#!/bin/bash
# Builds dist/<name>-<version>.zip (main.py with the requirements vendored at the zip root, which is what Fission's
# python environment imports from), its sha256, and dist/package.yaml (the Fission Package, Function and HTTPTrigger
# that point at the release asset). Used locally and by the release workflow.
# Usage: GITHUB_REPOSITORY=owner/repo ./build.sh <version>     (the workflow sets GITHUB_REPOSITORY itself)
# The Fission python environment runs python:3.13-alpine (musl), so only pure-python requirements work: the build
# fails if anything compiled (*.so) ends up in the archive.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

VERSION=${1:?usage: build.sh <version>, e.g. build.sh v0.1.0}
REPO=${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY, e.g. owner/repo}
NAME=test-package
FISSION_NAMESPACE=${FISSION_NAMESPACE:-services}
FISSION_ENVIRONMENT=${FISSION_ENVIRONMENT:-python}

ZIP="$NAME-$VERSION.zip"
URL="https://github.com/$REPO/releases/download/$VERSION/$ZIP"

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

sed -e "s|__NAME__|$NAME|g" \
    -e "s|__NAMESPACE__|$FISSION_NAMESPACE|g" \
    -e "s|__ENVIRONMENT__|$FISSION_ENVIRONMENT|g" \
    -e "s|__URL__|$URL|g" \
    -e "s|__SHA256__|$SHA256|g" \
    fission/package.yaml.tmpl > dist/package.yaml

echo "built dist/$ZIP"
echo "sha256 $SHA256"
echo "url    $URL"
