#!./.venv/bin/python

from dataclasses import fields
from pathlib import Path

import matlab.engine

from config import MATCUTEST_DIR
from problem import MatlabFunction, Problem


def read_matcutest_problems() -> list[Problem]:
    engine = matlab.engine.start_matlab()
    try:
        engine.addpath(str(Path(__file__).parent), nargout=0)
        engine.addpath(str(MATCUTEST_DIR), nargout=0)
        engine.addpath(str(MATCUTEST_DIR / "src/matcutest/mtools/src"), nargout=0)
        names = engine.matcutest_select(engine.struct())
        problems: list[Problem] = []
        for name in names:
            metadata = engine.matcutest_bridge(name)
            for field in ("objective", "grad", "hprod", "nonlcon"):
                metadata[field] = (
                    MatlabFunction(engine, name, field) if metadata[field] else None
                )
            for field in fields(Problem):
                if field.type is int:
                    metadata[field.name] = int(metadata[field.name])
                elif field.type is matlab.double and isinstance(
                    metadata[field.name], float
                ):
                    metadata[field.name] = matlab.double([[metadata[field.name]]])
            problems.append(Problem(**metadata))
        return problems
    except Exception:
        engine.quit()
        raise


def read_problems() -> list[Problem]:
    return read_matcutest_problems()


def test() -> None:
    problems = read_problems()


if __name__ == "__main__":
    test()
