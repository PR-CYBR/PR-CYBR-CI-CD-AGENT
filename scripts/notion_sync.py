#!/usr/bin/env python3
"""CLI utility for synchronising GitHub webhook payloads with Notion."""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from pathlib import Path
from typing import Any, Callable, Dict


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC_PATH = REPO_ROOT / "src"
if str(SRC_PATH) not in sys.path:
    sys.path.insert(0, str(SRC_PATH))


from agent_integrations.notion import (  # pylint: disable=wrong-import-position
    sync_discussion,
    sync_issue,
    sync_project_item,
    sync_pull_request,
)


LOGGER = logging.getLogger(__name__)


def _configure_logging(verbose: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )


def _load_payload(payload_path: Path | None) -> Dict[str, Any]:
    if not payload_path:
        LOGGER.info("No payload path supplied; using empty payload")
        return {}
    if not payload_path.exists():
        LOGGER.warning("Payload file %s does not exist", payload_path)
        return {}
    try:
        with payload_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        LOGGER.error("Failed to read payload %s: %s", payload_path, exc)
        return {}


def _resolve_event_type(cli_event: str | None) -> str | None:
    if cli_event:
        return cli_event
    if env_event := os.environ.get("NOTION_SYNC_EVENT"):
        return env_event
    if github_event := os.environ.get("GITHUB_EVENT_NAME"):
        return github_event
    return None


def _normalise_event(event: str) -> str:
    event = event.lower().strip()
    if event.endswith(".json"):
        event = event[:-5]
    return event.replace(" ", "_")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Sync GitHub payloads with Notion")
    parser.add_argument("--event-type", help="GitHub event type (issues, pull_request, project_item, discussion)")
    parser.add_argument("--payload", type=Path, help="Path to GitHub event payload JSON", default=None)
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")

    args = parser.parse_args(argv)

    _configure_logging(args.verbose)

    event_type = _resolve_event_type(args.event_type)
    if not event_type:
        parser.error("An event type must be provided via --event-type or environment variables")

    event_type = _normalise_event(event_type)
    payload_path = args.payload or (Path(os.environ["GITHUB_EVENT_PATH"]) if os.environ.get("GITHUB_EVENT_PATH") else None)
    payload = _load_payload(payload_path)

    event_map: Dict[str, Callable[[Dict[str, Any]], Any]] = {
        "issues": sync_issue,
        "issue": sync_issue,
        "pull_request": sync_pull_request,
        "pull_request_target": sync_pull_request,
        "pull_request_review": sync_pull_request,
        "project": sync_project_item,
        "project_item": sync_project_item,
        "projects_v2_item": sync_project_item,
        "discussion": sync_discussion,
        "discussion_comment": sync_discussion,
    }

    handler = event_map.get(event_type)
    if handler is None:
        LOGGER.warning("Unsupported event type %s; nothing to do", event_type)
        return 0

    try:
        notion_page_id = handler(payload)
    except Exception as exc:  # pylint: disable=broad-except
        LOGGER.exception("Failed to sync event %s: %s", event_type, exc)
        return 1

    if notion_page_id:
        LOGGER.info("Notion page ID: %s", notion_page_id)
    else:
        LOGGER.warning("No Notion page created or updated for event %s", event_type)

    return 0


if __name__ == "__main__":  # pragma: no cover - script entry point
    sys.exit(main())

