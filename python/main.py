#!./.venv/bin/python

from problem import Problem
from config import MAX_DIMENSION, MIN_DIMENSION
from get_pycutest_problems import get_pycutest_problems
from transform_problems import transform_problems


def get_problems() -> list[Problem]:
    """No inputs. Return the original problem collection."""
    return get_pycutest_problems(MIN_DIMENSION, MAX_DIMENSION)


def test() -> None:
    problems = get_problems()
    for p in problems:
        print(p.name)
    transformed_problems = transform_problems(problems)


if __name__ == "__main__":
    test()
