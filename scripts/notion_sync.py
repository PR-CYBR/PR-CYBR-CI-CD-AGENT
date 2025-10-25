#!/usr/bin/env python3
"""Utility entry point for GitHub-driven Notion synchronisation.

This script intentionally keeps the implementation lightweight. It converts the
GitHub Actions payload (passed via CLI arguments) into a structured summary that
can be consumed by downstream automation or inspected for debugging. The
resulting payload is persisted to ``build/notion_payload.json`` so that other
steps in the workflow—or operators investigating a failure—can review the exact
content that would be sent to Notion.

The script does not interact with the Notion API directly. That behaviour can
be implemented by extending :func:`dispatch_to_notion` with the desired API
calls. For now, the function simply logs the prepared payload. This keeps the
job successful even when the required Notion credentials are absent, while still
providing a deterministic, testable output for validation.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional


@dataclass
class EventContext:
    """Structured representation of the GitHub event payload."""

    event_name: str
    action: str
    resource_type: str
    resource_id: str
    resource_url: str
    repository: str
    workflow: str
    run_id: str
    actor: Optional[str] = None
    title: Optional[str] = None
    additional_metadata: Dict[str, Any] = field(default_factory=dict)

    def to_serialisable(self) -> Dict[str, Any]:
        payload = asdict(self)
        payload["timestamp"] = datetime.now(timezone.utc).isoformat()
        return payload


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event-name", required=True)
    parser.add_argument("--event-action", default="")
    parser.add_argument("--resource-type", required=True)
    parser.add_argument("--resource-id", required=True)
    parser.add_argument("--resource-url", default="")
    parser.add_argument("--repository", required=True)
    parser.add_argument("--workflow", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--actor")
    parser.add_argument("--title")
    parser.add_argument("--metadata", help="JSON encoded metadata payload", default="{}")
    parser.add_argument("--payload-path", default="build/notion_payload.json")
    parser.add_argument("--notion-api-key", default=os.environ.get("NOTION_API_TOKEN"))
    parser.add_argument("--database-id", default=os.environ.get("NOTION_DATABASE_ID"))
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def load_metadata(raw: str) -> Dict[str, Any]:
    try:
        return json.loads(raw) if raw else {}
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON metadata payload: {exc}") from exc


def persist_payload(path: str, data: Dict[str, Any]) -> Path:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")
    return target


def dispatch_to_notion(event: EventContext, notion_api_key: Optional[str], database_id: Optional[str], dry_run: bool) -> None:
    if not notion_api_key or not database_id:
        print("[notion_sync] Notion credentials were not provided. Skipping API dispatch.", file=sys.stderr)
        return

    if dry_run:
        print("[notion_sync] Dry run enabled. Prepared payload would be sent to Notion:")
        print(json.dumps(event.to_serialisable(), indent=2, sort_keys=True))
        return

    # Placeholder for future Notion API implementation.
    print("[notion_sync] Notion integration not implemented. Payload logged for reference:")
    print(json.dumps(event.to_serialisable(), indent=2, sort_keys=True))


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    metadata = load_metadata(args.metadata)

    context = EventContext(
        event_name=args.event_name,
        action=args.event_action,
        resource_type=args.resource_type,
        resource_id=args.resource_id,
        resource_url=args.resource_url,
        repository=args.repository,
        workflow=args.workflow,
        run_id=args.run_id,
        actor=args.actor,
        title=args.title,
        additional_metadata=metadata,
    )

    serialisable_payload = context.to_serialisable()
    serialisable_payload["notion"] = {
        "database_id": args.database_id,
        "api_key_provided": bool(args.notion_api_key),
    }

    output_path = persist_payload(args.payload_path, serialisable_payload)
    print(f"[notion_sync] Payload written to {output_path}")

    dispatch_to_notion(context, args.notion_api_key, args.database_id, args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
