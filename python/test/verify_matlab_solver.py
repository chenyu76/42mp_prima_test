"""Run the legacy PRIMA interfaces through the Python MATLAB adapter."""
import os
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import numpy as np

from matlab_solver import MatlabSolver, start_matlab
from problem import Problem
from config import CUTEST_DIR, LINKER_FLAGS, MASTSIF_DIR, PRIMA_DIR, PRIMA_SOURCE_DIR, PROJECT_DIR, SIFDECODE_DIR
from get_pycutest_problems import _convert_problem


def main() -> None:
    assert PRIMA_DIR is not None
    prima_dir = PROJECT_DIR / PRIMA_DIR
    if not (prima_dir / 'matlab').exists():
        shutil.copytree(PROJECT_DIR / PRIMA_SOURCE_DIR / 'matlab', prima_dir / 'matlab')
    calls: dict[str, int] = {'fun': 0, 'cub': 0, 'ceq': 0}

    def fun(x: np.ndarray) -> float:
        calls['fun'] += 1
        assert x.shape == (2,)
        return float(np.sum((x - [1.0, 2.0]) ** 2))

    def cub(x: np.ndarray) -> np.ndarray:
        calls['cub'] += 1
        return np.array([x @ x - 1.0])

    def ceq(x: np.ndarray) -> np.ndarray:
        calls['ceq'] += 1
        return np.empty(0)

    problem = Problem(
        name='QUADRATIC', n=2, x0=np.array([0.25, 0.25]),
        xl=np.zeros(2), xu=np.full(2, 3.0),
        aub=np.array([[1.0, 1.0]]), bub=np.array([2.5]),
        aeq=np.empty((0, 2)), beq=np.empty(0),
        fun=fun, cub=cub, ceq=ceq,
    )
    print('Starting MATLAB.', flush=True)
    engine = start_matlab()
    try:
        print(f'MATLAB {engine.version(nargout=1)}', flush=True)
        tools = prima_dir / 'matlab/setup_tools'
        runtime = prima_dir / 'matlab/interfaces/private'
        if not (runtime / 'all_precisions.m').exists():
            engine.addpath(str(tools), nargout=0)
            engine.create_all_precisions(str(runtime), nargout=0)
            engine.create_all_variants(str(runtime), nargout=0)
            engine.copy_shared_tools(str(tools), str(runtime), nargout=0)
        for name in ('uobyqa', 'newuoa', 'bobyqa', 'lincoa', 'cobyla'):
            before = calls['fun']
            result = MatlabSolver(engine, name)(
                problem, options={'fortran': False, 'quiet': True, 'maxfun': 300},
            )
            assert result.x.shape == (2,), result
            assert np.isfinite(result.fun), result
            assert np.isclose(result.fun, fun(result.x)), result
            assert calls['fun'] > before + 1, calls
            if name in ('uobyqa', 'newuoa', 'bobyqa'):
                assert result.fun < 1e-8, result
            if name == 'lincoa':
                assert np.sum(result.x) <= 2.5 + 1e-5, result
                assert abs(result.fun - 0.125) < 1e-4, result
            if name == 'cobyla':
                assert result.x @ result.x <= 1.0 + 1e-4, result
                assert abs(result.fun - (np.sqrt(5.0) - 1.0) ** 2) < 1e-3, result
                assert calls['cub'] > 0 and calls['ceq'] > 0, calls
            print(f'{name}: x={result.x}, f={result.fun}, status={result.status}, callbacks={calls}', flush=True)
        for variable, directory in (
            ('CUTEST', CUTEST_DIR), ('SIFDECODE', SIFDECODE_DIR), ('MASTSIF', MASTSIF_DIR),
        ):
            if directory is not None:
                os.environ[variable] = str((PROJECT_DIR / directory).resolve())
        os.environ['PYCUTEST_CACHE'] = str(PROJECT_DIR)
        os.environ['LDFLAGS'] = LINKER_FLAGS
        import pycutest

        rosenbrock = _convert_problem(pycutest.import_problem('ROSENBR'))
        result = MatlabSolver(engine, 'newuoa')(
            rosenbrock, options={'fortran': False, 'quiet': True, 'maxfun': 300},
        )
        assert result.fun < 1e-6, result
        assert np.isclose(result.fun, rosenbrock.fun(result.x)), result
        print(f'PyCUTEst ROSENBR: x={result.x}, f={result.fun}, status={result.status}', flush=True)
    finally:
        engine.quit()


if __name__ == '__main__':
    main()
