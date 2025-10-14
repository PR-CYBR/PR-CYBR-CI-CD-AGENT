# CI Logs

Workflow runs should write structured JSON Lines files (for example, `build-test-20240101T120000Z.jsonl`) into this directory.

Each entry must contain:
- `timestamp` in UTC using ISO 8601.
- `level` such as `info`, `warning`, or `error`.
- `event` describing the step that executed.
- Optional sanitized metadata such as `status` or `summary`. Strip container IDs, paths, or repository names to non-sensitive suffixes when possible.

Do not commit raw CI logs. If a sanitized summary is necessary for documentation, name it `sanitized-<context>.jsonl` and review it for secrets before committing.
