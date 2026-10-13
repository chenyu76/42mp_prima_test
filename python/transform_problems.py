from collections.abc import Callable

import numpy as np

from config import (
    TOUGH_FIXED_VARIABLES,
    TOUGH_INVALID_LINEAR,
    TOUGH_NOISE_LEVEL,
    TOUGH_RUNS,
    TOUGH_SEED,
    TOUGH_WITH_FAILURE,
)
from problem import FloatArray, Problem


def transform_problems(problems: list[Problem]) -> list[Problem]:
    """Return tough variants for each problem, preserving the inputs."""
    transformed: list[Problem] = []
    for problem in problems:
        name_seed = sum((i + 1) * ord(char) for i, char in enumerate(problem.name))
        for run in range(1, TOUGH_RUNS + 1):
            seed = (TOUGH_SEED + name_seed + 104729 * run) % 2**32
            transformed.append(make_tough_problem(problem, seed))
    return transformed


def make_tough_problem(
    base: Problem,
    seed: int,
    noise_level: float = TOUGH_NOISE_LEVEL,
    with_failure: bool = TOUGH_WITH_FAILURE,
    invalid_linear: bool = TOUGH_INVALID_LINEAR,
    fixed_variables: bool = TOUGH_FIXED_VARIABLES,
) -> Problem:
    """Return a perturbed problem with deterministic evaluation noise."""
    rng = np.random.Generator(np.random.MT19937(seed))
    x0 = base.x0 + noise_level * np.maximum(1, np.abs(base.x0)) * rng.standard_normal(base.n)
    xl, xu = base.xl.copy(), base.xu.copy()
    xl_work, xu_work = np.maximum(-1e10, xl), np.minimum(1e10, xu)
    width = np.maximum(0, xu_work - xl_work)
    bound_scale = noise_level * 0.9 * np.minimum(1, width)
    finite_xl, finite_xu = np.isfinite(xl), np.isfinite(xu)
    xl[finite_xl] = xl_work[finite_xl] + bound_scale[finite_xl] * (
        rng.random(np.count_nonzero(finite_xl)) - 1
    )
    xu[finite_xu] = xu_work[finite_xu] + bound_scale[finite_xu] * (
        rng.random(np.count_nonzero(finite_xu)) - 1
    )

    if fixed_variables:
        candidates = np.flatnonzero(np.isfinite(xl) & np.isfinite(xu))
        fixed = candidates[rng.random(candidates.size) < 0.2]
        choose_lower = rng.random(fixed.size) < 0.5
        xu[fixed[choose_lower]] = xl[fixed[choose_lower]]
        xl[fixed[~choose_lower]] = xu[fixed[~choose_lower]]

    aub, bub = _tough_linear_data(base.aub, base.bub, rng, noise_level, invalid_linear)
    aeq, beq = _tough_linear_data(base.aeq, base.beq, rng, noise_level, invalid_linear)

    def fun(x: FloatArray) -> float:
        return _contaminate(base.fun(x), x, seed, noise_level, with_failure, 0)

    def cub(x: FloatArray) -> FloatArray:
        return _contaminate_vector(base.cub, x, seed, noise_level, 1)

    def ceq(x: FloatArray) -> FloatArray:
        return _contaminate_vector(base.ceq, x, seed, noise_level, 2)

    return Problem(
        name=f"{base.name}_tough_{seed:010d}", n=base.n, x0=x0,
        xl=xl, xu=xu, aub=aub, bub=bub, aeq=aeq, beq=beq,
        fun=fun, cub=cub, ceq=ceq,
    )


def _tough_linear_data(
    matrix: FloatArray,
    rhs: FloatArray,
    rng: np.random.Generator,
    noise_level: float,
    invalid_linear: bool,
) -> tuple[FloatArray, FloatArray]:
    if matrix.size == 0:
        return matrix.copy(), rhs.copy()
    matrix = matrix + noise_level * np.maximum(1, np.abs(matrix)) * rng.standard_normal(matrix.shape)
    rhs = rhs + noise_level * np.maximum(1, np.abs(rhs)) * rng.standard_normal(rhs.shape)
    if invalid_linear:
        for array in (matrix, rhs):
            for value in (np.inf, -np.inf, np.nan):
                array[rng.random(array.shape) > 0.97] = value
    return matrix, rhs


def _contaminate_vector(
    callback: Callable[[FloatArray], FloatArray],
    x: FloatArray,
    seed: int,
    noise_level: float,
    channel: int,
) -> FloatArray:
    values = callback(x).copy()
    # The legacy transformation injects exceptions only into the objective.
    for i, value in enumerate(values):
        values[i] = _contaminate(value, x, seed, noise_level, False, channel * 100000 + i + 1)
    return values


def _contaminate(
    value: float,
    x: FloatArray,
    seed: int,
    noise_level: float,
    with_failure: bool,
    salt: int,
) -> float:
    # Seed from x's hexadecimal representation, independently of call order.
    text_sum = sum(map(ord, np.asarray(x, dtype=">f8").tobytes().hex()))
    local_seed = (seed + salt + text_sum) % 2**32
    rng = np.random.Generator(np.random.MT19937(local_seed))
    value = float(value) * (1 + noise_level * rng.standard_normal())
    r = 2 * rng.random() - 1
    if r > 0.9:
        if with_failure:
            raise RuntimeError("Injected tough-problem evaluation failure.")
        return np.nan
    if r > 0.8:
        return np.nan
    if r > 0.7:
        return np.inf
    if r < -0.9:
        return -1e30
    return float(value)
