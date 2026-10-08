#!./.venv/bin/python

from __future__ import annotations

import os
from dataclasses import fields

from config import CUTEST_DIR, LINKER_FLAGS, MASTSIF_DIR, PROJECT_DIR, SIFDECODE_DIR
from problem import Problem


def read_pycutest_problems() -> list[Problem]:
    """No inputs. Return custom Problem objects loaded from PyCUTEst."""
    for variable, directory in (
        ("CUTEST", CUTEST_DIR),
        ("SIFDECODE", SIFDECODE_DIR),
        ("MASTSIF", MASTSIF_DIR),
    ):
        if directory is not None:
            os.environ[variable] = str((PROJECT_DIR / directory).resolve())
    os.environ["PYCUTEST_CACHE"] = str(PROJECT_DIR)
    os.environ["LDFLAGS"] = LINKER_FLAGS

    import pycutest

    problems: list[Problem] = []
    for name in pycutest.find_problems():
        source = pycutest.import_problem(name)
        problems.append(
            Problem(**{field.name: getattr(source, field.name) for field in fields(Problem)})
        )
    return problems


def read_problems() -> list[Problem]:
    """Return the problem collection."""
    return read_pycutest_problems()


def test() -> None:
    problems = read_problems()


if __name__ == "__main__":
    test()
