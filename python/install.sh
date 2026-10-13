#!/usr/bin/env bash
# Install Python dependencies, CUTEst, SIFDecode, and the complete MASTSIF library.
# Linux prerequisites: Python 3.10 with headers and venv, gcc, gfortran,
# curl, tar, meson, ninja, and patch. Usage: ./install.sh [python-executable]
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"
python_bin="${1:-python3.10}"

if [[ "$(uname -s)" != Linux ]]; then
    echo "This installation script supports Linux." >&2
    exit 1
fi
for command in "$python_bin" gcc gfortran curl tar meson ninja patch; do
    if ! command -v "$command" >/dev/null; then
        echo "Missing prerequisite: $command" >&2
        exit 1
    fi
done
"$python_bin" -c 'import sysconfig; from pathlib import Path; assert (Path(sysconfig.get_path("include")) / "Python.h").is_file(), "Python development headers are missing"'
"$python_bin" -m venv .venv
.venv/bin/python -m pip install --no-cache-dir -r requirements.txt

# Python package names cannot contain parameter value decimal points.
pycutest_package_dir="$(.venv/bin/python -c 'from importlib.util import find_spec; from pathlib import Path; print(Path(find_spec("pycutest").origin).parent)')"
if patch --directory="$pycutest_package_dir" -p1 --forward --dry-run --silent < pycutest_cache_names.patch; then
    patch --directory="$pycutest_package_dir" -p1 < pycutest_cache_names.patch
elif ! patch --directory="$pycutest_package_dir" -p1 --reverse --dry-run --silent < pycutest_cache_names.patch; then
    echo "The PyCUTEst cache-name patch does not match the installed package." >&2
    exit 1
fi

prefix="$project_dir/.venv/cutest"
work_dir="$project_dir/.venv/install"
mkdir -p "$work_dir" "$prefix/share/mastsif-full"

# Fixed revisions used in the full-library test.
cutest_revision=7dafe08040f83a53712a52f675e02a47b153f0a8
sifdecode_revision=979967c923241c136c35f17630cfdcf614e6df17
mastsif_revision=29adac9f1618

fetch_source() {
    local url="$1" name="$2"
    local destination="${3:-$work_dir/$name}"
    local archive="$work_dir/$name.tar.gz"
    if [[ ! -f "$archive" ]]; then
        curl --fail --location --retry 3 "$url" -o "$archive.part"
        mv "$archive.part" "$archive"
    fi
    mkdir -p "$destination"
    tar -xzf "$archive" --strip-components=1 -C "$destination"
    rm -f -- "$archive"
}

build_native() {
    local name="$1"
    shift
    local build_dir="$work_dir/$name/build"
    if [[ -f "$build_dir/meson-private/coredata.dat" ]]; then
        meson setup --reconfigure "$build_dir" "$work_dir/$name" --prefix="$prefix" "$@"
    else
        meson setup "$build_dir" "$work_dir/$name" --prefix="$prefix" "$@"
    fi
    meson compile -C "$build_dir" -j 2
    meson test -C "$build_dir" --print-errorlogs
    meson install -C "$build_dir"
}

fetch_source "https://github.com/ralna/SIFDecode/archive/$sifdecode_revision.tar.gz" sifdecode
# Preserve other definitions when parameter alternatives are interleaved.
patch --directory="$work_dir/sifdecode" -p1 < sifdecode_parameters.patch
build_native sifdecode
fetch_source "https://github.com/ralna/CUTEst/archive/$cutest_revision.tar.gz" cutest
build_native cutest -Dmodules=false
fetch_source "https://bitbucket.org/optrove/sif/get/$mastsif_revision.tar.gz" mastsif "$prefix/share/mastsif-full"

.venv/bin/python - <<'PY'
import os
from config import CUTEST_DIR, LINKER_FLAGS, MASTSIF_DIR, PROJECT_DIR, SIFDECODE_DIR

for variable, directory in (("CUTEST", CUTEST_DIR), ("SIFDECODE", SIFDECODE_DIR), ("MASTSIF", MASTSIF_DIR)):
    if directory is not None:
        os.environ[variable] = str((PROJECT_DIR / directory).resolve())
os.environ["PYCUTEST_CACHE"] = str(PROJECT_DIR)
os.environ["LDFLAGS"] = LINKER_FLAGS
import pycutest

names = pycutest.find_problems()
assert len(names) == 1542, f"Expected 1542 problems, found {len(names)}"
problem = pycutest.import_problem("ROSENBR")
assert problem.grad(problem.x0).shape == (problem.n,)
print(f"Installation verified: {len(names)} problems; ROSENBR objective = {problem.obj(problem.x0)}")
PY

# Remove downloaded sources, duplicate data, and build files after verification.
rm -rf -- "$work_dir"

# Prepare dimensions once so normal problem selection never decodes large cases.
# Missing configurations may take substantial time on the first preparation.
.venv/bin/python prepare_pycutest_dimensions.py
