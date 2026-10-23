#!/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

# Keep the previous output until translation and adapter copying succeed.
staging_dir="$(mktemp -d "$script_dir/.build.XXXXXX")"
trap 'rm -rf -- "$staging_dir"' EXIT

42mp -r ./ -o "$staging_dir/" ./*.f90
cp -- ./*.m "$staging_dir/"
rm -rf -- "$script_dir/generated"
mv -- "$staging_dir" "$script_dir/generated"
