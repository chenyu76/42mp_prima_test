from dataclasses import dataclass

import matlab
import matlab.engine


@dataclass
class MatlabFunction:
    engine: matlab.engine.MatlabEngine
    problem_name: str
    field: str

    def __call__(
        self, *args: matlab.double | float | bool, nargout: int = 1
    ) -> float | matlab.double | tuple[float | matlab.double, ...] | None:
        return self.engine.matcutest_bridge(
            self.problem_name, self.field, *args, nargout=nargout
        )


@dataclass
class Problem:
    """Fields of the native MatCUTEst macup structure."""

    name: str
    type: str
    mexdir: str
    objective: MatlabFunction
    grad: MatlabFunction
    hprod: MatlabFunction
    x0: matlab.double
    Aineq: matlab.double
    bineq: matlab.double
    Aeq: matlab.double
    beq: matlab.double
    lb: matlab.double
    ub: matlab.double
    nonlcon: MatlabFunction | None
    f0: float
    g0: matlab.double
    nlcineq0: matlab.double
    nlceq0: matlab.double
    gnlcineq0: matlab.double
    gnlceq0: matlab.double
    constrv0: float
    numb: int
    numlb: int
    numub: int
    numfixedx: int
    numcon: int
    numlcon: int
    numnlcon: int
    numeq: int
    numineq: int
    numleq: int
    numlineq: int
    numnleq: int
    numnlineq: int
    is_feasibility: bool
    H0: matlab.double | None = None
