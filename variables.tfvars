################################################
# PR-CYBR Agent Terraform Variable Definitions #
# Populate these values within Terraform Cloud  #
# or override locally for development/testing.  #
################################################

# --- Docker / Registry ---
DOCKERHUB_TOKEN         = "__SET_IN_TFC__"
DOCKERHUB_USERNAME      = "pr-cybr-bot"
DOCKER_USERNAME         = "__SET_IN_TFC__"
DOCKER_PASSWORD         = "__SET_IN_TFC__"
PR_CYBR_DOCKER_USER     = "__SET_IN_TFC__"
PR_CYBR_DOCKER_PASS     = "__SET_IN_TFC__"

# --- Global Infrastructure URIs ---
GLOBAL_DOMAIN                = "example.pr-cybr.dev"
GLOBAL_ELASTIC_URI           = "https://elastic.example.pr-cybr.dev"
GLOBAL_GRAFANA_URI           = "https://grafana.example.pr-cybr.dev"
GLOBAL_KIBANA_URI            = "https://kibana.example.pr-cybr.dev"
GLOBAL_PROMETHEUS_URI        = "https://prometheus.example.pr-cybr.dev"
GLOBAL_TAILSCALE_AUTHKEY     = "__SET_IN_TFC__"
GLOBAL_TRAEFIK_ACME_EMAIL    = "ops@example.pr-cybr.dev"
GLOBAL_TRAEFIK_ENTRYPOINTS   = "web,websecure"
GLOBAL_ZEROTIER_NETWORK_ID   = "__SET_IN_TFC__"

# --- Agent Tokens ---
AGENT_ACTIONS = "__SET_IN_TFC__"
AGENT_COLLAB  = "__SET_IN_TFC__"

# --- GitHub / Terraform Cloud ---
GITHUB_TOKEN = "__SET_IN_TFC__"
TFC_TOKEN    = "__SET_IN_TFC__"

# --- n8n Workflow Automation ---
N8N_ENCRYPTION_KEY       = "__SET_IN_TFC__"
N8N_WORKFLOW_WEBHOOK_URL = "https://n8n.example.pr-cybr.dev/webhook"
SLACK_CHANNEL_NAME       = "operations-alerts"
DISCORD_WEBHOOK_URL      = "__SET_IN_TFC__"
TRIGGER_URL              = "__SET_IN_TFC__"
N8N_USERNAME             = "n8n-bot"
N8N_PASSWORD             = "__SET_IN_TFC__"
