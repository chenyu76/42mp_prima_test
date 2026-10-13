import unittest
from contextlib import contextmanager
from collections.abc import Iterator
from types import SimpleNamespace
from tempfile import TemporaryDirectory
from pathlib import Path
import re
from unittest.mock import Mock, patch

from get_pycutest_problems import _parameter_combinations, get_pycutest_problems


@contextmanager
def parameter_output(output: str) -> Iterator[None]:
    with TemporaryDirectory() as directory:
        lines = []
        for line in output.splitlines():
            match = re.match(r'(\S+)=(\S+) \((IE|RE)\)(.*)', line)
            if match:
                name, value, kind, annotation = match.groups()
                marker = ' ' if '-default value-' in annotation else '*'
                lines.append(f'{marker}{kind} {name:<10}          {value:<15}$-PARAMETER {annotation}')
        Path(directory, 'EXAMPLE.SIF').write_text('\n'.join(lines))
        paths = SimpleNamespace(get_mastsif_path=lambda: directory)
        with patch.dict('sys.modules', {'pycutest.system_paths': paths}):
            yield



class SelectionTests(unittest.TestCase):
    def test_parameter_marker_in_wrong_column_is_not_settable(self) -> None:
        with TemporaryDirectory() as directory:
            lines = [
                '*IE N                   3              $-PARAMETER',
                ' IE N                   1000           $-PARAMETER',
                '*IE N1                  2               $-PARAMETER  .lt. N',
                ' IE N1                  500             $-PARAMETER  .lt. N',
            ]
            Path(directory, 'EXAMPLE.SIF').write_text('\n'.join(lines))
            paths = SimpleNamespace(get_mastsif_path=lambda: directory)
            with patch.dict('sys.modules', {'pycutest.system_paths': paths}):
                self.assertEqual(list(_parameter_combinations('EXAMPLE')), [{'N': 3}, {'N': 1000}])

    def test_precision_and_fortran_exponents(self) -> None:
        with parameter_output('R=0.9305681558 (RE)\nR=1.234567D-2 (RE)'):
            self.assertEqual(list(_parameter_combinations('EXAMPLE')), [
                {'R': 0.9305681558}, {'R': 0.01234567},
            ])

    def test_independent_parameters_and_duplicates(self) -> None:
        output = '\n'.join([
            'N=2 (IE) uncommented',
            'N=3 (IE) -default value- uncommented',
            'N=2 (IE) comment: original value',
            'M=4 (IE) uncommented',
            'M=5 (IE) -default value- uncommented',
            'SCALE=0.5 (RE) -default value- uncommented',
            'RHO1=0.5 (RE) comment: for M = 4',
            'RHO1=0.9305681558 (RE) -default value- comment: for M = 5',
        ])
        with parameter_output(output):
            self.assertEqual(list(_parameter_combinations('EXAMPLE')), [
                {'N': 2, 'M': 4}, {'N': 2, 'M': 5},
                {'N': 3, 'M': 4}, {'N': 3, 'M': 5},
            ])

    def test_single_value_without_default(self) -> None:
        with parameter_output('N=1000000 (IE) uncommented'):
            self.assertEqual(list(_parameter_combinations('EXAMPLE')), [{'N': 1000000}])

    def test_fixed_defaults(self) -> None:
        with parameter_output('N=2 (IE) -default value- uncommented'):
            self.assertEqual(list(_parameter_combinations('EXAMPLE')), [{}])

    def test_actual_dimensions_and_inclusive_endpoints(self) -> None:
        def parameters(name: str) -> Iterator[dict[str, int]]:
            return iter([{}] if name == 'FIXED' else [{'K': k} for k in (1, 2, 3, 4)])

        def load(name: str, sifParams: dict[str, int] | None = None) -> SimpleNamespace:
            n = 3 if name == 'FIXED' else 2 * sifParams['K']
            return SimpleNamespace(name=name, n=n)

        provider = SimpleNamespace(
            find_problems=lambda: ['FIXED', 'VARIABLE'], import_problem=Mock(side_effect=load),
        )
        with patch.dict('sys.modules', pycutest=provider), patch.dict('os.environ'), patch(
            'get_pycutest_problems._parameter_combinations', side_effect=parameters
        ), patch('get_pycutest_problems.DimensionIndex') as index_type, patch(
            'get_pycutest_problems._convert_problem', side_effect=lambda source: SimpleNamespace(name=source.name, n=source.n)
        ):
            index_type.return_value.get.side_effect = lambda name, params: 3 if name == 'FIXED' else 2 * params['K']
            index_type.return_value.parameters.side_effect = parameters
            problems = get_pycutest_problems(4, 6)
        self.assertEqual([(problem.name, problem.n) for problem in problems], [('VARIABLE_n4', 4), ('VARIABLE_n6', 6)])
        self.assertEqual([call.kwargs['sifParams'] for call in provider.import_problem.call_args_list], [{'K': 2}, {'K': 3}])

    def test_one_instance_per_dimension(self) -> None:
        provider = SimpleNamespace(
            find_problems=lambda: ['EXAMPLE'],
            import_problem=Mock(side_effect=lambda name, sifParams: SimpleNamespace(name=name, n=2)),
        )
        with patch.dict('sys.modules', pycutest=provider), patch.dict('os.environ'), patch(
            'get_pycutest_problems._parameter_combinations', return_value=iter([{'M': 1}, {'M': 2}])
        ), patch('get_pycutest_problems.DimensionIndex') as index_type, patch(
            'get_pycutest_problems._convert_problem', side_effect=lambda source: SimpleNamespace(name=source.name, n=source.n)
        ):
            index_type.return_value.get.return_value = 2
            index_type.return_value.parameters.return_value = [{'M': 1}, {'M': 2}]
            self.assertEqual(len(get_pycutest_problems(2, 2)), 1)
        self.assertEqual(provider.import_problem.call_count, 1)

    def test_unavailable_parameter_combination(self) -> None:
        def load(name: str, sifParams: dict[str, int]) -> SimpleNamespace:
            if sifParams['N'] == 1:
                raise RuntimeError('Invalid parameter combination')
            return SimpleNamespace(name=name, n=2)
        provider = SimpleNamespace(find_problems=lambda: ['EXAMPLE'], import_problem=load)
        with patch.dict('sys.modules', pycutest=provider), patch.dict('os.environ'), patch(
            'get_pycutest_problems._parameter_combinations', return_value=iter([{'N': 1}, {'N': 2}])
        ), patch('get_pycutest_problems.DimensionIndex') as index_type, patch(
            'get_pycutest_problems._convert_problem', side_effect=lambda source: SimpleNamespace(name=source.name, n=source.n)
        ), self.assertWarns(UserWarning):
            index_type.return_value.get.side_effect = lambda name, params: params['N']
            index_type.return_value.parameters.return_value = [{'N': 1}, {'N': 2}]
            self.assertEqual(len(get_pycutest_problems(1, 2)), 1)

    def test_invalid_interval(self) -> None:
        for bounds in ((3, 2), (-1, 20)):
            with self.assertRaises(ValueError):
                get_pycutest_problems(*bounds)


if __name__ == '__main__':
    unittest.main()
