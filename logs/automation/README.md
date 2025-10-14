# Automation Logs

Helper scripts should capture their progress in JSON Lines files under this directory.

Recommended fields per entry:
- `timestamp` (UTC ISO 8601)
- `level` (info, warning, error)
- `action` (script phase, such as `docker_build` or `git_clone`)
- Optional `target` or `status` values that avoid exposing hostnames, repository URLs, or user-supplied credentials.

Rotate files when they exceed 5 MB or 50 runs by starting a new timestamped file. Delete or archive stale files older than 30 days unless they are tied to open investigations.
