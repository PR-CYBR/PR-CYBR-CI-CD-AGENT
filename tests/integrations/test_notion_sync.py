import logging
from typing import Dict
from unittest.mock import MagicMock

import pytest

from agent_logic.notion_sync import NotionSyncError, NotionSyncService, RetryPolicy


class RateLimitError(Exception):
    """Simple stand in to emulate the Notion client's 429 error."""

    def __init__(self, message: str = "Rate limited", status: int = 429) -> None:
        super().__init__(message)
        self.status = status


def issue_payload() -> Dict:
    return {
        "event_type": "issues",
        "action": "opened",
        "issue": {
            "id": 1,
            "title": "Bug in deployment",
            "state": "open",
            "html_url": "https://github.com/PR-CYBR/example/issues/1",
            "updated_at": "2024-04-01T12:00:00Z",
            "labels": [
                {"id": 10, "name": "bug"},
                {"id": 11, "name": "priority:high"},
            ],
        },
    }


def pull_request_payload() -> Dict:
    return {
        "event_type": "pull_request",
        "action": "synchronize",
        "pull_request": {
            "id": 2,
            "title": "Add structured logging",
            "state": "open",
            "draft": False,
            "html_url": "https://github.com/PR-CYBR/example/pull/2",
            "updated_at": "2024-04-01T13:00:00Z",
            "user": {"login": "octocat"},
        },
    }


def discussion_payload() -> Dict:
    return {
        "event_type": "discussion",
        "action": "created",
        "discussion": {
            "id": 3,
            "title": "How should retries work?",
            "html_url": "https://github.com/PR-CYBR/example/discussions/3",
            "category": {"id": 30, "name": "Architecture"},
            "updated_at": "2024-04-01T14:00:00Z",
        },
    }


def project_card_payload() -> Dict:
    return {
        "event_type": "project_card",
        "action": "moved",
        "project_card": {
            "id": 4,
            "note": "Follow-up on alerting",
            "column_name": "Review",
            "url": "https://github.com/PR-CYBR/example/projects/1#card-4",
            "content_url": "https://api.github.com/repos/PR-CYBR/example/issues/1",
        },
    }


@pytest.fixture
def notion_client() -> MagicMock:
    client = MagicMock()
    client.upsert_page.return_value = {"id": "page-123"}
    return client


def test_dry_run_skips_updates(monkeypatch, caplog, notion_client):
    monkeypatch.setenv("NOTION_DRY_RUN", "true")
    service = NotionSyncService(notion_client, database_id="db123")

    with caplog.at_level(logging.INFO):
        response = service.sync_payload(issue_payload())

    assert response is None
    notion_client.upsert_page.assert_not_called()
    assert "Dry run enabled" in caplog.text


def test_retry_on_rate_limit(monkeypatch, notion_client):
    monkeypatch.setenv("NOTION_DRY_RUN", "false")

    sleep_calls = []

    def fake_sleep(delay: float) -> None:
        sleep_calls.append(delay)

    rate_limit_error = RateLimitError()
    notion_client.upsert_page.side_effect = [rate_limit_error, {"id": "page-456"}]
    service = NotionSyncService(
        notion_client,
        database_id="db123",
        retry_policy=RetryPolicy(max_attempts=3, initial_delay=0.1, backoff_multiplier=2.0),
        dry_run=False,
        sleep_func=fake_sleep,
    )

    response = service.sync_payload(pull_request_payload())

    assert response == {"id": "page-456"}
    assert notion_client.upsert_page.call_count == 2
    assert sleep_calls == [0.1]


def test_failure_raises_error(monkeypatch, notion_client):
    monkeypatch.setenv("NOTION_DRY_RUN", "false")
    notion_client.upsert_page.side_effect = RuntimeError("boom")
    service = NotionSyncService(notion_client, database_id="db123", dry_run=False)

    with pytest.raises(NotionSyncError):
        service.sync_payload(discussion_payload())


def test_unknown_event_logs_warning(caplog, notion_client):
    payload = {"event_type": "deployment", "deployment": {}}
    service = NotionSyncService(notion_client, database_id="db123", dry_run=False)

    with caplog.at_level(logging.WARNING):
        response = service.sync_payload(payload)

    assert response is None
    assert "Unsupported GitHub event" in caplog.text
    notion_client.upsert_page.assert_not_called()


def test_project_card_payload_contains_children(notion_client):
    service = NotionSyncService(notion_client, database_id="db123", dry_run=True)
    payload = project_card_payload()

    notion_payload = service._build_project_card_payload(payload)

    assert notion_payload
    assert notion_payload["children"][0]["paragraph"]["rich_text"][0]["text"]["content"].startswith("Linked content:")
