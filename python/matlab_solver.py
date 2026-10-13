from __future__ import annotations

import os
from collections.abc import Mapping
from typing import TYPE_CHECKING

import numpy as np

from config import MATLAB_LD_PRELOAD, MATLAB_STARTUP_OPTIONS, PRIMA_DIR, PROJECT_DIR
from matlab_callback import problem_bridge
from problem import Problem
from solver import SolverResult

if TYPE_CHECKING:
    from matlab.engine import MatlabEngine


class MatlabSolver:
    """Python solver interface backed by a MATLAB function and an existing engine."""

    def __init__(self, engine: MatlabEngine, function_name: str) -> None:
        self.engine = engine
        self.function_name = function_name

    def __call__(
        self,
        problem: Problem,
        *,
        options: Mapping[str, object] | None = None,
    ) -> SolverResult:
        """Accept a Python problem and settings; return a Python solver result."""
        self.engine.addpath(str(PROJECT_DIR), nargout=0)
        if PRIMA_DIR is not None:
            directory = (PROJECT_DIR / PRIMA_DIR).resolve() / "matlab"
            self.engine.addpath(str(directory / "interfaces"), str(directory / "setup_tools"), nargout=0)
        if self.engine.eval("char(pyenv().Status)", nargout=1) == "NotLoaded":
            self.engine.pyenv(
                "Version", str(PROJECT_DIR / ".venv/bin/python"),
                "ExecutionMode", "OutOfProcess", nargout=0,
            )
        fields = self.wrap_problem(problem)
        settings = dict(options) if options is not None else {}
        with problem_bridge(problem) as address:
            result = self.engine.run_matlab_solver(
                self.function_name.lower(), fields, settings, address, nargout=4,
            )
        return self.unwrap_result(*result)

    def wrap_problem(self, problem: Problem) -> dict[str, object]:
        """Return problem data; MATLAB creates callbacks through the bridge."""
        import matlab

        fields: dict[str, object] = {"name": problem.name, "n": float(problem.n)}
        for name in ("x0", "xl", "xu", "aub", "bub", "aeq", "beq"):
            array = getattr(problem, name)
            shape = array.shape if array.ndim == 2 else (array.size, 1)
            fields[name] = matlab.double(array.ravel(order="F").tolist(), size=shape)
        return fields

    def unwrap_result(
        self,
        x: object,
        fun: object,
        status: object,
        output: object,
    ) -> SolverResult:
        """Convert MATLAB solution, objective, status, and output into a result."""
        if not isinstance(output, dict):
            raise TypeError("Expected a MATLAB scalar struct as solver output.")
        return SolverResult(
            x=np.asarray(x, dtype=float).reshape(-1).copy(),
            fun=float(np.asarray(fun).item()),
            status=int(np.asarray(status).item()),
            output={key: _python_value(value) for key, value in output.items()},
        )


def _python_value(value: object) -> object:
    """Convert double arrays and nested solver output containers to Python."""
    import matlab

    if isinstance(value, matlab.double):
        return np.asarray(value, dtype=float).copy()
    if isinstance(value, dict):
        return {key: _python_value(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_python_value(item) for item in value]
    return value


def start_matlab() -> MatlabEngine:
    """Start an engine using the machine-specific launcher settings in config."""
    import matlab.engine

    if MATLAB_LD_PRELOAD is not None:
        os.environ["LD_PRELOAD"] = MATLAB_LD_PRELOAD
    return matlab.engine.start_matlab(MATLAB_STARTUP_OPTIONS)
