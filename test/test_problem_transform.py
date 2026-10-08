import unittest
from types import SimpleNamespace

import numpy as np
from numpy.testing import assert_array_equal, assert_allclose

from problem import Problem
from read_pycutest_problems import _convert_problem
from transform_problems import make_tough_problem, transform_problems


def make_base(n: int = 2) -> Problem:
    return Problem(
        name="EXAMPLE", n=n, x0=np.ones(n), xl=np.zeros(n), xu=np.ones(n),
        aub=np.ones((2, n)), bub=np.ones(2),
        aeq=np.ones((1, n)), beq=np.ones(1),
        fun=lambda x: float(x @ x), cub=lambda x: np.array([x.sum(), -x.sum()]),
        ceq=lambda x: np.array([x[0] - 1]),
    )


class ConversionTests(unittest.TestCase):
    def test_affine_offsets_and_two_sided_constraints(self) -> None:
        rows = np.array([[2., 0.], [0., -1.], [1., -1.], [1., 1.]])
        offsets = np.array([3., 2., 4., 3.])

        def scons(x, index, gradient):
            self.assertLess(index, 4)
            row = rows[index:index + 1]
            return float(rows[index] @ x + offsets[index]), SimpleNamespace(toarray=lambda: row)

        def cons(x):
            return np.concatenate((rows @ x + offsets, [x[0]**2 + x[1], x[0]*x[1], x[1]**2]))

        source = SimpleNamespace(
            name="MIXED", n=2, m=7, x0=np.array([1., 2.]),
            bl=np.array([-1e20, 0.]), bu=np.array([1e20, 10.]),
            cl=np.array([-1e20, 1., 5., -1., -1., 2., 4.]),
            cu=np.array([7., 1e20, 5., 6., 9., 2., 1e20]),
            is_linear_cons=np.array([True]*4 + [False]*3),
            is_eq_cons=np.array([False, False, True, False, False, True, False]),
            obj=lambda x: float(x @ x), scons=scons, cons=cons,
        )
        problem = _convert_problem(source)
        assert_array_equal(problem.aub, [[2, 0], [0, 1], [1, 1], [-1, -1]])
        assert_array_equal(problem.bub, [4, 1, 3, 4])
        assert_array_equal(problem.aeq, [[1, -1]])
        assert_array_equal(problem.beq, [1])
        assert_array_equal(problem.cub(problem.x0), [-6, -4, 0])
        assert_array_equal(problem.ceq(problem.x0), [0])
        self.assertEqual(problem.fun(problem.x0), 5.)
        self.assertTrue(np.isneginf(problem.xl[0]))
        self.assertTrue(np.isposinf(problem.xu[0]))

    def test_empty_constraints(self) -> None:
        source = SimpleNamespace(
            name="FREE", n=2, m=0, x0=np.zeros(2),
            bl=np.full(2, -1e20), bu=np.full(2, 1e20), obj=lambda x: 0.,
        )
        problem = _convert_problem(source)
        self.assertEqual(problem.aub.shape, (0, 2))
        self.assertEqual(problem.aeq.shape, (0, 2))
        self.assertEqual(problem.cub(problem.x0).shape, (0,))
        self.assertEqual(problem.ceq(problem.x0).shape, (0,))


class ToughTests(unittest.TestCase):
    def test_reproducibility_and_preservation(self) -> None:
        base = make_base()
        original = {name: getattr(base, name).copy() for name in ('x0', 'xl', 'xu', 'aub', 'bub', 'aeq', 'beq')}
        global_state = np.random.get_state()
        first, second = make_tough_problem(base, 42), make_tough_problem(base, 42)
        for name, expected in original.items():
            assert_array_equal(getattr(base, name), expected)
            assert_array_equal(getattr(first, name), getattr(second, name))
        state_after = np.random.get_state()
        self.assertEqual(global_state[0], state_after[0])
        assert_array_equal(global_state[1], state_after[1])
        self.assertEqual(global_state[2:], state_after[2:])

    def test_evaluations_do_not_depend_on_call_order(self) -> None:
        base = make_base()
        x = np.array([0.2, 0.3])
        for seed in range(100):
            problem = make_tough_problem(base, seed)
            def outcome(point):
                try:
                    return ('value', np.array([problem.fun(point)]))
                except RuntimeError as error:
                    return ('error', str(error))
            first = outcome(x)
            outcome(x + 1)
            second = outcome(x)
            self.assertEqual(first[0], second[0])
            if first[0] == 'value':
                assert_array_equal(first[1], second[1])
            else:
                self.assertEqual(first[1], second[1])
            assert_array_equal(problem.cub(x), problem.cub(x))
            assert_array_equal(problem.ceq(x), problem.ceq(x))

    def test_invalid_linear_data_and_fixed_variables(self) -> None:
        base = make_base(100)
        base.aub = np.ones((100, 100))
        base.bub = np.ones(100)
        transformed = make_tough_problem(base, 12)
        self.assertTrue(np.any(transformed.xl == transformed.xu))
        for check in (np.isnan, np.isposinf, np.isneginf):
            self.assertTrue(np.any(check(transformed.aub)))
        self.assertTrue(np.all(np.isfinite(base.aub)))

    def test_noise_and_injected_outcomes(self) -> None:
        base = make_base()
        x = np.array([0.2, 0.3])
        outcomes = set()
        for seed in range(500):
            problem = make_tough_problem(base, seed)
            try:
                value = problem.fun(x)
            except RuntimeError:
                outcomes.add('exception')
                continue
            if np.isnan(value):
                outcomes.add('nan')
            elif np.isposinf(value):
                outcomes.add('inf')
            elif value == -1e30:
                outcomes.add('large-negative')
            else:
                outcomes.add('finite')
                self.assertNotEqual(value, base.fun(x))
        self.assertEqual(outcomes, {'exception', 'nan', 'inf', 'large-negative', 'finite'})

    def test_ten_variants_per_problem(self) -> None:
        base = make_base()
        variants = transform_problems([base])
        self.assertEqual(len(variants), 10)
        self.assertEqual(len({problem.name for problem in variants}), 10)
        self.assertEqual(transform_problems([]), [])
        for left, right in zip(variants, transform_problems([base])):
            assert_allclose(left.x0, right.x0, rtol=0, atol=0)


if __name__ == '__main__':
    unittest.main()
