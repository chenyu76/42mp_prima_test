from __future__ import annotations

import os
import re
import subprocess
import warnings
from pathlib import Path
from itertools import product
from collections.abc import Iterator
from typing import TYPE_CHECKING

import numpy as np
from tqdm import tqdm

from config import CUTEST_DIR, LINKER_FLAGS, MASTSIF_DIR, PROJECT_DIR, SIFDECODE_DIR
from problem import FloatArray, Problem
from pycutest_dimensions import DimensionIndex

if TYPE_CHECKING:
    from pycutest import CUTEstProblem


def get_pycutest_problems(min_dimension: int, max_dimension: int) -> list[Problem]:
    """Return available SIF-listed dimensions in the inclusive interval."""
    if min_dimension < 0 or max_dimension < min_dimension:
        raise ValueError("Require 0 <= min_dimension <= max_dimension.")
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

    problems: list[Problem] = []
    names = pycutest.find_problems()
    index = DimensionIndex(PROJECT_DIR / ".venv/pycutest_dimensions.json")
    with tqdm(total=len(names), desc="Loading problems", unit="problem") as progress:
        try:
            for name in names:
                dimensions: set[int] = set()
                progress.set_postfix_str(name)
                for parameters in index.parameters(name):
                    progress.set_postfix_str(f"{name} {parameters}" if parameters else name)
                    try:
                        n = index.get(name, parameters)
                        if not min_dimension <= n <= max_dimension or n in dimensions:
                            continue
                        source = pycutest.import_problem(name, sifParams=parameters or None)
                    except (RuntimeError, ImportError, subprocess.CalledProcessError) as error:
                        warnings.warn(f"Unavailable problem {name}, parameters {parameters}: {error}")
                        continue
                    if min_dimension <= source.n <= max_dimension and source.n not in dimensions:
                        problem = _convert_problem(source)
                        if parameters:
                            problem.name = f"{name}_n{source.n}"
                        problems.append(problem)
                        dimensions.add(source.n)
                progress.update(1)
        finally:
            index.save()
    return problems


def _parameter_combinations(name: str) -> Iterator[dict[str, int | float]]:
    """Read independent parameter choices directly from their SIF definitions."""
    from pycutest.system_paths import get_mastsif_path

    sif = Path(get_mastsif_path()) / (name + ".SIF")
    choices: dict[str, list[int | float]] = {}
    defaults: set[str] = set()
    with sif.open(errors="replace") as stream:
        for line in stream:
            # SIFDecode recognizes this marker only in columns 40--50.
            kind = line[1:3]
            if line[39:50] != "$-PARAMETER" or kind not in ("IE", "RE"):
                continue
            comment = line[:1] == "*"
            parameter, text, annotation = line[4:14].strip(), line[24:36].strip(), line[50:]
            if re.search(r"\bfor\b", annotation, re.IGNORECASE):
                continue
            value = float(text.replace("D", "e").replace("d", "e"))
            if kind == "IE":
                value = int(value)
            values = choices.setdefault(parameter, [])
            if value not in values:
                values.append(value)
            if not comment:
                defaults.add(parameter)
    # Keep fixed defaults in SIF; explicitly supply a lone value if no default exists.
    choices = {key: values for key, values in choices.items() if len(values) > 1 or key not in defaults}
    for values in product(*choices.values()):
        yield dict(zip(choices, values))


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
