# Notion Sync

## Future Work

### Webhook listener or scheduled poller
- Implement a lightweight Notion webhook listener that receives change notifications for pages tied to the CI/CD planning database. The listener should enqueue updates for downstream processing and invoke the existing `scripts/notion_backsync.py` logic to reconcile GitHub state when relevant properties change.
- As a fallback (or complementary path), run `scripts/notion_backsync.py` on a schedule to poll Notion for updates. The poller should track last-synced timestamps to minimize API calls and only push deltas into GitHub.
- Both approaches should normalise incoming payloads into a common event schema (page ID, changed properties, prior values) so that downstream automation does not depend on how the change was detected.

### Mapping Notion property changes to GitHub actions
- **Status changes:** When a task's status transitions to "Ready for Review" or similar, automatically open or update a draft pull request linked to the relevant issue. When a status changes to "Done" or "Shipped," close the corresponding GitHub issue and merge the associated pull request if all required checks have passed.
- **New tasks:** When a new Notion page is created in the backlog database, generate a matching GitHub issue (labeled with metadata from Notion such as priority or sprint) and populate cross-links back to Notion.
- **Reassignments or priority updates:** Sync assignee and label changes into GitHub issues so triage views remain aligned across both systems.

### Identifier storage for two-way sync
- Persist a mapping of Notion page IDs to GitHub issue and pull request numbers. Recommended options include:
  - A dedicated metadata table (e.g., SQLite file or lightweight key-value store) maintained by the sync service and versioned in object storage.
  - Custom Notion properties (e.g., "GitHub Issue #", "GitHub PR #") populated with the numeric identifiers once records are created.
  - GitHub issue body/front matter sections containing the Notion page ID so GitHub-driven updates can resolve the reciprocal record.
- The mapping layer should support upserts, conflict detection, and a "soft delete" flag to handle archived pages or closed issues while preserving historical traceability.

### Infrastructure and permissions
- **Runtime:** Deploy the webhook listener as a serverless function (AWS Lambda, Google Cloud Function, or Azure Function) exposed via HTTPS, or run the scheduled poller inside a GitHub Actions workflow configured with a `schedule` cron trigger. Both options align with the existing Terraform-managed infrastructure strategy and keep operational overhead low.
- **Secrets & configuration:** Store Notion integration tokens, GitHub app credentials, and any database connection strings in Terraform Cloud Workspace environment variables so they remain out of the repository while accessible to the automation runtime.
- **Permissions:**
  - Notion: the integration must have read/write access to the relevant database(s) to fetch tasks, update cross-link properties, and append comments.
  - GitHub: use a GitHub App or fine-scoped PAT with `contents:write`, `issues:write`, `pull_requests:write`, and `workflow` permissions to open issues/PRs, close issues, merge PRs, and dispatch workflows. If running as a GitHub Action, configure the workflow token permissions accordingly.
- **Observability:** Configure logging and alerting (CloudWatch, Stackdriver, or GitHub Action summaries) for failed sync attempts, rate limit responses, and permission errors so operators can intervene quickly.
