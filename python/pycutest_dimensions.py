"""Read free-variable dimensions without compiling or initializing CUTEst."""

import json
import hashlib
import subprocess
from functools import lru_cache
from itertools import islice
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import TextIO, cast

import numpy as np


class MissingDimensionError(FileNotFoundError):
    """The installed SIF configuration has no prepared dimension entry."""


class DimensionIndex:
    def __init__(self, path: Path) -> None:
        self.path = path
        data = json.loads(path.read_text()) if path.exists() else {}
        self.entries: dict[str, dict[str, object]] = data.get('entries', data)
        self.configurations: dict[str, dict[str, object]] = data.get('configurations', {})
        self._dirty = False

    def parameters(self, name: str) -> list[dict[str, int | float]]:
        """Return available parameters after complete preparation of this SIF file."""
        _, signature = _source(name)
        entry = self.configurations.get(name)
        if entry is None or entry['source'] != signature:
            raise MissingDimensionError(
                f'Parameter information is missing or stale for {name}. '
                'Run ./.venv/bin/python prepare_pycutest_dimensions.py before running main.py.'
            )
        return cast(list[dict[str, int | float]], entry['parameters'])

    def record_parameters(self, name: str, parameters: list[dict[str, int | float]]) -> None:
        """Record available parameters after checking every listed configuration."""
        _, signature = _source(name)
        entry = {'source': signature, 'parameters': parameters}
        if self.configurations.get(name) != entry:
            self.configurations[name] = entry
            self._dirty = True

    def get(self, name: str, parameters: dict[str, int | float], *, decode: bool = False) -> int:
        """Return the free dimension; only preparation may set decode=True."""
        sif, signature = _source(name)
        key = json.dumps([name, parameters], sort_keys=True)
        entry = self.entries.get(key)
        if entry is not None and entry['source'] == signature:
            if 'n' in entry:
                return int(entry['n'])
            if not decode:
                raise RuntimeError(str(entry['error']))
        if not decode:
            raise MissingDimensionError(
                f'Dimension information is missing or stale for {name}, parameters {parameters}. '
                'Run ./.venv/bin/python prepare_pycutest_dimensions.py before running main.py.'
            )

        reviewed = _reviewed_dimension(sif, parameters)
        if reviewed is not None:
            self.entries[key] = {'source': signature, 'n': reviewed}
            self._dirty = True
            return reviewed

        from pycutest.build_interface import get_problem_directory
        from pycutest.system_paths import get_sifdecoder_path

        decoded = Path(get_problem_directory(name, sifParams=parameters or None)) / 'OUTSDIF.d'
        if not decoded.exists() and parameters and _matches_defaults(sif, parameters):
            decoded = Path(get_problem_directory(name, sifParams=None)) / 'OUTSDIF.d'
        if decoded.exists():
            n = read_dimension(decoded)
        else:
            # Keep completed work if a later native decode is interrupted.
            self.save()
            command = [get_sifdecoder_path(), '-s', '3']
            if parameters:
                command += ['-param', ','.join(f'{key}={value}' for key, value in parameters.items())]
            command.append(str(sif))
            with TemporaryDirectory(prefix='42mp-dimension-') as directory:
                try:
                    output = subprocess.run(command, cwd=directory, capture_output=True, text=True, check=True)
                    if 'WARNING' in output.stdout + output.stderr:
                        raise RuntimeError(output.stdout + output.stderr)
                    n = read_dimension(Path(directory) / 'OUTSDIF.d')
                except (subprocess.CalledProcessError, RuntimeError, OSError, ValueError) as error:
                    detail = str(error)
                    if isinstance(error, subprocess.CalledProcessError):
                        detail = '\n'.join((error.stdout or '', error.stderr or '')).strip() or detail
                    self.entries[key] = {'source': signature, 'error': detail}
                    self._dirty = True
                    self.save()
                    raise RuntimeError(detail) from error
        self.entries[key] = {'source': signature, 'n': n}
        self._dirty = True
        return n

    def save(self) -> None:
        if not self._dirty and self.path.exists():
            return
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix('.tmp')
        temporary.write_text(json.dumps({
            'entries': self.entries, 'configurations': self.configurations,
        }, indent=2) + '\n')
        temporary.replace(self.path)
        self._dirty = False


def _source(name: str) -> tuple[Path, list[str | int]]:
    from pycutest.system_paths import get_mastsif_path

    sif = Path(get_mastsif_path()) / (name + '.SIF')
    stat = sif.stat()
    return sif, [str(sif.resolve()), stat.st_mtime_ns, stat.st_size]


@lru_cache(maxsize=1)
def _reviewed_dimensions() -> dict[str, dict[str, object]]:
    return json.loads(Path(__file__).with_name('sif_dimensions.json').read_text())


def _reviewed_dimension(sif: Path, parameters: dict[str, int | float]) -> int | None:
    entry = _reviewed_dimensions().get(sif.stem)
    if entry is None or hashlib.sha256(sif.read_bytes()).hexdigest() != entry['sha256']:
        return None
    dimensions = cast(dict[str, int], entry['dimensions'])
    return dimensions.get(str(parameters.get(str(entry['parameter']))))


def _matches_defaults(sif: Path, parameters: dict[str, int | float]) -> bool:
    defaults: dict[str, int | float] = {}
    with sif.open() as stream:
        for line in stream:
            if line[39:50] == '$-PARAMETER' and line[:1] != '*' and line[1:3] in ('IE', 'RE'):
                value = float(line[24:36].replace('D', 'E').replace('d', 'e'))
                defaults[line[4:14].strip()] = int(value) if line[1:3] == 'IE' else value
    return all(key in defaults and defaults[key] == value for key, value in parameters.items())


def _skip_records(stream: TextIO, count: int, width: int) -> None:
    for _ in range(max(1, (count + width - 1) // width)):
        if not stream.readline():
            raise ValueError('Truncated OUTSDIF data.')


def _read_reals(stream: TextIO, count: int) -> np.ndarray:
    records = max(1, (count + 3) // 4)
    text = ''.join(islice(stream, records)).replace('D', 'E')
    values = np.fromstring(text, sep=' ')
    if len(values) != count:
        raise ValueError('Invalid OUTSDIF real array length.')
    return values


def read_dimension(path: Path) -> int:
    """Read bounds using CUTEst's OUTSDIF layout and PyCUTEst's fixed-variable rule."""
    with path.open() as stream:
        n, ng, nel, ntotel, nvrels, nnza, *_ = map(int, stream.readline().split())
        algorithm = int(stream.readline()[:2])
        counts = [ng + 1] * 3 + [nel + 1] * 2 + [ng]
        if algorithm >= 2:
            counts.append(ng)
        counts += [nel, nel, ntotel, nvrels, nnza]
        for count in counts:
            _skip_records(stream, count, 10)
        _skip_records(stream, nnza, 4)
        _skip_records(stream, ng, 4)
        bound_count = n + ng if algorithm > 2 else n
        lower = _read_reals(stream, bound_count)[:n]
        upper = _read_reals(stream, bound_count)[:n]
    return int(np.count_nonzero(~(upper - lower <= 1e-15)))
