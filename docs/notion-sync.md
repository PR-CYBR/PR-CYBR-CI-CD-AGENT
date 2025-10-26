# Notion Sync Integration

This repository mirrors the secret-management and CI/CD conventions documented in the [spec-bootstrap](https://github.com/PR-CYBR/spec-bootstrap/) template. The Notion sync touches only the scheduled maintenance automation, so the same separation of duties (`codex`, `agents`, `dev`, `main`) remains intact.

## Secret Management via Terraform Cloud

The `agent-variables.tf` baseline now declares the following Terraform Cloud workspace variables:

- `NOTION_TOKEN`
- `NOTION_TASK_DB`
- `NOTION_PR_DB`
- `NOTION_PROJECT_DB`
- `NOTION_DISCUSSION_DB`

Populate each variable in the Terraform Cloud workspace that feeds this agent. Mark every entry as **Environment Variable** and **Sensitive** so they inherit the encryption-at-rest and audit logging guarantees from Terraform Cloud. This mirrors the spec-bootstrap expectation that all runtime credentials live in Terraform Cloud rather than the repository.

> **Tip:** Record the Notion database IDs in the workspace variable descriptions so future rotations can be coordinated without exposing values in Git history.

## Mapping Secrets into GitHub Actions

The scheduled `maintenance` workflow is the only job that calls the Notion sync Python entry point. To stay aligned with spec-bootstrap CI patterns:

1. Mirror the Terraform Cloud variables into GitHub Actions secrets with the same names. (When this repository is wired to Terraform Cloud, the `tfc-sync` workflow will propagate the workspace values.)
2. The workflow step exports those secrets into the execution environment, making them available to `maintenance.py` via `os.environ`.
3. The job continues to trigger only from the automation branches (`codex`, `agents`, `dev`) or pull requests targeting `main`, preserving the branch-governance model from spec-bootstrap.

Developers running the script locally can create a `.env` file or export the same variables manually before calling the Python module.

## Notion Integration Hardening

Limit the Notion integration to the exact databases the automation touches:

- Share the integration with the task tracker database identified by `NOTION_TASK_DB`.
- Share the integration with the pull request register database identified by `NOTION_PR_DB`.
- Share the integration with the portfolio database identified by `NOTION_PROJECT_DB`.
- Share the integration with the discussion/decision log identified by `NOTION_DISCUSSION_DB`.

Do **not** grant the integration workspace-wide access. In the Notion UI, open each database, click **Share**, and invite the integration. Leave all other pages and databases unshared.

### Minimum Token Scopes

When creating or rotating the integration token, enable only the following capabilities:

- **Read content** – required to fetch database rows for synchronization.
- **Update content** – required to update database rows when syncing status fields.
- **Insert content** (optional) – enable only if the automation needs to create new entries; otherwise leave disabled.

No additional scopes (commenting, user management, or unrestricted workspace access) are required.

## Operational Checklist

1. Confirm Terraform Cloud workspace variables are populated and marked sensitive.
2. Sync the secrets into GitHub Actions so the `maintenance` workflow can expose them to `maintenance.py`.
3. Verify the Notion integration is shared with only the four target databases.
4. Trigger the `maintenance` workflow from the `codex` or `agents` branch to validate the end-to-end handoff.

Keeping the bootstrap patterns in place ensures the Notion automation inherits the same compliance posture as the rest of the PR-CYBR platform.
