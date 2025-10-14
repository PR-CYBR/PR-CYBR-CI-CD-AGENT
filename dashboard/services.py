"""Service layer stubs for integrating Codex/AgentKit backends."""
from __future__ import annotations

import logging
from typing import Any, Dict, Optional

from .store import DashboardStore

LOGGER = logging.getLogger(__name__)


class BackendInterface:
    """Common interface for future real-time execution backends."""

    name: str

    def warmup(self) -> None:
        """Prepare the backend."""

    def trigger(self, builder_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Submit a job to the backend and return metadata."""
        raise NotImplementedError


class CodexBackend(BackendInterface):
    name = "codex"

    def warmup(self) -> None:  # pragma: no cover - placeholder logic
        LOGGER.info("Codex backend warmup complete (placeholder).")

    def trigger(self, builder_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        LOGGER.info("Triggering Codex execution for %s with payload %s", builder_id, payload)
        return {"backend": self.name, "accepted": True}


class AgentKitBackend(BackendInterface):
    name = "agentkit"

    def warmup(self) -> None:  # pragma: no cover - placeholder logic
        LOGGER.info("AgentKit backend warmup complete (placeholder).")

    def trigger(self, builder_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        LOGGER.info("Triggering AgentKit execution for %s with payload %s", builder_id, payload)
        return {"backend": self.name, "accepted": True}


class BackendRegistry:
    """Registry for available execution backends."""

    def __init__(self, store: DashboardStore) -> None:
        self.store = store
        self.backends: Dict[str, BackendInterface] = {
            CodexBackend.name: CodexBackend(),
            AgentKitBackend.name: AgentKitBackend(),
        }

    def get(self, name: str) -> Optional[BackendInterface]:
        return self.backends.get(name)

    def trigger_execution(self, backend_name: str, builder_id: str, payload: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        backend = self.get(backend_name)
        if not backend:
            raise KeyError(f"Unknown backend: {backend_name}")
        backend.warmup()
        payload = payload or {}
        metadata = backend.trigger(builder_id, payload)
        execution = self.store.create_execution(builder_id, metadata={"backend": backend_name, **metadata})
        LOGGER.info("Execution %s created via backend %s", execution.id, backend_name)
        return execution.to_dict()


def create_backend_registry(store: DashboardStore) -> BackendRegistry:
    return BackendRegistry(store)
