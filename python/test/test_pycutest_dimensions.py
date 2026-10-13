import unittest
import json
import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import patch

from pycutest_dimensions import DimensionIndex, MissingDimensionError, _reviewed_dimension, read_dimension


def write_decoded(path: Path, algorithm: int) -> None:
    lines = ['         3         1         0         0         0         0         0         0         0         0', f'{algorithm:2d}EXAMPLE']
    counts = [2, 2, 2, 1, 1, 1]
    if algorithm >= 2:
        counts.append(1)
    counts += [0, 0, 0, 0, 0]
    for count in counts:
        lines.append(''.join(f'{0:8d}' for _ in range(count)))
    lines.append('')
    lines.append(f'{0.:18.10E}')
    lower, upper = [0., 2., -1e20], [1., 2., 1e20]
    if algorithm > 2:
        lower.append(-1e20)
        upper.append(1e20)
    for values in (lower, upper):
        lines.append(''.join(f'{value:18.10E}'.replace('E', 'D') for value in values))
    path.write_text('\n'.join(lines) + '\n')


class DimensionTests(unittest.TestCase):
    def test_reviewed_dimensions_require_identical_sif_content(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'EXAMPLE.SIF'
            source.write_text('NAME EXAMPLE\n')
            catalog = {'EXAMPLE': {
                'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'parameter': 'N', 'dimensions': {'100000': 100000},
            }}
            paths = SimpleNamespace(get_mastsif_path=lambda: directory)
            with patch.dict('sys.modules', {'pycutest.system_paths': paths}), patch(
                'pycutest_dimensions._reviewed_dimensions', return_value=catalog
            ), patch('pycutest_dimensions.subprocess.run') as decode:
                index = DimensionIndex(root / 'dimensions.json')
                self.assertEqual(index.get('EXAMPLE', {'N': 100000}, decode=True), 100000)
                decode.assert_not_called()
                source.write_text('NAME EXAMPLE\n* Changed definition\n')
                self.assertIsNone(_reviewed_dimension(source, {'N': 100000}))

    def test_default_configuration_reuses_existing_default_decode(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'EXAMPLE.SIF').write_text(' IE N                   3              $-PARAMETER\n')
            (root / 'default').mkdir()
            write_decoded(root / 'default/OUTSDIF.d', 3)
            paths = SimpleNamespace(get_mastsif_path=lambda: directory, get_sifdecoder_path=lambda: 'sifdecoder')
            build = SimpleNamespace(get_problem_directory=lambda name, sifParams: str(
                root / ('default' if sifParams is None else 'parameterized')
            ))
            with patch.dict('sys.modules', {
                'pycutest.system_paths': paths, 'pycutest.build_interface': build,
            }), patch('pycutest_dimensions.subprocess.run', side_effect=RuntimeError('Decode requested')) as decode:
                index = DimensionIndex(root / 'dimensions.json')
                self.assertEqual(index.get('EXAMPLE', {'N': 3}, decode=True), 2)
                decode.assert_not_called()
                with self.assertRaisesRegex(RuntimeError, 'Decode requested'):
                    index.get('EXAMPLE', {'N': 4}, decode=True)
                decode.assert_called_once()

    def test_completed_dimensions_are_saved_before_decoding(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('FIRST', 'SECOND'):
                (root / f'{name}.SIF').write_text(f'NAME {name}\n')
            (root / 'FIRST').mkdir()
            write_decoded(root / 'FIRST/OUTSDIF.d', 3)
            paths = SimpleNamespace(get_mastsif_path=lambda: directory, get_sifdecoder_path=lambda: 'sifdecoder')
            build = SimpleNamespace(get_problem_directory=lambda name, sifParams: str(root / name))
            with patch.dict('sys.modules', {
                'pycutest.system_paths': paths, 'pycutest.build_interface': build,
            }), patch('pycutest_dimensions.subprocess.run', side_effect=RuntimeError('Decode interrupted')):
                index = DimensionIndex(root / 'dimensions.json')
                self.assertEqual(index.get('FIRST', {}, decode=True), 2)
                with self.assertRaisesRegex(RuntimeError, 'Decode interrupted'):
                    index.get('SECOND', {}, decode=True)
                saved = json.loads(index.path.read_text())
                self.assertEqual(saved['entries'][json.dumps(['FIRST', {}], sort_keys=True)]['n'], 2)
                reloaded = DimensionIndex(index.path)
                self.assertEqual(reloaded.get('FIRST', {}), 2)
                with self.assertRaisesRegex(RuntimeError, 'Decode interrupted'):
                    reloaded.get('SECOND', {})

    def test_missing_metadata_never_decodes_during_selection(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'EXAMPLE.SIF').write_text('NAME EXAMPLE\n')
            paths = SimpleNamespace(get_mastsif_path=lambda: directory, get_sifdecoder_path=lambda: 'sifdecoder')
            with patch.dict('sys.modules', {'pycutest.system_paths': paths}), patch(
                'pycutest_dimensions.subprocess.run'
            ) as decode:
                index = DimensionIndex(root / 'dimensions.json')
                with self.assertRaisesRegex(MissingDimensionError, 'prepare_pycutest_dimensions.py'):
                    index.get('EXAMPLE', {})
                decode.assert_not_called()

    def test_changed_sif_requires_preparation_again(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'EXAMPLE.SIF'
            source.write_text('NAME EXAMPLE\n')
            (root / 'EXAMPLE').mkdir()
            write_decoded(root / 'EXAMPLE/OUTSDIF.d', 3)
            paths = SimpleNamespace(get_mastsif_path=lambda: directory, get_sifdecoder_path=lambda: 'sifdecoder')
            build = SimpleNamespace(get_problem_directory=lambda name, sifParams: str(root / name))
            with patch.dict('sys.modules', {
                'pycutest.system_paths': paths, 'pycutest.build_interface': build,
            }), patch('pycutest_dimensions.subprocess.run') as decode:
                index = DimensionIndex(root / 'dimensions.json')
                self.assertEqual(index.get('EXAMPLE', {}, decode=True), 2)
                with self.assertRaises(MissingDimensionError):
                    index.parameters('EXAMPLE')
                index.record_parameters('EXAMPLE', [{}])
                index.save()
                self.assertEqual(DimensionIndex(index.path).parameters('EXAMPLE'), [{}])
                source.write_text('NAME EXAMPLE\n* Changed definition\n')
                with self.assertRaises(MissingDimensionError):
                    index.get('EXAMPLE', {})
                with self.assertRaises(MissingDimensionError):
                    index.parameters('EXAMPLE')
                decode.assert_not_called()

    def test_free_dimensions_and_constraint_bounds(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'OUTSDIF.d'
            for algorithm in (1, 2, 3):
                write_decoded(path, algorithm)
                self.assertEqual(read_dimension(path), 2)

    def test_truncated_data_is_rejected(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'OUTSDIF.d'
            write_decoded(path, 3)
            path.write_text(path.read_text().splitlines()[0] + '\n 3EXAMPLE\n')
            with self.assertRaises(ValueError):
                read_dimension(path)


if __name__ == '__main__':
    unittest.main()
