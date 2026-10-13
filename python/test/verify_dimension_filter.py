"""Verify real small-dimension loading and prevent large CUTEst initialization."""
import os
import sys
from pathlib import Path
from time import perf_counter
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from config import CUTEST_DIR, LINKER_FLAGS, MASTSIF_DIR, PROJECT_DIR, SIFDECODE_DIR
from get_pycutest_problems import get_pycutest_problems
from pycutest_dimensions import read_dimension


def main() -> None:
    for variable, directory in (('CUTEST', CUTEST_DIR), ('SIFDECODE', SIFDECODE_DIR), ('MASTSIF', MASTSIF_DIR)):
        if directory is not None:
            os.environ[variable] = str((PROJECT_DIR / directory).resolve())
    os.environ['PYCUTEST_CACHE'] = str(PROJECT_DIR)
    os.environ['LDFLAGS'] = LINKER_FLAGS
    import pycutest
    from pycutest.build_interface import get_problem_directory

    for name, parameters in [('ROSENBR', None), ('HS1', None), ('ARGLINA', {'N': 10, 'M': 20}), ('CHANNEL', {'NH': 50, 'NC': 1})]:
        source = pycutest.import_problem(name, sifParams=parameters)
        decoded = Path(get_problem_directory(name, sifParams=parameters)) / 'OUTSDIF.d'
        assert read_dimension(decoded) == source.n, name
    print('Decoded dimension controls passed.', flush=True)

    original = pycutest.import_problem
    loaded: list[str] = []

    def load(name: str, sifParams=None):
        assert name not in ('BA-L52', 'BA-L52LS', 'CHANNEL', 'ARGLINA'), (name, sifParams)
        decoded = Path(get_problem_directory(name, sifParams=sifParams)) / 'OUTSDIF.d'
        if decoded.exists():
            assert 1 <= read_dimension(decoded) <= 5, (name, sifParams)
        source = original(name, sifParams=sifParams)
        assert 1 <= source.n <= 5, (name, source.n)
        loaded.append(name)
        return source

    start = perf_counter()
    with patch.object(pycutest, 'import_problem', side_effect=load):
        problems = get_pycutest_problems(1, 5)
    assert problems
    assert len({(p.name, p.n) for p in problems}) == len(problems)
    print(f'Loaded {len(problems)} problems in {perf_counter() - start:.2f}s; {len(loaded)} CUTEst imports.', flush=True)


if __name__ == '__main__':
    main()
