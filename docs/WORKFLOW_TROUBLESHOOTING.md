# Workflow Troubleshooting Guide

## Verify Environment Variables Workflow

### Issue: Workflow Failing Due to Missing Environment Variables

The `verify-env-vars.yml` workflow is designed to check that all required GitHub secrets and variables are properly configured for the repository.

### Required Configuration

The following environment variables must be configured in your GitHub repository:

#### Repository Variables (Settings → Secrets and variables → Actions → Variables)

- `AGENT_ACTIONS` - Actions available to the agent
- `NOTION_DISCUSSIONS_ARC_DB_ID` - Notion database ID for discussions archive
- `NOTION_ISSUES_BACKLOG_DB_ID` - Notion database ID for issues backlog
- `NOTION_KNOWLEDGE_FILE_DB_ID` - Notion database ID for knowledge files
- `NOTION_PAGE_ID` - Notion page ID for the main workspace
- `NOTION_PR_BACKLOG_DB_ID` - Notion database ID for PR backlog
- `NOTION_PROJECT_BOARD_BACKLOG_DB_ID` - Notion database ID for project board backlog
- `NOTION_TASK_BACKLOG_DB_ID` - Notion database ID for task backlog

#### Repository Secrets (Settings → Secrets and variables → Actions → Secrets)

- `NOTION_TOKEN` - Authentication token for Notion API (sensitive)

### How to Configure

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click on **Variables** tab to add repository variables
4. Click **New repository variable** for each variable listed above
5. Click on **Secrets** tab to add secrets
6. Click **New repository secret** to add `NOTION_TOKEN`

### How the Workflow Works

The workflow:
1. Maps each required variable from GitHub's `vars` or `secrets` context to the environment
2. Checks if each variable has a value
3. Reports which variables are missing (if any)
4. Fails if any required variable is not configured
5. Succeeds if all variables are properly set

### Testing

To verify your configuration:
1. Go to **Actions** tab in your repository
2. Select **Verify Environment Variables** workflow
3. Click **Run workflow**
4. Check the workflow logs to see which variables are properly configured

### Common Errors

**Error: "Required variable X is not set in GitHub secrets/variables"**
- Solution: Add the missing variable to your repository settings as described above

**Error: Workflow fails immediately**
- Solution: Ensure you have the necessary permissions to configure repository secrets and variables
