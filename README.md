# test_package

A small Python function packaged for [Fission](https://fission.io), used to try out deploying function code that is built outside the cluster and fetched by URL (a Fission `Package` with `deployment.type: url`) instead of being embedded in the Package as a base64 literal.

- `main.py` - the function (`main.main`)
- `requirements.txt` - dependencies, vendored into the archive at build time (`humanize`, pure python)
- `build.sh` - builds `dist/test-package-<version>.zip` and its `.sha256`: the plain package, with no Fission deployment config in it

Release automation lives under `.github/`, apart from the package itself:

- `.github/workflows/release.yml` - builds on every push and pull request, and publishes a release or pre-release (see below)
- `.github/scripts/build-fission-package.sh` - renders `dist/package.yaml` from the zip and checksum that `build.sh` produced, and renders the spec to `dist/openapi.yaml`
- `.github/fission/package.yaml.tmpl` - template for the Fission Package, Function and HTTPTrigger, including the catalog annotations
- `.github/fission/openapi.yaml` - template for the endpoint's OpenAPI document, rendered and published as a release asset (the server URL is `API_BASE_URL` in `release.yml`)
- `.github/scripts/prune-dev-releases.sh` - deletes old development pre-releases (see below)

## What gets published

| Event | Version | Result |
|---|---|---|
| pull request | `ci-<sha>` | build only, nothing published |
| push to `main` | `dev-<short sha>` | a GitHub **pre-release** with the assets below, then old dev pre-releases are pruned |
| push a `v*` tag | the tag, e.g. `v0.1.0` | a normal release with the assets below |

Every build has its own URL and its own checksum, so a Package pointing at a build never changes underneath you.

| Asset | What it is |
|---|---|
| `test-package-<version>.zip` | `main.py` plus the vendored dependencies at the zip root |
| `test-package-<version>.zip.sha256` | the checksum |
| `package.yaml` | an example Fission deployment of the zip, from a separate workflow step: a `Package` (URL of the zip and its sha256), `Function` (`main.main`, newdeploy, scale to zero) and `HTTPTrigger` (`/test-package`) |
| `openapi.yaml` | the OpenAPI document for `/test-package`; the `HTTPTrigger` in `package.yaml` links to it through its `catalog.squirrelhome.co.uk/openapi` annotation |

The URL is the release asset, so the repository has to be public for the cluster to fetch it without credentials.

## Development workflow

1. Edit and try it locally: run `main()` directly, or `./build.sh v0.0.0-local` and import `main` from the unpacked zip.
2. Push to `main`. About a minute later there is a `dev-<sha>` pre-release.
3. Pull the `package.yaml` you want and apply it:

   ```bash
   gh release list --repo cwilko/test_package             # newest first; dev builds are marked Pre-release
   gh release download dev-1a2b3c4 --repo cwilko/test_package --pattern package.yaml --output package.yaml
   kubectl apply -f package.yaml
   ```

4. When it's good, tag a real release: `git tag v0.2.0 && git push origin v0.2.0`.

### Pruning

Pruning is automatic. Each push to `main` publishes its `dev-<sha>` pre-release and then runs `.github/scripts/prune-dev-releases.sh`, which keeps the newest `KEEP_DEV_RELEASES` (5, set in the workflow) and deletes the rest together with their tags. It only ever selects pre-releases whose tag starts with `dev-`; `v*` releases (including `v*-rc` pre-releases) are never touched.

Because old dev builds disappear, a Package that still points at a pruned `dev-<sha>` URL can't fetch its code the next time Fission starts a pod for it. Apply a newer `package.yaml`, or tag a `v*` release for anything that has to stay deployed.

To prune by hand, or to keep a different number: `.github/scripts/prune-dev-releases.sh 3`.

## Building locally

```bash
./build.sh v0.0.0-local
```

Needs `python` (with `pip`), `zip` and `shasum`. To also render the Fission manifest for that build:

```bash
GITHUB_REPOSITORY=owner/repo API_BASE_URL=https://api.example.com .github/scripts/build-fission-package.sh v0.0.0-local
```

Set `FISSION_NAMESPACE` and `FISSION_ENVIRONMENT` (defaults `services` and `python`) to change what goes into `package.yaml`.

## Notes

- Fission's python environment runs `python:3.13-alpine` (musl), so only pure-python dependencies work. `build.sh` installs with `--only-binary=:all:` and fails if the archive contains any compiled `.so` file.
- The handler is `main.main` (module `main`, function `main`), the environment's default. Fission appends the extracted archive directory to `sys.path`, which is why the dependencies sit at the zip root.
