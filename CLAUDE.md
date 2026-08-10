# Claude Instructions — Mosaic registry

This repository is Mosaic's **official extension-module registry**: it publishes
the signed index a Platform installs extension modules from
([platform#40](https://github.com/mosaic-media/platform/blob/main/docs/adr/0040-module-distribution-and-trust.md),
[platform#49](https://github.com/mosaic-media/platform/blob/main/docs/adr/0049-the-platform-manages-extension-modules.md)).
`README.md` is the working description; read it first.

## What this repo is, and is not

- **It is a catalogue.** `registry.yaml` names the module *repositories* and
  release versions in the official set; CI downloads each one's own manifest —
  **unsigned**, since a module signs nothing: `modulesign build-manifest` emits
  it carrying each binary's digest, and the index signature is what authenticates
  the manifest and those digests — and turns them into a signed `index.json` on
  GitHub Pages. It holds no module code and no binaries — those live in each
  module's own repo and releases. It names the repository rather than the module
  id because the two differ: `module-stremio-addons` publishes a module whose id
  is `stremio`.
- **It is not the trust root by itself.** The index is signed with one ed25519
  key. The private half is the `REGISTRY_SIGNING_KEY` secret here; the public
  half is trusted by the Platform. GitHub is an *untrusted* host — the signature
  and digests protect a download, not the host.

## Non-negotiable facts

- **The private signing key never lands in the repository.** It is a CI secret,
  base64-encoded, and the workflow removes its decoded copy immediately after
  signing.
- **A module is catalogued only once it ships out-of-process binaries.** The
  publish workflow refuses to catalogue a module whose release publishes no
  downloadable `manifest.json`, rather than emit a broken index, and the `bump`
  job makes the same check before it will move an entry — so the refusal lands on
  the dispatch that caused it rather than on every publish afterwards. **Whether
  a given module ships binaries is that module's fact, not this repository's**:
  the rule is what governs the next one.
- **A dispatch moves an entry; it never adds one.** `publish.yml`'s `bump` job
  refuses a repository that is not already in `registry.yaml`. Enrolling in the
  official set is the
  [platform#40](https://github.com/mosaic-media/platform/blob/main/docs/adr/0040-module-distribution-and-trust.md)
  trust decision — one key vouches for everything the index carries — and a
  repository must not be able to make that decision on its own behalf. Adding a
  module is a deliberate edit here, by a person.
- **`modulesign` is not built from this repository.** `publish.yml` checks out
  [`platform`](https://github.com/mosaic-media/platform) and builds
  `./tools/modulesign` from it, because the tool depends on that repository's
  internal packages. Extracting the manifest and index format to a public module
  is a deliberate later decision, noted in `README.md` — not a thing to work
  around silently here.

## Working expectations

- **The catalogue is not edited by hand any more, and that is the point.** A
  module's release dispatches `module-released`, the `bump` job moves its version
  by pull request, and the merge is what republishes the index — so `publish.yml`
  triggers on a push to `main` touching `registry.yaml`. Hand-curation is what
  left the catalogue three releases stale for two days with nothing red anywhere,
  because a stale catalogue publishes a perfectly valid signed index that simply
  offers old versions. If you find yourself editing a version in `registry.yaml`,
  ask first whether the dispatch chain is broken — that is the actual defect.
- **Adding or removing a module is still a hand edit**, and the only one. See the
  non-negotiable facts above for why.
- The empty-catalogue path in `assemble.sh` remains and must stay a clean no-op,
  even though nothing reaches it now.
- When something is undecided, say so rather than inventing a convention that a
  real module release then has to fight. The id and URL scheme *was* that live
  example and is now settled: a module's binary URLs live in its own
  `manifest.json` — it knows where it hosts its bytes — and the catalogue names
  the *repository* to fetch that manifest from, since a repo name does not follow
  from a module id. The registry aggregates and signs; it computes no URLs.

<!-- shared-rules:begin -->
<!-- shared-rules:end -->

## Records and the gate, in this repository

**This repository owns no decision records and has no `docs/adr/`.** That is
correct rather than an omission: every decision it implements — the trust model,
the distribution shape, who manages an installed module — is enforced by a
mechanism in [`platform`](https://github.com/mosaic-media/platform), so the
records live there. If a change here would change a recorded decision, the new
record belongs in the repository holding the mechanism, and this one links to it.

**There is no test container here, and nothing to run locally.** This repository
is a YAML catalogue, a shell script and a workflow; its gate is `publish.yml`
itself, which refuses rather than publishing something broken. So verification is
by reading — `registry.yaml`, `scripts/assemble.sh`,
`.github/workflows/publish.yml` — and by watching the run that a merge triggers.
**Say which of those you actually read**, and never describe the published index
from this repository's source: fetch it.
