# test_package

A small Python function packaged for [Fission](https://fission.io), used to try out deploying function code that is built outside the cluster and fetched by URL (a Fission `Package` with `deployment.type: url`) instead of being embedded in the Package as a base64 literal.

- `main.py` - the function (`main.main`)
- `requirements.txt` - dependencies, vendored into the archive at build time (`humanize`, pure python)
- `build.sh` - builds `dist/test-package-<version>.zip`, its `.sha256`, and `dist/package.yaml`
- `fission/package.yaml.tmpl` - template for the Fission Package, Function and HTTPTrigger
- `.github/workflows/release.yml` - builds on every push and pull request; on a `v*` tag it also publishes a GitHub release

## Releasing

Push a tag:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

The workflow builds the archive and creates a release with three assets:

| Asset | What it is |
|---|---|
| `test-package-v0.1.0.zip` | `main.py` plus the vendored dependencies at the zip root |
| `test-package-v0.1.0.zip.sha256` | the checksum |
| `package.yaml` | a Fission `Package` (URL of the zip and its sha256), `Function` (`main.main`, newdeploy, scale to zero) and `HTTPTrigger` (`/test-package`) |

Apply `package.yaml` to the cluster with `kubectl apply -f`. The URL is the release asset, so the repository has to be public for the cluster to fetch it without credentials.

## Building locally

```bash
GITHUB_REPOSITORY=owner/repo ./build.sh v0.0.0-local
```

Needs `python` (with `pip`), `zip` and `shasum`. Set `FISSION_NAMESPACE` and `FISSION_ENVIRONMENT` (defaults `services` and `python`) to change what goes into `package.yaml`.

## Notes

- Fission's python environment runs `python:3.13-alpine` (musl), so only pure-python dependencies work. `build.sh` installs with `--only-binary=:all:` and fails if the archive contains any compiled `.so` file.
- The handler is `main.main` (module `main`, function `main`), the environment's default. Fission appends the extracted archive directory to `sys.path`, which is why the dependencies sit at the zip root.
