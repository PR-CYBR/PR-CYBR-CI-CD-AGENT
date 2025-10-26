#############################################
# PR-CYBR Agent Variables (Generic Baseline)
# This file declares variables expected by
# Terraform Cloud across all PR-CYBR Agents.
# Real values are securely managed in TFC.
#############################################

# --- Docker / Registry ---
variable "DOCKERHUB_TOKEN" {
  type        = string
  sensitive   = true
  description = "Docker Hub access token"
}

variable "DOCKERHUB_USERNAME" {
  type        = string
  description = "Docker Hub username"
}

variable "DOCKER_USERNAME" {
  type        = string
  description = "Username for Docker Hub sync workflows"
}

variable "DOCKER_PASSWORD" {
  type        = string
  sensitive   = true
  description = "Password or access token for Docker Hub sync workflows"
}

variable "PR_CYBR_DOCKER_USER" {
  type        = string
  description = "Service account user for PR-CYBR Docker image publishing"
}

variable "PR_CYBR_DOCKER_PASS" {
  type        = string
  sensitive   = true
  description = "Credential for PR-CYBR Docker image publishing"
}

# --- Global Infrastructure URIs ---
variable "GLOBAL_DOMAIN" {
  type        = string
  description = "Root DNS domain for PR-CYBR services"
}

variable "GLOBAL_ELASTIC_URI" {
  type        = string
  description = "Elasticsearch endpoint"
}

variable "GLOBAL_GRAFANA_URI" {
  type        = string
  description = "Grafana endpoint"
}

variable "GLOBAL_KIBANA_URI" {
  type        = string
  description = "Kibana endpoint"
}

variable "GLOBAL_PROMETHEUS_URI" {
  type        = string
  description = "Prometheus endpoint"
}

# --- Networking / Security ---
variable "GLOBAL_TAILSCALE_AUTHKEY" {
  type        = string
  sensitive   = true
  description = "Auth key for Tailscale VPN/DNS"
}

variable "GLOBAL_TRAEFIK_ACME_EMAIL" {
  type        = string
  description = "Email used by Traefik for Let's Encrypt"
}

variable "GLOBAL_TRAEFIK_ENTRYPOINTS" {
  type        = string
  description = "Default entrypoints for Traefik"
}

variable "GLOBAL_ZEROTIER_NETWORK_ID" {
  type        = string
  sensitive   = true
  description = "ZeroTier overlay network ID"
}

# --- Agent Tokens ---
variable "AGENT_ACTIONS" {
  type        = string
  sensitive   = true
  description = "Token for CI/CD pipelines (builds, tests, deploys)"
}

variable "AGENT_COLLAB" {
  type        = string
  sensitive   = true
  description = "Token for governance, discussions, issues, project boards"
}

# --- GitHub / Terraform Cloud ---
variable "GITHUB_TOKEN" {
  type        = string
  sensitive   = true
  description = "Personal access token used by the tfc-sync workflow"
}

variable "TFC_TOKEN" {
  type        = string
  sensitive   = true
  description = "Terraform Cloud API token for CLI authentication"
}

# --- n8n Workflow Automation ---
variable "N8N_ENCRYPTION_KEY" {
  type        = string
  sensitive   = true
  description = "Encryption key used by n8n instances"
}

variable "N8N_WORKFLOW_WEBHOOK_URL" {
  type        = string
  sensitive   = true
  description = "Webhook endpoint for triggering n8n workflows"
}

variable "SLACK_CHANNEL_NAME" {
  type        = string
  description = "Slack channel identifier for workflow notifications"
}

variable "DISCORD_WEBHOOK_URL" {
  type        = string
  sensitive   = true
  description = "Discord webhook for workflow notifications"
}

variable "TRIGGER_URL" {
  type        = string
  sensitive   = true
  description = "Trigger URL for external workflow invocations"
}

variable "N8N_USERNAME" {
  type        = string
  description = "Username for authenticating to n8n"
}

variable "N8N_PASSWORD" {
  type        = string
  sensitive   = true
  description = "Password for authenticating to n8n"
}
