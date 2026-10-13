"""Print native SIFDecode diagnostics for a named parameter configuration."""

import os
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from config import CUTEST_DIR, MASTSIF_DIR, PROJECT_DIR, SIFDECODE_DIR


def main() -> None:
    for variable, directory in (
        ('CUTEST', CUTEST_DIR), ('MASTSIF', MASTSIF_DIR), ('SIFDECODE', SIFDECODE_DIR),
    ):
        if directory is not None:
            os.environ[variable] = str((PROJECT_DIR / directory).resolve())
    os.environ['PYCUTEST_CACHE'] = str(PROJECT_DIR)
    from pycutest.system_paths import get_mastsif_path, get_sifdecoder_path

    command = [os.environ.get('SIFDECODER_EXECUTABLE', get_sifdecoder_path()), '-s', '3']
    if len(sys.argv) > 2:
        command += ['-param', sys.argv[2]]
    command += sys.argv[3:]
    command.append(str(Path(get_mastsif_path()) / (sys.argv[1] + '.SIF')))
    with TemporaryDirectory(prefix='42mp-diagnostic-') as directory:
        result = subprocess.run(command, cwd=directory, capture_output=True, text=True)
    print(result.stdout, result.stderr, f'Exit status: {result.returncode}')


if __name__ == '__main__':
    main()
