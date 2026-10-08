import unittest
from types import SimpleNamespace
from unittest.mock import patch

from get_pycutest_problems import _parameter_combinations, get_pycutest_problems


class SelectionTests(unittest.TestCase):
    def test_scientific_notation_for_integer_parameters(self) -> None:
        provider = SimpleNamespace(
            print_available_sif_params=lambda name: print('N = 1e+06 (int)'),
        )
        with patch.dict('sys.modules', pycutest=provider):
            self.assertEqual(list(_parameter_combinations('EXAMPLE')), [{'N': 1000000}])

    def test_listed_parameter_product_and_duplicates(self) -> None:
        def show(name: str) -> None:
            print('N = 2 (int)')
            print('N = 3 (int) [default]')
            print('N = 2 (int) duplicated description')
            print('M = 4 (int)')
            print('M = 5 (int)')
            print('SCALE = 0.5 (float)')
        provider = SimpleNamespace(print_available_sif_params=show)
        with patch.dict('sys.modules', pycutest=provider):
            choices = list(_parameter_combinations('EXAMPLE'))
        self.assertEqual(choices, [
            {'N': 2, 'M': 4, 'SCALE': 0.5},
            {'N': 2, 'M': 5, 'SCALE': 0.5},
            {'N': 3, 'M': 4, 'SCALE': 0.5},
            {'N': 3, 'M': 5, 'SCALE': 0.5},
        ])

    def test_actual_dimensions_and_inclusive_endpoints(self) -> None:
        def show(name: str) -> None:
            if name == 'VARIABLE':
                for value in (1, 2, 3, 4):
                    print(f'K = {value} (int)')

        def load(name: str, sifParams=None):
            n = 3 if name == 'FIXED' else 2 * sifParams['K']
            return SimpleNamespace(name=name, n=n)

        provider = SimpleNamespace(
            print_available_sif_params=show,
            find_problems=lambda: ['FIXED', 'VARIABLE'], import_problem=load,
        )
        with patch.dict('sys.modules', pycutest=provider), patch.dict('os.environ'), patch(
            'get_pycutest_problems._convert_problem', side_effect=lambda source: SimpleNamespace(name=source.name, n=source.n)
        ):
            problems = get_pycutest_problems(4, 6)
        self.assertEqual([(problem.name, problem.n) for problem in problems], [('VARIABLE_n4', 4), ('VARIABLE_n6', 6)])

    def test_one_instance_per_dimension(self) -> None:
        provider = SimpleNamespace(
            print_available_sif_params=lambda name: print('M = 1 (int)\nM = 2 (int)'),
            find_problems=lambda: ['EXAMPLE'],
            import_problem=lambda name, sifParams: SimpleNamespace(name=name, n=2),
        )
        with patch.dict('sys.modules', pycutest=provider), patch.dict('os.environ'), patch(
            'get_pycutest_problems._convert_problem', side_effect=lambda source: SimpleNamespace(name=source.name, n=source.n)
        ):
            self.assertEqual(len(get_pycutest_problems(2, 2)), 1)

    def test_unavailable_parameter_combination(self) -> None:
        def load(name: str, sifParams):
            if sifParams['N'] == 1:
                raise RuntimeError('Invalid parameter combination')
            return SimpleNamespace(name=name, n=2)
        provider = SimpleNamespace(
            print_available_sif_params=lambda name: print('N = 1 (int)\nN = 2 (int)'),
            find_problems=lambda: ['EXAMPLE'], import_problem=load,
        )
        with patch.dict('sys.modules', pycutest=provider), patch.dict('os.environ'), patch(
            'get_pycutest_problems._convert_problem', side_effect=lambda source: SimpleNamespace(name=source.name, n=source.n)
        ), self.assertWarns(UserWarning):
            self.assertEqual(len(get_pycutest_problems(1, 2)), 1)

    def test_invalid_interval(self) -> None:
        for bounds in ((3, 2), (-1, 20)):
            with self.assertRaises(ValueError):
                get_pycutest_problems(*bounds)


if __name__ == '__main__':
    unittest.main()
