"""Flask application for the agent workflow dashboard."""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Dict, Optional

from flask import Flask, jsonify, redirect, render_template, request, url_for

from .services import BackendRegistry, create_backend_registry
from .store import DashboardStore

LOGGER = logging.getLogger(__name__)


def create_app(store: Optional[DashboardStore] = None, backend_registry: Optional[BackendRegistry] = None) -> Flask:
    base_path = Path(__file__).parent
    app = Flask(
        __name__,
        template_folder=str(base_path / "templates"),
        static_folder=str(base_path / "static"),
    )

    dashboard_store = store or DashboardStore()
    dashboard_store.ensure_seed_builders()
    registry = backend_registry or create_backend_registry(dashboard_store)

    @app.route("/")
    def index() -> str:
        builders = dashboard_store.get_builders()
        executions = dashboard_store.list_executions()
        return render_template("index.html", builders=builders, executions=executions)

    @app.route("/builders")
    def builders_page() -> str:
        builders = dashboard_store.get_builders()
        return render_template("builders.html", builders=builders)

    @app.route("/status/<execution_id>")
    def status_page(execution_id: str) -> str:
        execution = dashboard_store.get_execution(execution_id)
        if not execution:
            return redirect(url_for("index"))
        builder = dashboard_store.get_builder(execution.builder_id)
        return render_template("status.html", execution=execution, builder=builder)

    @app.route("/activity")
    def activity_page() -> str:
        return render_template("activity.html")

    @app.get("/api/builders")
    def api_builders() -> Dict[str, object]:
        data = [
            {
                "id": builder.id,
                "name": builder.name,
                "description": builder.description,
                "created_at": builder.created_at,
                "metadata": builder.metadata,
            }
            for builder in dashboard_store.get_builders()
        ]
        return jsonify({"builders": data})

    @app.post("/api/builders")
    def api_create_builder() -> Dict[str, object]:
        payload = request.get_json(force=True)
        builder = dashboard_store.register_builder(
            name=payload.get("name", "Untitled Builder"),
            description=payload.get("description", ""),
            metadata=payload.get("metadata"),
        )
        return jsonify({"builder": {
            "id": builder.id,
            "name": builder.name,
            "description": builder.description,
            "created_at": builder.created_at,
            "metadata": builder.metadata,
        }})

    @app.post("/api/execute")
    def api_execute() -> Dict[str, object]:
        payload = request.get_json(force=True)
        builder_id = payload.get("builder_id")
        backend_name = payload.get("backend", "codex")
        extra_payload = payload.get("payload", {})
        if not builder_id:
            return jsonify({"error": "builder_id is required"}), 400
        try:
            execution = registry.trigger_execution(backend_name, builder_id, extra_payload)
            dashboard_store.update_execution(execution["id"], status="running", log_line="Execution started")
        except KeyError as exc:
            LOGGER.exception("Execution trigger failed")
            return jsonify({"error": str(exc)}), 404
        return jsonify({"execution": execution})

    @app.get("/api/status/<execution_id>")
    def api_status(execution_id: str) -> Dict[str, object]:
        execution = dashboard_store.get_execution(execution_id)
        if not execution:
            return jsonify({"error": "Execution not found"}), 404
        return jsonify({"execution": execution.to_dict()})

    @app.get("/api/activity")
    def api_activity() -> Dict[str, object]:
        return jsonify({"activity": dashboard_store.list_activity()})

    @app.get("/api/executions")
    def api_executions() -> Dict[str, object]:
        executions = [record.to_dict() for record in dashboard_store.list_executions()]
        return jsonify({"executions": executions})

    return app


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    create_app().run(host="0.0.0.0", port=8000, debug=True)
