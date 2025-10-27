#############################################
# PR-CYBR Agent Terraform Variable Schema   #
# All values are sourced from Terraform      #
# Cloud workspace variables. No secrets are  #
# committed to this repository.              #
#############################################

variable "AGENT_ID" {
  type = string
}

variable "PR_CYBR_DOCKER_USER" {
  type = string
}

variable "PR_CYBR_DOCKER_PASS" {
  type      = string
  sensitive = true
}

variable "DOCKERHUB_USERNAME" {
  type = string
}

variable "DOCKERHUB_TOKEN" {
  type      = string
  sensitive = true
}

variable "GLOBAL_DOMAIN" {
  type = string
}

variable "AGENT_ACTIONS" {
  type      = string
  sensitive = true
}

variable "NOTION_TOKEN" {
  type      = string
  sensitive = true
}

variable "NOTION_DISCUSSIONS_ARC_DB_ID" {
  type = string
}

variable "NOTION_ISSUES_BACKLOG_DB_ID" {
  type = string
}

variable "NOTION_KNOWLEDGE_FILE_DB_ID" {
  type = string
}

variable "NOTION_PROJECT_BOARD_BACKLOG_DB_ID" {
  type = string
}

variable "NOTION_PR_BACKLOG_DB_ID" {
  type = string
}

variable "NOTION_TASK_BACKLOG_DB_ID" {
  type = string
}

variable "NOTION_PAGE_ID" {
  type = string
}

variable "TFC_TOKEN" {
  type      = string
  sensitive = true
}
