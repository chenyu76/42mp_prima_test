#!./.venv/bin/python

from problem import Problem
from read_pycutest_problems import read_pycutest_problems
from transform_problems import transform_problems


def read_problems() -> list[Problem]:
    """No inputs. Return the original problem collection."""
    return read_pycutest_problems()


def test() -> None:
    problems = read_problems()
    transformed_problems = transform_problems(problems)


if __name__ == "__main__":
    test()
