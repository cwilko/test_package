#!/bin/bash
# Builds dist/<name>-<version>.zip and its sha256. Used locally and by the release workflow. 
# Usage: ./build.sh <version>
# Constraints: Targeted python:3.13-alpine (musl), so only pure-python requirements work: the build
# fails if anything compiled (*.so) ends up in the archive.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

VERSION=${1:?usage: build.sh <version>, e.g. build.sh v0.1.0}
NAME=test-package

ZIP="$NAME-$VERSION.zip"

rm -rf build dist
mkdir build dist

python -m pip install --quiet --target build --only-binary=:all: -r requirements.txt
cp main.py build/

if find build -name '*.so' | grep -q .; then
  echo "compiled extensions found in the archive - the python environment is musl/alpine, use pure-python requirements:" >&2
  find build -name '*.so' >&2
  exit 1
fi

find build -name __pycache__ -prune -exec rm -rf {} +
(cd build && zip -X -q -r "../dist/$ZIP" .)

SHA256=$(shasum -a 256 "dist/$ZIP" | awk '{print $1}')
echo "$SHA256  $ZIP" > "dist/$ZIP.sha256"

echo "built dist/$ZIP"
echo "sha256 $SHA256"
