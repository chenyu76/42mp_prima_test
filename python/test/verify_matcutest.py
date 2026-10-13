"""Select and evaluate all small problems in the local MatCUTEst runtime."""

import sys
from pathlib import Path
from time import perf_counter

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from config import MATCUTEST_DIR, MAX_DIMENSION, MIN_DIMENSION, PROJECT_DIR
from matlab_solver import start_matlab


def main() -> None:
    """No inputs. Verify selection, loading, evaluation and handle reuse."""
    print("Starting MATLAB.", flush=True)
    engine = start_matlab()
    try:
        engine.addpath(str(PROJECT_DIR / MATCUTEST_DIR / "mtools/src"), nargout=0)
        engine.addpath(str(PROJECT_DIR / "test"), nargout=0)
        started = perf_counter()
        count = engine.verify_matcutest_runtime(
            float(MIN_DIMENSION), float(MAX_DIMENSION), nargout=1,
        )
        print(f"Verified {int(count)} problems in {perf_counter() - started:.2f} s.", flush=True)
    finally:
        engine.quit()


if __name__ == "__main__":
    main()
