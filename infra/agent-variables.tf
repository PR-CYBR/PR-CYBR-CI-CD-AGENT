#############################################
# PR-CYBR Agent Variable Locals             #
# Maps Terraform Cloud inputs into logical  #
# groupings consumed by downstream modules. #
#############################################

locals {
  agent_identity = {
    id             = var.AGENT_ID
    notion_page_id = var.NOTION_PAGE_ID
  }

  docker_registry = {
    pr_cybr_user       = var.PR_CYBR_DOCKER_USER
    pr_cybr_pass       = var.PR_CYBR_DOCKER_PASS
    dockerhub_username = var.DOCKERHUB_USERNAME
    dockerhub_token    = var.DOCKERHUB_TOKEN
  }

  automation_tokens = {
    agent_actions = var.AGENT_ACTIONS
    notion_token  = var.NOTION_TOKEN
    tfc_token     = var.TFC_TOKEN
  }

  notion_databases = {
    discussions_arc_db_id       = var.NOTION_DISCUSSIONS_ARC_DB_ID
    issues_backlog_db_id        = var.NOTION_ISSUES_BACKLOG_DB_ID
    knowledge_file_db_id        = var.NOTION_KNOWLEDGE_FILE_DB_ID
    project_board_backlog_db_id = var.NOTION_PROJECT_BOARD_BACKLOG_DB_ID
    pr_backlog_db_id            = var.NOTION_PR_BACKLOG_DB_ID
    task_backlog_db_id          = var.NOTION_TASK_BACKLOG_DB_ID
  }

  global = {
    domain = var.GLOBAL_DOMAIN
  }
}

output "agent_identity" {
  description = "Agent specific identifiers"
  value       = local.agent_identity
}

output "docker_registry" {
  description = "Docker registry credentials sourced from TFC"
  value       = local.docker_registry
  sensitive   = true
}

output "automation_tokens" {
  description = "Tokens required by automation tooling"
  value       = local.automation_tokens
  sensitive   = true
}

output "notion_databases" {
  description = "Notion database identifiers shared across PR-CYBR"
  value       = local.notion_databases
}

output "global" {
  description = "Global infrastructure configuration"
  value       = local.global
}
