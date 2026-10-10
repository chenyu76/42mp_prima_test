from pathlib import Path


PROJECT_DIR: Path = Path(__file__).resolve().parent

# Set installation paths relative to PROJECT_DIR, or leave None to use
# existing environment variables and PyCUTEst's default locations.
CUTEST_DIR: Path | None = Path(".venv/cutest")
SIFDECODE_DIR: Path | None = Path(".venv/cutest")
MASTSIF_DIR: Path | None = Path(".venv/cutest/share/mastsif-full")

# Keep the math library linked for GCC's vectorized Fortran functions.
LINKER_FLAGS: str = "-Wl,--no-as-needed -lm -lmvec"

MIN_DIMENSION: int = 1
MAX_DIMENSION: int = 5

TOUGH_RUNS: int = 10
TOUGH_SEED: int = 0
TOUGH_NOISE_LEVEL: float = 0.2
TOUGH_WITH_FAILURE: bool = True
TOUGH_INVALID_LINEAR: bool = True
TOUGH_FIXED_VARIABLES: bool = True
