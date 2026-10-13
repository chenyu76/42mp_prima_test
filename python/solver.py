from collections.abc import Mapping
from dataclasses import dataclass
from typing import Protocol

from problem import FloatArray, Problem


@dataclass
class SolverResult:
    """Final solution; status and output retain the solver's native meanings."""

    x: FloatArray  # (n,)
    fun: float
    status: int
    output: dict[str, object]


class Solver(Protocol):
    def __call__(
        self,
        problem: Problem,
        *,
        options: Mapping[str, object] | None = None,
    ) -> SolverResult:
        """Solve a problem with optional solver-specific settings."""
        ...
