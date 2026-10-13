#!/bin/bash
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$scriptDir"
set -e

rm -rf ./matlab/
42mp -r ./fortran/ -o ./matlab/
