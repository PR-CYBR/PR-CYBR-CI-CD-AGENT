"""Utilities for synchronising GitHub activity into Notion databases.

The module is intentionally self contained so that it can be used from
GitHub Actions or other automation entry points.  A thin wrapper class is
provided which accepts a Notion client instance (for example
``notion_client.Client``) and performs a resilient upsert with
exponential backoff.  Structured logging is used throughout to make it
simple to ingest the logs into observability platforms.
"""
from __future__ import annotations

import logging
import os
import time
from dataclasses import dataclass
from typing import Any, Callable, Dict, Optional, Protocol

logger = logging.getLogger("pr_cybr.notion_sync")


class NotionClientProtocol(Protocol):
    """Protocol describing the Notion client behaviour used by the service."""

    def upsert_page(self, *, database_id: str, properties: Dict[str, Any], children: Optional[list] = None) -> Dict[str, Any]:
        """Create or update a Notion page in the specified database."""


class NotionSyncError(RuntimeError):
    """Raised when the Notion synchronisation process fails."""


@dataclass(frozen=True)
class RetryPolicy:
    """Configuration for retrying failed Notion API calls."""

    max_attempts: int = 5
    initial_delay: float = 1.0
    backoff_multiplier: float = 2.0


class NotionSyncService:
    """Synchronise GitHub webhook payloads into Notion.

    Parameters
    ----------
    notion_client:
        An object implementing :class:`NotionClientProtocol`.
    database_id:
        The Notion database identifier where pages should be upserted.
    dry_run:
        Optional flag overriding the ``NOTION_DRY_RUN`` environment
        variable.  When enabled the service logs the payload it would send
        to Notion without performing any write operations.
    retry_policy:
        Configuration controlling how retries are executed.
    sleep_func:
        Injection point for ``time.sleep`` (makes unit testing easier).
    """

    def __init__(
        self,
        notion_client: NotionClientProtocol,
        *,
        database_id: str,
        dry_run: Optional[bool] = None,
        retry_policy: RetryPolicy = RetryPolicy(),
        logger_: Optional[logging.Logger] = None,
        sleep_func: Callable[[float], None] = time.sleep,
    ) -> None:
        self.notion_client = notion_client
        self.database_id = database_id
        self.retry_policy = retry_policy
        self.sleep = sleep_func
        self.logger = logger_ or logger
        if dry_run is None:
            dry_run_env = os.getenv("NOTION_DRY_RUN", "false").strip().lower()
            dry_run = dry_run_env in {"1", "true", "yes", "on"}
        self.dry_run = dry_run

    # Public API ---------------------------------------------------------
    def sync_payload(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Synchronise a GitHub payload into Notion.

        Parameters
        ----------
        payload:
            GitHub webhook payload.  The payload is expected to contain an
            ``event_type`` key or similar information to identify the
            originating GitHub event.

        Returns
        -------
        Optional[Dict[str, Any]]
            The response from the Notion API if the operation succeeds.
            ``None`` is returned for dry-run invocations or when the
            payload cannot be converted into a Notion update.
        """

        event_type = self._extract_event_type(payload)
        if not event_type:
            self.logger.warning(
                "Unable to determine event type for GitHub payload",
                extra={"payload_keys": list(payload.keys())},
            )
            return None

        notion_payload = self._build_notion_payload(event_type, payload)
        if not notion_payload:
            self.logger.warning(
                "Unsupported GitHub event for Notion sync",
                extra={"event_type": event_type},
            )
            return None

        if self.dry_run:
            self.logger.info(
                "Dry run enabled – skipping Notion update",
                extra={"event_type": event_type, "notion_payload": notion_payload},
            )
            return None

        return self._execute_with_retry(
            self._submit_to_notion,
            notion_payload,
            event_type=event_type,
        )

    # Internal helpers ---------------------------------------------------
    def _execute_with_retry(
        self,
        func: Callable[[Dict[str, Any]], Dict[str, Any]],
        notion_payload: Dict[str, Any],
        *,
        event_type: str,
    ) -> Dict[str, Any]:
        attempts = 0
        delay = self.retry_policy.initial_delay

        while True:
            attempts += 1
            try:
                self.logger.debug(
                    "Attempting Notion sync",
                    extra={"event_type": event_type, "attempt": attempts},
                )
                response = func(notion_payload)
                self.logger.info(
                    "Notion sync completed",
                    extra={"event_type": event_type, "attempts": attempts},
                )
                return response
            except Exception as exc:  # pragma: no cover - branch verified via tests
                if self._is_rate_limit_error(exc) and attempts < self.retry_policy.max_attempts:
                    self.logger.warning(
                        "Notion API rate limit encountered",
                        extra={"event_type": event_type, "attempt": attempts, "delay": delay},
                    )
                    self.sleep(delay)
                    delay *= self.retry_policy.backoff_multiplier
                    continue
                self.logger.exception(
                    "Unable to sync payload to Notion",
                    extra={"event_type": event_type, "attempts": attempts},
                )
                raise NotionSyncError("Failed to synchronise payload to Notion") from exc

    def _submit_to_notion(self, notion_payload: Dict[str, Any]) -> Dict[str, Any]:
        return self.notion_client.upsert_page(
            database_id=self.database_id,
            properties=notion_payload["properties"],
            children=notion_payload.get("children"),
        )

    @staticmethod
    def _extract_event_type(payload: Dict[str, Any]) -> Optional[str]:
        for key in ("event_type", "event", "action", "type"):
            event_type = payload.get(key)
            if isinstance(event_type, str) and event_type:
                return event_type
        return None

    def _build_notion_payload(self, event_type: str, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        builders = {
            "issues": self._build_issue_payload,
            "issue": self._build_issue_payload,
            "pull_request": self._build_pull_request_payload,
            "pull_request_target": self._build_pull_request_payload,
            "discussion": self._build_discussion_payload,
            "project_card": self._build_project_card_payload,
        }

        builder = builders.get(event_type)
        if not builder:
            return None
        return builder(payload)

    # Payload builders ---------------------------------------------------
    def _build_issue_payload(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        issue = payload.get("issue")
        if not issue:
            return None
        title = issue.get("title", "(untitled issue)")
        url = issue.get("html_url")
        state = issue.get("state")
        labels = [label.get("name") for label in issue.get("labels", []) if label.get("name")]
        return {
            "properties": {
                "Name": {"title": [{"text": {"content": title}}]},
                "URL": {"url": url},
                "State": {"select": {"name": state} if state else None},
                "Labels": {"multi_select": [{"name": label} for label in labels]},
                "Updated": {"date": {"start": issue.get("updated_at")}},
            }
        }

    def _build_pull_request_payload(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        pr = payload.get("pull_request")
        if not pr:
            return None
        title = pr.get("title", "(untitled pull request)")
        url = pr.get("html_url")
        state = pr.get("state")
        draft = pr.get("draft")
        return {
            "properties": {
                "Name": {"title": [{"text": {"content": title}}]},
                "URL": {"url": url},
                "State": {"select": {"name": state} if state else None},
                "Draft": {"checkbox": bool(draft)},
                "Updated": {"date": {"start": pr.get("updated_at")}},
                "Author": {"rich_text": [{"text": {"content": pr.get("user", {}).get("login", "")}}]},
            }
        }

    def _build_discussion_payload(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        discussion = payload.get("discussion")
        if not discussion:
            return None
        title = discussion.get("title", "(untitled discussion)")
        url = discussion.get("html_url")
        category = discussion.get("category", {}).get("name")
        return {
            "properties": {
                "Name": {"title": [{"text": {"content": title}}]},
                "URL": {"url": url},
                "Category": {"select": {"name": category} if category else None},
                "Updated": {"date": {"start": discussion.get("updated_at")}},
            }
        }

    def _build_project_card_payload(self, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        card = payload.get("project_card")
        if not card:
            return None
        note = card.get("note") or "(no note)"
        column = card.get("column_name")
        url = card.get("url") or card.get("html_url")
        content_url = card.get("content_url")
        children = []
        if content_url:
            children.append(
                {
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": {
                        "rich_text": [
                            {
                                "type": "text",
                                "text": {"content": f"Linked content: {content_url}"},
                            }
                        ]
                    },
                }
            )
        return {
            "properties": {
                "Name": {"title": [{"text": {"content": note}}]},
                "URL": {"url": url},
                "Column": {"select": {"name": column} if column else None},
            },
            "children": children or None,
        }

    # Static helpers -----------------------------------------------------
    @staticmethod
    def _is_rate_limit_error(exc: Exception) -> bool:
        status = getattr(exc, "status", None) or getattr(exc, "code", None)
        if status == 429:
            return True
        message = str(exc).lower()
        return "rate limit" in message or "too many requests" in message


__all__ = ["NotionSyncService", "NotionSyncError", "RetryPolicy"]
