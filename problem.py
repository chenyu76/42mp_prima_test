from collections.abc import Callable
from dataclasses import dataclass

import numpy as np
from numpy.typing import NDArray


@dataclass
class Problem:
    """PyCUTEst metadata and evaluation callbacks, with matching names."""

    name: str
    n: int
    m: int
    x0: NDArray[np.float64]  # (n,)
    sifParams: dict[str, int | float] | None
    sifOptions: list[str] | None
    vartype: NDArray[np.integer]  # (n,)
    nnzh: int
    nonlinear_vars_first: bool
    bl: NDArray[np.float64]  # (n,)
    bu: NDArray[np.float64]  # (n,)
    n_full: int
    n_free: int
    n_fixed: int
    eq_cons_first: bool | None
    linear_cons_first: bool | None
    nnzj: int | None
    v0: NDArray[np.float64] | None  # (m,)
    cl: NDArray[np.float64] | None  # (m,)
    cu: NDArray[np.float64] | None  # (m,)
    is_eq_cons: NDArray[np.bool_] | None  # (m,)
    is_linear_cons: NDArray[np.bool_] | None  # (m,)

    objcons: Callable[..., object]
    obj: Callable[..., float | tuple[float, NDArray[np.float64]]]
    grad: Callable[..., NDArray[np.float64]]
    cons: Callable[..., object]
    lag: Callable[..., object]
    lagjac: Callable[..., object]
    jprod: Callable[..., NDArray[np.float64]]
    hess: Callable[..., NDArray[np.float64]]
    ihess: Callable[..., NDArray[np.float64]]
    hprod: Callable[..., NDArray[np.float64]]
    gradhess: Callable[..., object]
    sobj: Callable[..., object]
    sgrad: Callable[..., object]
    scons: Callable[..., object]
    slagjac: Callable[..., object]
    sphess: Callable[..., object]
    isphess: Callable[..., object]
    gradsphess: Callable[..., object]

