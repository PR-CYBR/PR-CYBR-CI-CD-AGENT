# Agent Dashboard

This dashboard provides a lightweight control plane for managing Codex/AgentKit powered agents. It includes a Flask-based backend, in-memory activity store, and polling-based frontend for real-time updates.

## Features

- Function builder registry with placeholder metadata storage.
- Execution trigger interface with backend selection (Codex or AgentKit stubs).
- Status pages showing execution metadata and logs.
- Activity feed that polls the backend for new events.

## Getting Started

### Prerequisites

- Python 3.9+
- Recommended: Create a virtual environment to isolate dependencies.

Install dependencies:

```bash
pip install flask
```

> **Note:** For production deployments you may wish to pin versions and include websocket libraries (e.g., `flask-socketio`) if you plan to extend the real-time interface beyond polling.

### Environment Variables

The application currently supports the following optional variables:

- `DASHBOARD_HOST` – Host interface to bind (default `0.0.0.0`).
- `DASHBOARD_PORT` – Port to bind (default `8000`).
- `DASHBOARD_DEBUG` – Set to `1` to enable Flask debug mode.

Authentication is not enabled by default. When exposing the dashboard publicly, ensure you add authentication middleware (e.g., basic auth, OAuth) and HTTPS termination. The `BackendRegistry` exposes a single entry point where you can enforce per-backend authentication/authorization checks.

### Running Locally

```bash
export FLASK_APP=dashboard.app:create_app
export FLASK_RUN_HOST=${DASHBOARD_HOST:-0.0.0.0}
export FLASK_RUN_PORT=${DASHBOARD_PORT:-8000}
flask run
```

Alternatively, run the module directly:

```bash
python -m dashboard.app
```

Once running, navigate to `http://localhost:8000` to access the dashboard.

### Running in CI Containers

1. Ensure your CI image installs `flask` and any optional dependencies.
2. Expose the dashboard port as an artifact or forwarded port depending on your CI platform.
3. Set environment variables via your CI secret store. For agent integrations you may add variables like `CODEX_API_KEY` and `AGENTKIT_API_KEY` and extend the backend stubs to read them.
4. Use the `BackendRegistry` hooks (`backend_registry.trigger_execution`) to integrate with your orchestration stack.

### Extending Backend Integrations

- Implement the `BackendInterface.trigger` method for each backend with real API calls.
- Use `DashboardStore.update_execution` to push log lines or status changes as callbacks are received.
- Replace the in-memory store with Redis, SQLite, or another persistent system if required for multi-process deployments.

### Frontend Customization

The static assets live in `dashboard/static/` and templates in `dashboard/templates/`. Modify these files to customize styling or add new components. The included JavaScript polls the backend every few seconds to keep the UI updated; you can swap this for a WebSocket implementation if your infrastructure supports it.
