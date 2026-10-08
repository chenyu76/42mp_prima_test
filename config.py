from pathlib import Path


PROJECT_DIR: Path = Path(__file__).resolve().parent

# Set installation paths relative to PROJECT_DIR, or leave None to use
# existing environment variables and PyCUTEst's default locations.
CUTEST_DIR: Path | None = Path(".venv/cutest")
SIFDECODE_DIR: Path | None = Path(".venv/cutest")
MASTSIF_DIR: Path | None = Path(".venv/cutest/share/mastsif-full")

# Keep the math library linked for GCC's vectorized Fortran functions.
LINKER_FLAGS: str = "-Wl,--no-as-needed -lm -lmvec"
