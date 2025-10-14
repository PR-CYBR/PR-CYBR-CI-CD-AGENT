"""Lightweight in-memory store backing the dashboard."""
from __future__ import annotations

import time
import uuid
from dataclasses import dataclass, field
from threading import Lock
from typing import Any, Dict, Iterable, List, Optional


@dataclass
class FunctionBuilder:
    """Represents a function builder configuration."""

    id: str
    name: str
    description: str
    created_at: float = field(default_factory=time.time)
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ExecutionRecord:
    """Represents an execution triggered from the dashboard."""

    id: str
    builder_id: str
    status: str
    created_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)
    logs: List[str] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "builder_id": self.builder_id,
            "status": self.status,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "logs": list(self.logs),
            "metadata": dict(self.metadata),
        }


class DashboardStore:
    """Thread-safe in-memory persistence layer."""

    def __init__(self) -> None:
        self._builders: Dict[str, FunctionBuilder] = {}
        self._executions: Dict[str, ExecutionRecord] = {}
        self._activity: List[Dict[str, Any]] = []
        self._lock = Lock()

    def register_builder(self, name: str, description: str, metadata: Optional[Dict[str, Any]] = None) -> FunctionBuilder:
        with self._lock:
            builder_id = str(uuid.uuid4())
            builder = FunctionBuilder(
                id=builder_id,
                name=name,
                description=description,
                metadata=metadata or {},
            )
            self._builders[builder_id] = builder
            self._activity.append(
                {
                    "type": "builder_registered",
                    "builder_id": builder_id,
                    "name": name,
                    "timestamp": time.time(),
                }
            )
            return builder

    def get_builders(self) -> Iterable[FunctionBuilder]:
        with self._lock:
            return list(self._builders.values())

    def get_builder(self, builder_id: str) -> Optional[FunctionBuilder]:
        with self._lock:
            return self._builders.get(builder_id)

    def create_execution(self, builder_id: str, metadata: Optional[Dict[str, Any]] = None) -> ExecutionRecord:
        with self._lock:
            if builder_id not in self._builders:
                raise KeyError(f"Unknown builder: {builder_id}")
            exec_id = str(uuid.uuid4())
            record = ExecutionRecord(
                id=exec_id,
                builder_id=builder_id,
                status="queued",
                metadata=metadata or {},
            )
            self._executions[exec_id] = record
            self._activity.append(
                {
                    "type": "execution_created",
                    "execution_id": exec_id,
                    "builder_id": builder_id,
                    "timestamp": time.time(),
                }
            )
            return record

    def update_execution(self, execution_id: str, status: Optional[str] = None, log_line: Optional[str] = None, metadata: Optional[Dict[str, Any]] = None) -> ExecutionRecord:
        with self._lock:
            record = self._executions.get(execution_id)
            if not record:
                raise KeyError(f"Unknown execution: {execution_id}")
            if status:
                record.status = status
            if metadata:
                record.metadata.update(metadata)
            if log_line:
                record.logs.append(log_line)
                self._activity.append(
                    {
                        "type": "log",
                        "execution_id": execution_id,
                        "message": log_line,
                        "timestamp": time.time(),
                    }
                )
            record.updated_at = time.time()
            return record

    def get_execution(self, execution_id: str) -> Optional[ExecutionRecord]:
        with self._lock:
            record = self._executions.get(execution_id)
            if record:
                return ExecutionRecord(**record.to_dict())
            return None

    def list_executions(self) -> List[ExecutionRecord]:
        with self._lock:
            return [ExecutionRecord(**record.to_dict()) for record in self._executions.values()]

    def list_activity(self, limit: int = 50) -> List[Dict[str, Any]]:
        with self._lock:
            return list(self._activity[-limit:])

    def ensure_seed_builders(self) -> None:
        """Populate the store with demo builders if empty."""
        with self._lock:
            if self._builders:
                return
            demos = [
                (
                    "Summarizer",
                    "Generate summaries of documents using Codex/AgentKit",
                ),
                (
                    "Sentiment Analyzer",
                    "Classify sentiment for customer feedback",
                ),
            ]
            for name, description in demos:
                builder_id = str(uuid.uuid4())
                self._builders[builder_id] = FunctionBuilder(
                    id=builder_id,
                    name=name,
                    description=description,
                )

    def reset(self) -> None:
        with self._lock:
            self._builders.clear()
            self._executions.clear()
            self._activity.clear()
