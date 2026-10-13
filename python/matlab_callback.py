"""Evaluate the original Python problem when requested by MATLAB."""

import json
import socket
from collections.abc import Iterator
from contextlib import contextmanager
from socketserver import StreamRequestHandler, UnixStreamServer
from tempfile import TemporaryDirectory
from threading import Thread

import numpy as np

from problem import FloatArray, Problem


@contextmanager
def problem_bridge(problem: Problem) -> Iterator[str]:
    """Serve fun/cub/ceq from this process for the duration of one solve."""
    class Handler(StreamRequestHandler):
        def handle(self) -> None:
            try:
                request = json.loads(self.rfile.readline())
                function = {"fun": problem.fun, "cub": problem.cub, "ceq": problem.ceq}[request["function"]]
                x = np.asarray(request["x"], dtype=float)
                value = function(x)
                response = {"value": np.asarray(value).tolist()}
            except Exception as error:
                response = {"error": f"{type(error).__name__}: {error}"}
            self.wfile.write((json.dumps(response) + "\n").encode())

    with TemporaryDirectory(prefix="42mp-matlab-") as directory:
        address = directory + "/callback.sock"
        with UnixStreamServer(address, Handler) as server:
            thread = Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True)
            thread.start()
            try:
                yield address
            finally:
                server.shutdown()
                thread.join()


def evaluate(address: str, function: str, x: object) -> float | FloatArray:
    """Called by MATLAB's Python interpreter; return a scalar or column vector."""
    request = {"function": function, "x": np.asarray(x, dtype=float).reshape(-1).tolist()}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.connect(address)
        connection.sendall((json.dumps(request) + "\n").encode())
        with connection.makefile("rb") as stream:
            response = json.loads(stream.readline())
    if "error" in response:
        raise RuntimeError(response["error"])
    if function == "fun":
        return float(response["value"])
    return np.asarray(response["value"], dtype=float).reshape(-1, 1)
