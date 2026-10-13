"""Verify parameter preprocessing and float-parameter imports using real CUTEst."""

import os
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from config import CUTEST_DIR, LINKER_FLAGS, MASTSIF_DIR, PROJECT_DIR, SIFDECODE_DIR
from pycutest_dimensions import read_dimension


def main() -> None:
    for variable, directory in (
        ('CUTEST', CUTEST_DIR), ('MASTSIF', MASTSIF_DIR), ('SIFDECODE', SIFDECODE_DIR),
    ):
        if directory is not None:
            os.environ[variable] = str((PROJECT_DIR / directory).resolve())
    os.environ['PYCUTEST_CACHE'] = str(PROJECT_DIR)
    os.environ['LDFLAGS'] = LINKER_FLAGS
    import pycutest
    from pycutest.build_interface import get_problem_directory, params_to_string

    for name, parameters, expected in (
        ('DTOC1ND', {'N': 10, 'NX': 2, 'NY': 4}, 54),
        ('LEVYMONT', {'N': 2, 'L': 0.25, 'C': 0.75}, 2),
        ('ARGLINA', {'N': 10, 'M': 20}, 10),
        ('CHARDIS0', {'NP1': 5}, 10),
        ('CHARDIS02', {'NP1': 5}, 10),
        ('CHARDIS1', {'NP1': 5}, 8),
        ('CHARDIS12', {'NP1': 5}, 8),
        ('PDE1', {'N': 3}, 26),
        ('PDE2', {'N': 3}, 40),
        ('ROSEPETAL', {'N': 2, 'R': 1.0}, 2),
    ):
        assert '.' not in params_to_string(parameters)
        source = pycutest.import_problem(name, sifParams=parameters)
        decoded = Path(get_problem_directory(name, sifParams=parameters)) / 'OUTSDIF.d'
        assert source.n == read_dimension(decoded) == expected, (name, source.n)
        assert np.isfinite(source.obj(source.x0)), name
        print(f'{name}: dimension {source.n}, objective and parameter import passed.', flush=True)


if __name__ == '__main__':
    main()
