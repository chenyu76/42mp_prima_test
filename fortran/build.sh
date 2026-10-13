#!/bin/bash
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$scriptDir"
set -e

target="./generated/"
rm -rf $target
42mp -r ./ -o $target
