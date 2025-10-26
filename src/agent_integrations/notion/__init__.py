"""Utilities for synchronising GitHub entities with Notion."""

from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, Optional

from notion_client import Client
from notion_client.errors import APIResponseError
from tenacity import retry, stop_after_attempt, wait_exponential


LOGGER = logging.getLogger(__name__)


@dataclass
class SyncContext:
    """Holds shared dependencies for sync operations."""

    client: Client
    cache: "NotionLinkStore"


class NotionLinkStore:
    """Persists mappings between GitHub entity IDs and Notion pages."""

    def __init__(self, path: Path | None = None) -> None:
        self.path = path or Path(".cache/notion_links.json")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._data: Dict[str, Dict[str, str]] = {
            "issues": {},
            "pull_requests": {},
            "projects": {},
            "discussions": {},
        }
        self._load()

    def _load(self) -> None:
        if not self.path.exists():
            return
        try:
            with self.path.open("r", encoding="utf-8") as handle:
                payload = json.load(handle)
        except (OSError, json.JSONDecodeError) as exc:
            LOGGER.warning("Failed to read Notion link cache %s: %s", self.path, exc)
            return
        if isinstance(payload, dict):
            for key, mapping in payload.items():
                if key in self._data and isinstance(mapping, dict):
                    self._data[key].update({str(k): str(v) for k, v in mapping.items()})

    def _save(self) -> None:
        try:
            with self.path.open("w", encoding="utf-8") as handle:
                json.dump(self._data, handle, indent=2, sort_keys=True)
        except OSError as exc:
            LOGGER.error("Unable to persist Notion link cache %s: %s", self.path, exc)

    def get(self, category: str, github_id: str) -> Optional[str]:
        return self._data.get(category, {}).get(github_id)

    def set(self, category: str, github_id: str, page_id: str) -> None:
        if category not in self._data:
            self._data[category] = {}
        self._data[category][github_id] = page_id
        self._save()


def _get_client() -> Optional[Client]:
    token = os.environ.get("NOTION_API_KEY") or os.environ.get("NOTION_TOKEN")
    if not token:
        LOGGER.error("NOTION_API_KEY environment variable must be set")
        return None
    return Client(auth=token)


def _get_sync_context() -> Optional[SyncContext]:
    client = _get_client()
    if client is None:
        return None
    cache = NotionLinkStore()
    return SyncContext(client=client, cache=cache)


def _build_properties(
    *,
    title: str,
    github_id: str,
    status: Optional[str] = None,
    stage: Optional[str] = None,
    body: Optional[str] = None,
    assignees: Optional[Iterable[str]] = None,
    labels: Optional[Iterable[str]] = None,
    url: Optional[str] = None,
) -> Dict[str, Any]:
    properties: Dict[str, Any] = {
        "Name": {
            "title": [
                {
                    "type": "text",
                    "text": {"content": title[:2000]},
                }
            ]
        },
        "GitHub ID": {
            "rich_text": [
                {
                    "type": "text",
                    "text": {"content": github_id},
                }
            ]
        },
    }

    if status:
        properties["Status"] = {"status": {"name": status[:100]}}
    if stage:
        properties["Stage"] = {"select": {"name": stage[:100]}}
    if body:
        excerpt = body.strip().replace("\r\n", "\n")[:2000]
        properties["Summary"] = {
            "rich_text": [
                {
                    "type": "text",
                    "text": {"content": excerpt},
                }
            ]
        }
    if assignees:
        people = [name for name in assignees if name]
        if people:
            properties["Assignees"] = {
                "multi_select": [{"name": person[:100]} for person in people]
            }
    if labels:
        tags = [label for label in labels if label]
        if tags:
            properties["Labels"] = {
                "multi_select": [{"name": label[:100]} for label in tags]
            }
    if url:
        properties["URL"] = {"url": url}

    return properties


@retry(wait=wait_exponential(multiplier=1, min=1, max=8), stop=stop_after_attempt(3), reraise=True)
def _find_page_by_github_id(client: Client, database_id: str, github_id: str) -> Optional[str]:
    response = client.databases.query(
        **{
            "database_id": database_id,
            "filter": {
                "property": "GitHub ID",
                "rich_text": {"equals": github_id},
            },
        }
    )
    results = response.get("results", [])
    if not results:
        return None
    return results[0].get("id")


@retry(wait=wait_exponential(multiplier=1, min=1, max=8), stop=stop_after_attempt(3), reraise=True)
def _create_page(client: Client, database_id: str, properties: Dict[str, Any]) -> str:
    page = client.pages.create(parent={"database_id": database_id}, properties=properties)
    return page["id"]


@retry(wait=wait_exponential(multiplier=1, min=1, max=8), stop=stop_after_attempt(3), reraise=True)
def _update_page(client: Client, page_id: str, properties: Dict[str, Any]) -> None:
    client.pages.update(page_id=page_id, properties=properties)


def _sync_entity(
    *,
    database_env: str,
    category: str,
    github_id: Optional[Any],
    title: Optional[str],
    status: Optional[str],
    stage: Optional[str],
    body: Optional[str],
    assignees: Iterable[str] | None,
    labels: Iterable[str] | None,
    url: Optional[str],
) -> Optional[str]:
    context = _get_sync_context()
    if context is None:
        return None

    database_id = os.environ.get(database_env)
    if not database_id:
        LOGGER.warning("%s environment variable not set; skipping Notion sync", database_env)
        return None

    if not github_id:
        LOGGER.warning("No GitHub ID provided for category %s", category)
        return None

    if not title:
        title = f"GitHub {category.title()} {github_id}"

    github_id_str = str(github_id)
    properties = _build_properties(
        title=title,
        github_id=github_id_str,
        status=status,
        stage=stage,
        body=body,
        assignees=assignees,
        labels=labels,
        url=url,
    )

    try:
        page_id = context.cache.get(category, github_id_str)
        if page_id:
            try:
                _update_page(context.client, page_id, properties)
                LOGGER.info("Updated Notion page %s for %s %s", page_id, category, github_id)
                return page_id
            except APIResponseError as exc:
                LOGGER.warning(
                    "Failed to update cached Notion page %s (%s); will attempt lookup: %s",
                    page_id,
                    category,
                    exc,
                )

        page_id = _find_page_by_github_id(context.client, database_id, github_id_str)
        if page_id:
            _update_page(context.client, page_id, properties)
            LOGGER.info("Updated Notion page %s for %s %s", page_id, category, github_id)
        else:
            page_id = _create_page(context.client, database_id, properties)
            LOGGER.info("Created Notion page %s for %s %s", page_id, category, github_id)

        context.cache.set(category, github_id_str, page_id)
        return page_id
    except APIResponseError as exc:
        LOGGER.error("Notion API error while syncing %s %s: %s", category, github_id, exc)
    except Exception as exc:  # pylint: disable=broad-except
        LOGGER.exception("Unexpected error while syncing %s %s: %s", category, github_id, exc)
    return None


def sync_issue(payload: Dict[str, Any]) -> Optional[str]:
    """Synchronise an issue payload with the configured Notion database."""

    issue = payload.get("issue", payload)
    github_id = issue.get("id")
    title = issue.get("title")
    status = issue.get("state")
    stage = issue.get("state_reason")
    body = issue.get("body")
    assignees = [assignee.get("login") for assignee in issue.get("assignees", [])]
    labels = [label.get("name") for label in issue.get("labels", [])]
    url = issue.get("html_url")

    return _sync_entity(
        database_env="NOTION_TASK_DB",
        category="issues",
        github_id=github_id,
        title=title,
        status=status,
        stage=stage,
        body=body,
        assignees=assignees,
        labels=labels,
        url=url,
    )


def sync_pull_request(payload: Dict[str, Any]) -> Optional[str]:
    """Synchronise a pull request payload with the configured Notion database."""

    pull_request = payload.get("pull_request", payload)
    github_id = pull_request.get("id")
    title = pull_request.get("title")
    status = "merged" if pull_request.get("merged") else pull_request.get("state")
    stage = "Draft" if pull_request.get("draft") else pull_request.get("mergeable_state")
    body = pull_request.get("body")
    assignees = [assignee.get("login") for assignee in pull_request.get("assignees", [])]
    labels = [label.get("name") for label in pull_request.get("labels", [])]
    url = pull_request.get("html_url")

    return _sync_entity(
        database_env="NOTION_PR_DB",
        category="pull_requests",
        github_id=github_id,
        title=title,
        status=status,
        stage=stage,
        body=body,
        assignees=assignees,
        labels=labels,
        url=url,
    )


def sync_project_item(payload: Dict[str, Any]) -> Optional[str]:
    """Synchronise a project item payload with the configured Notion database."""

    project_item = (
        payload.get("project_item")
        or payload.get("projects_v2_item")
        or payload.get("item")
        or payload
    )

    github_id = project_item.get("id") or project_item.get("item_id")
    title = project_item.get("title") or project_item.get("name")
    status = project_item.get("status")
    stage = project_item.get("stage") or project_item.get("state")
    body = project_item.get("body") or project_item.get("summary")
    labels = project_item.get("labels") or project_item.get("tags")
    if isinstance(labels, str):
        labels = [item.strip() for item in labels.split(",") if item.strip()]
    assignees_data = project_item.get("assignees") or []
    assignees: Iterable[str] | None
    if isinstance(assignees_data, list):
        assignees = [
            assignee.get("name")
            if isinstance(assignee, dict)
            else str(assignee)
            for assignee in assignees_data
        ]
    else:
        assignees = [str(assignees_data)] if assignees_data else None
    url = project_item.get("html_url") or project_item.get("url")

    return _sync_entity(
        database_env="NOTION_PROJECT_DB",
        category="projects",
        github_id=github_id,
        title=title,
        status=status,
        stage=stage,
        body=body,
        assignees=assignees,
        labels=labels,
        url=url,
    )


def sync_discussion(payload: Dict[str, Any]) -> Optional[str]:
    """Synchronise a discussion payload with the configured Notion database."""

    discussion = payload.get("discussion", payload)
    github_id = discussion.get("id")
    title = discussion.get("title")
    status = discussion.get("state")
    stage = discussion.get("category", {}).get("name") if isinstance(discussion.get("category"), dict) else None
    body = discussion.get("body_text") or discussion.get("body")
    labels = discussion.get("labels") or discussion.get("tags")
    if isinstance(labels, list):
        labels = [label.get("name") if isinstance(label, dict) else str(label) for label in labels]
    elif isinstance(labels, str):
        labels = [label.strip() for label in labels.split(",") if label.strip()]
    url = discussion.get("html_url") or discussion.get("url")

    return _sync_entity(
        database_env="NOTION_DISCUSSION_DB",
        category="discussions",
        github_id=github_id,
        title=title,
        status=status,
        stage=stage,
        body=body,
        assignees=None,
        labels=labels,
        url=url,
    )


__all__ = [
    "sync_issue",
    "sync_pull_request",
    "sync_project_item",
    "sync_discussion",
    "NotionLinkStore",
]

