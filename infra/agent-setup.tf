#############################################
# PR-CYBR Agent Terraform Entry Point       #
# This module intentionally remains minimal  #
# because all actionable infrastructure is   #
# orchestrated centrally through Terraform   #
# Cloud. Local runs validate that all        #
# required variables are wired correctly.    #
#############################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
  }
}

# Placeholder null_resource to ensure terraform plan succeeds while
# still validating variable resolution. Downstream modules within
# Terraform Cloud consume the exported locals defined in
# agent-variables.tf.
resource "null_resource" "agent_configuration" {
  triggers = {
    agent_id          = var.AGENT_ID
    notion_page_id    = var.NOTION_PAGE_ID
    global_domain     = var.GLOBAL_DOMAIN
    dockerhub_user    = var.DOCKERHUB_USERNAME
    pr_cybr_docker    = var.PR_CYBR_DOCKER_USER
    notion_token_hash = md5(var.NOTION_TOKEN)
  }
}
