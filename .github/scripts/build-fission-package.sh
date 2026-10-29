#!/bin/bash
# Renders dist/package.yaml, the Fission Package, Function and HTTPTrigger that point at the release asset, from
# .github/fission/package.yaml.tmpl, and renders .github/fission/openapi.yaml to dist/openapi.yaml so it is published as a
# release asset too (the trigger's openapi annotation points at it). This is the Fission deployment layer on top of a plain build: it reads the zip and
# checksum that build.sh already wrote to dist/ and knows nothing about how they were made.
# Usage: GITHUB_REPOSITORY=owner/repo API_BASE_URL=https://api.example.com .github/scripts/build-fission-package.sh <version>
# (run after build.sh <version>; the workflow sets GITHUB_REPOSITORY itself and API_BASE_URL from release.yml). API_BASE_URL
# is the public host that serves the function, which goes in the spec's servers block.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

VERSION=${1:?usage: build-fission-package.sh <version>, e.g. build-fission-package.sh v0.1.0}
REPO=${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY, e.g. owner/repo}
API_BASE_URL=${API_BASE_URL:?set API_BASE_URL, the public base URL the function is served from, e.g. https://api.example.com}
FISSION_NAMESPACE=${FISSION_NAMESPACE:-services}
FISSION_ENVIRONMENT=${FISSION_ENVIRONMENT:-python}

zips=(dist/*-"$VERSION".zip)
[ "${#zips[@]}" -eq 1 ] && [ -f "${zips[0]}" ] || { echo "expected exactly one dist/*-$VERSION.zip, run build.sh $VERSION first" >&2; exit 1; }

ZIP=$(basename "${zips[0]}")
NAME=${ZIP%-"$VERSION".zip}
URL="https://github.com/$REPO/releases/download/$VERSION/$ZIP"
OPENAPI_URL="https://github.com/$REPO/releases/download/$VERSION/openapi.yaml"
read -r SHA256 _ < "dist/$ZIP.sha256"

sed -e "s|__NAME__|$NAME|g" \
    -e "s|__SERVER_URL__|$API_BASE_URL|g" \
    .github/fission/openapi.yaml > dist/openapi.yaml

sed -e "s|__NAME__|$NAME|g" \
    -e "s|__NAMESPACE__|$FISSION_NAMESPACE|g" \
    -e "s|__ENVIRONMENT__|$FISSION_ENVIRONMENT|g" \
    -e "s|__URL__|$URL|g" \
    -e "s|__SHA256__|$SHA256|g" \
    -e "s|__OPENAPI_URL__|$OPENAPI_URL|g" \
    .github/fission/package.yaml.tmpl > dist/package.yaml

echo "built dist/package.yaml and dist/openapi.yaml"
echo "sha256 $SHA256"
echo "url    $URL"
