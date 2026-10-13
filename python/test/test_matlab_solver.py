import unittest
from unittest.mock import Mock

import matlab
import numpy as np

from matlab_solver import MatlabSolver
from problem import Problem


class AdapterTests(unittest.TestCase):
    def test_wrap_preserves_vectors_matrices_and_empty_shapes(self) -> None:
        problem = Problem(
            name='EXAMPLE', n=3, x0=np.array([1., 2., 3.]),
            xl=np.full(3, -np.inf), xu=np.full(3, np.inf),
            aub=np.array([[1., 2., 3.], [4., 5., 6.]]), bub=np.array([7., 8.]),
            aeq=np.empty((0, 3)), beq=np.empty(0),
            fun=lambda x: float(x @ x), cub=lambda x: np.empty(0), ceq=lambda x: np.empty(0),
        )
        fields = MatlabSolver(Mock(), 'lincoa').wrap_problem(problem)
        self.assertEqual(fields['x0'].size, (3, 1))
        self.assertEqual(fields['aeq'].size, (0, 3))
        self.assertEqual(fields['beq'].size, (0, 1))
        np.testing.assert_array_equal(np.asarray(fields['aub']), problem.aub)
        np.testing.assert_array_equal(np.asarray(fields['xl']).reshape(-1), problem.xl)
        np.testing.assert_array_equal(problem.x0, [1., 2., 3.])

    def test_unwrap_solution_and_nested_output(self) -> None:
        result = MatlabSolver(Mock(), 'newuoa').unwrap_result(
            matlab.double([[1.], [2.]]), 3., 0.,
            {'xhist': matlab.double([[1., 3.], [2., 4.]]),
             'nested': {'fhist': matlab.double([[5., 3.]])}, 'message': 'Done'},
        )
        np.testing.assert_array_equal(result.x, [1., 2.])
        self.assertEqual(result.fun, 3.)
        self.assertEqual(result.status, 0)
        np.testing.assert_array_equal(result.output['xhist'], [[1., 3.], [2., 4.]])
        self.assertEqual(result.output['nested']['fhist'].shape, (1, 2))
        self.assertEqual(result.output['message'], 'Done')


if __name__ == '__main__':
    unittest.main()
