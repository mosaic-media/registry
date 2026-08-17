# Claude Instructions — registry

Mosaic's official extension-module registry. `registry.yaml` is the catalogue;
CI turns it into a signed `index.json` published to GitHub Pages. `README.md`
describes the shape — this file is how to work here without breaking it.

Fleet-wide conventions — commits, decision records, citation form, the roadmap —
are in [`architecture`](https://github.com/mosaic-media/architecture/blob/main/CLAUDE.md).
This file is what is specific to `registry`.

## What is here

`registry.yaml`, `scripts/assemble.sh`, two workflows and a vendored citation
lint. No module code, no binaries and no Go source: the modules' own releases
hold those, and this repository only points at them.

## The catalogue names a repository, not a module id

Each entry is a GitHub repository under `mosaic-media` plus a release tag,
because a repository name does not follow from a module id — the id cannot
locate the release. Everything else, including the id itself, the roles, and the
binaries' URLs and digests, comes from the `manifest.json` that release
publishes.

`scripts/assemble.sh` downloads each catalogued release's manifest and runs
`modulesign build-index` over them. **The registry aggregates and signs; it
computes no URL and re-hashes no bytes.** Anything derived here is a second
answer to a question the manifest already answered. Its empty-catalogue branch
is a clean no-op and must stay one.

## What is signed, and with what

One ed25519 key signs the index. The private half is the base64
`REGISTRY_SIGNING_KEY` secret and lives nowhere else: `publish.yml` decodes it
under `umask 077` and deletes it on the next line. **Do not insert a step
between those two lines** — the step aborts on error, so anything that can fail
in between leaves `signing.key` on disk. Its `.gitignore` entry is a backstop,
not the mechanism.

A module's manifest is not signed by the module. The index signature over it is
what authenticates that manifest and the digests it carries.

## What a dispatch may do, and what it may not

`publish.yml`'s `bump` job moves one version on an entry that already exists. It
refuses:

- a repository not matching `^module-[a-z0-9-]+$`, or a version that is not
  `vMAJOR.MINOR.PATCH`;
- a repository not already in `registry.yaml` — enrolling in the official set is
  the trust decision one key vouching for everything makes, and a repository
  must not be able to take it on its own behalf;
- a release publishing no downloadable `manifest.json`, checked before the edit
  so the failure lands on the dispatch that caused it rather than on every
  publish afterwards.

A dispatch repeating the catalogued version is a no-op and opens no pull
request. The edit is a targeted `awk` line change, then proved twice: the file
re-parses and says the requested version, and exactly one line changed.
**Never round-trip `registry.yaml` through a YAML library** — it is mostly
comments, and a load-and-dump drops all of them.

## Adding or removing a module is the only hand edit

Merging a change to `registry.yaml` on `main` is what republishes; that path
filter is the publish trigger. **A version that is behind is a broken dispatch
chain, not a line to fix by hand** — a stale catalogue publishes a perfectly
valid signed index and nothing goes red, so editing it hides the defect.

`CATALOGUE_BUMP_TOKEN` has to be a PAT rather than the default `github.token`:
a merge performed by `github.token` raises no further workflow run, so the
catalogue would move and the published index would stay exactly as stale.

## The gate is the publish workflow

There is no test container and nothing to build. Two workflows run:

- `.github/workflows/verify.yml` — on a push to `main` and on every pull
  request, and the only thing runnable locally:
  `python3 scripts/adr_lint.py --repo registry --exclude 'scripts/adr_*.py'`
- `.github/workflows/publish.yml` — the gate for the catalogue itself. It
  refuses loudly rather than publishing something broken.

`scripts/assemble.sh` cannot be run on a laptop as-is: it appends to
`$GITHUB_OUTPUT` under `set -u` and expects a built `./modulesign` beside it.
So verifying a change means **reading** `registry.yaml`, `scripts/assemble.sh`
and `.github/workflows/publish.yml`, and watching the run a merge triggers —
say which of those you actually did. **Never describe the published index from
this repository's source; fetch it** from the base URL `registry.yaml` names.

## Two things this repository does not hold

- **`modulesign`.** `publish.yml` checks out
  [`platform`](https://github.com/mosaic-media/platform) and builds
  `./tools/modulesign` from there. Link to that repository rather than
  describing the tool: the manifest and index formats are its business, and
  changing either is a change over there.
- **Decision records.** There is no `docs/adr/` here, and every decision this
  repository implements is enforced by a mechanism elsewhere. A new record
  belongs with that mechanism, and this repository cites it.

`scripts/adr_lint.py` is vendored and says so in its header. Do not edit it
here; change it at its source and re-vendor.
