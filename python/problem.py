from collections.abc import Callable
from dataclasses import dataclass

import numpy as np
from numpy.typing import NDArray

FloatArray = NDArray[np.float64]


@dataclass
class Problem:
    """Derivative-free problem; cub(x) <= 0 and ceq(x) == 0."""

    name: str
    n: int
    x0: FloatArray  # (n,)
    xl: FloatArray  # (n,)
    xu: FloatArray  # (n,)
    aub: FloatArray  # (number of linear inequalities, n)
    bub: FloatArray  # (number of linear inequalities,)
    aeq: FloatArray  # (number of linear equalities, n)
    beq: FloatArray  # (number of linear equalities,)
    fun: Callable[[FloatArray], float]
    cub: Callable[[FloatArray], FloatArray]
    ceq: Callable[[FloatArray], FloatArray]
