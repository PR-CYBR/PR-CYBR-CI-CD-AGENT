# Notion Sync Runbook

This runbook documents how the Notion synchronisation workflow is
monitored, how to conduct manual validation, and what to do when a
rollback is required.

## Monitoring

1. **Workflow logs** – Review the GitHub Actions workflow that invokes
   the Python sync utility. Structured logs emitted by
   `pr_cybr.notion_sync` include the GitHub event type, retry attempt
   counts, and the Notion payload being processed. Export the logs to the
   central observability stack for alerting on repeated failures or
   excessive retries.
2. **Notion activity history** – Confirm that updates appear in the
   expected database. The Notion UI exposes a page history that will show
   new or modified pages.
3. **Rate limit tracking** – The workflow logs `Notion API rate limit
   encountered` whenever a 429 is handled. A sudden increase suggests the
   integration should be throttled or scheduled at a lower frequency.

## Manual validation (spec-bootstrap flow)

Manual validation must be executed from a dedicated feature branch (for
example `feature/notion-sync-validation`) before merging any changes into
`main`.

1. Trigger the workflow manually using workflow dispatch and set the
   `NOTION_DRY_RUN` input to `true`. This confirms the workflow completes
   and logs the intended Notion operations without writing data.
2. Toggle `NOTION_DRY_RUN` to `false` and rerun the workflow using sample
   GitHub artefacts (issues, pull requests, discussions, and project
   cards). Confirm the corresponding pages are created or updated in
   Notion.
3. Capture screenshots or export of the Notion database rows to document
   the validation.

## Rollback and containment

If the integration must be halted or rolled back:

1. **Disable the workflow** – From GitHub Actions, disable the Notion
   sync workflow or revert the feature branch to stop further executions.
2. **Revoke the Notion integration token** – Remove or rotate the token
   stored in Terraform Cloud workspace variables to prevent new sessions.
3. **Restore database state** – Use Notion’s page history or backups to
   restore any affected pages if incorrect updates were applied.
4. **Open an incident ticket** – Record the timeline, affected records,
   and remediation steps for auditability.

## Troubleshooting checklist

- Review the workflow run logs for stack traces or repeated `Failed to
  synchronise payload to Notion` messages.
- Confirm Terraform Cloud secrets (Notion token, database ID) are
  present and have not expired.
- Use the dry-run mode (`NOTION_DRY_RUN=true`) to reproduce the issue
  safely after applying fixes.
