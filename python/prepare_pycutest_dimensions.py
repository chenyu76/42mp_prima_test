"""Prepare complete SIF dimension information without initializing CUTEst."""

import os
import warnings

from tqdm import tqdm

from config import CUTEST_DIR, MASTSIF_DIR, PROJECT_DIR, SIFDECODE_DIR
from get_pycutest_problems import _parameter_combinations
from pycutest_dimensions import DimensionIndex


def main() -> None:
    """Prepare all listed configurations for the installed SIF library."""
    for variable, directory in (
        ('CUTEST', CUTEST_DIR), ('MASTSIF', MASTSIF_DIR), ('SIFDECODE', SIFDECODE_DIR),
    ):
        if directory is not None:
            os.environ[variable] = str((PROJECT_DIR / directory).resolve())
    os.environ['PYCUTEST_CACHE'] = str(PROJECT_DIR)

    import pycutest

    names = pycutest.find_problems()
    index = DimensionIndex(PROJECT_DIR / '.venv/pycutest_dimensions.json')
    with tqdm(total=len(names), desc='Preparing dimensions', unit='problem') as progress:
        try:
            for name in names:
                configurations = list(_parameter_combinations(name))
                available: list[dict[str, int | float]] = []
                for parameters in configurations:
                    progress.set_postfix_str(f'{name} {parameters}' if parameters else name)
                    try:
                        index.get(name, parameters, decode=True)
                    except RuntimeError as error:
                        warnings.warn(f'Unavailable problem {name}, parameters {parameters}: {error}')
                    else:
                        available.append(parameters)
                index.record_parameters(name, available)
                progress.update(1)
                if progress.n % 25 == 0:
                    index.save()
        finally:
            index.save()


if __name__ == '__main__':
    main()
