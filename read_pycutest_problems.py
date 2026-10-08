from __future__ import annotations

import os
from typing import TYPE_CHECKING

import numpy as np

from config import CUTEST_DIR, LINKER_FLAGS, MASTSIF_DIR, PROJECT_DIR, SIFDECODE_DIR
from problem import FloatArray, Problem

if TYPE_CHECKING:
    from pycutest import CUTEstProblem


def read_pycutest_problems() -> list[Problem]:
    """No inputs. Return derivative-free problems loaded from PyCUTEst."""
    for variable, directory in (
        ("CUTEST", CUTEST_DIR),
        ("SIFDECODE", SIFDECODE_DIR),
        ("MASTSIF", MASTSIF_DIR),
    ):
        if directory is not None:
            os.environ[variable] = str((PROJECT_DIR / directory).resolve())
    os.environ["PYCUTEST_CACHE"] = str(PROJECT_DIR)
    os.environ["LDFLAGS"] = LINKER_FLAGS

    import pycutest

    return [_convert_problem(pycutest.import_problem(name)) for name in pycutest.find_problems()]


def _bounds(lower: FloatArray, upper: FloatArray) -> tuple[FloatArray, FloatArray]:
    lower, upper = lower.copy(), upper.copy()
    lower[lower <= -1e20] = -np.inf
    upper[upper >= 1e20] = np.inf
    return lower, upper


def _convert_problem(source: CUTEstProblem) -> Problem:
    """Convert bounded CUTEst constraints into linear rows and residuals."""
    xl, xu = _bounds(source.bl, source.bu)
    aub_rows, bub_values, aeq_rows, beq_values = [], [], [], []
    if source.m:
        cl, cu = _bounds(source.cl, source.cu)
        linear = source.is_linear_cons
        equality = source.is_eq_cons
        zero = np.zeros(source.n)
        for i in np.flatnonzero(linear):
            # A linear constraint is A[i] @ x + offset; query it at zero.
            offset, gradient = source.scons(zero, index=int(i), gradient=True)
            row = gradient.toarray().reshape(source.n)
            if equality[i]:
                aeq_rows.append(row)
                beq_values.append(cl[i] - offset)
            else:
                if np.isfinite(cu[i]):
                    aub_rows.append(row)
                    bub_values.append(cu[i] - offset)
                if np.isfinite(cl[i]):
                    aub_rows.append(-row)
                    bub_values.append(offset - cl[i])
        nonlinear_eq = ~linear & equality
        nonlinear_upper = ~linear & ~equality & np.isfinite(cu)
        nonlinear_lower = ~linear & ~equality & np.isfinite(cl)
    else:
        cl, cu = np.empty(0), np.empty(0)
        nonlinear_eq = nonlinear_upper = nonlinear_lower = np.zeros(0, dtype=bool)

    def fun(x: FloatArray) -> float:
        return float(source.obj(x))

    def cub(x: FloatArray) -> FloatArray:
        if not (np.any(nonlinear_upper) or np.any(nonlinear_lower)):
            return np.empty(0)
        values = source.cons(x)
        return np.concatenate((
            values[nonlinear_upper] - cu[nonlinear_upper],
            cl[nonlinear_lower] - values[nonlinear_lower],
        ))

    def ceq(x: FloatArray) -> FloatArray:
        if not np.any(nonlinear_eq):
            return np.empty(0)
        return source.cons(x)[nonlinear_eq] - cl[nonlinear_eq]

    return Problem(
        name=source.name, n=source.n, x0=source.x0.copy(), xl=xl, xu=xu,
        aub=np.asarray(aub_rows, dtype=float).reshape(len(aub_rows), source.n),
        bub=np.asarray(bub_values, dtype=float),
        aeq=np.asarray(aeq_rows, dtype=float).reshape(len(aeq_rows), source.n),
        beq=np.asarray(beq_values, dtype=float),
        fun=fun, cub=cub, ceq=ceq,
    )
