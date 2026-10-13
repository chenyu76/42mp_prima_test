"""Check parameter parsing against the installed SIFDecode executable."""

import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from config import CUTEST_DIR, MASTSIF_DIR, PROJECT_DIR, SIFDECODE_DIR
from get_pycutest_problems import _parameter_combinations
from pycutest_dimensions import DimensionIndex

for variable, directory in (
    ('CUTEST', CUTEST_DIR), ('MASTSIF', MASTSIF_DIR), ('SIFDECODE', SIFDECODE_DIR),
):
    os.environ[variable] = str((PROJECT_DIR / directory).resolve())
os.environ['PYCUTEST_CACHE'] = str(PROJECT_DIR)

from pycutest.system_paths import get_mastsif_path, get_sifdecoder_path

index = DimensionIndex(PROJECT_DIR / '.venv/pycutest_dimensions.json')
parameters = list(_parameter_combinations('ALJAZZAF'))
assert parameters == [{'N': n} for n in (3, 100, 1000, 10000)], parameters
for combination in parameters:
    print('ALJAZZAF', combination, 'free dimension:', index.get('ALJAZZAF', combination, decode=True), flush=True)
index.save()

checked = 0
for sif in sorted(Path(get_mastsif_path()).glob('*.SIF')):
    output = subprocess.run(
        [get_sifdecoder_path(), '-show', str(sif)],
        capture_output=True, text=True, check=True,
    ).stdout
    recognized = {
        line.split('=', 1)[0].strip()
        for line in output.splitlines()
        if '(IE)' in line or '(RE)' in line
    }
    for combination in _parameter_combinations(sif.stem):
        assert combination.keys() <= recognized, (sif.stem, combination, recognized)
    checked += 1
print(f'Parameter names checked against SIFDecode for {checked} problems.')
