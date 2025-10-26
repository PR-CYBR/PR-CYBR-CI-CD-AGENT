# Terraform Cloud Workflow Bridge Integration

This repository uses the Terraform Cloud–GitHub Actions workflow bridge so that GitHub only signals when a run should execute and all long-lived credentials stay inside Terraform Cloud. The `.github/workflows/terraform-cloud-workflow-bridge` workflow exchanges a GitHub OIDC token for a short-lived credential that Terraform Cloud validates before queueing the run.

## Required Repository Variables

Configure the following GitHub **repository variables** so the workflow knows how to reach your Terraform Cloud workflow bridge endpoint:

| Variable | Description |
| --- | --- |
| `TFC_WORKFLOW_BRIDGE_URL` | The HTTPS invoke URL provided by the Terraform Cloud workflow bridge. |
| `TFC_WORKFLOW_AUDIENCE` | Optional custom OIDC audience string if your workflow bridge expects something other than `app.terraform.io`. |
| `TFC_WORKSPACE_NAME` | Optional hint that is forwarded to Terraform Cloud for routing or logging. |

All sensitive data (Terraform Cloud API tokens, provider credentials, etc.) must remain configured as Terraform Cloud workspace variables or variable sets.

## Monitoring Runs

The workflow returns once Terraform Cloud acknowledges the request. Monitor the plan and apply progress directly from the Terraform Cloud workspace that backs this repository.
