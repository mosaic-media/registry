# Claude Instructions — Mosaic registry

This repository is Mosaic's **official extension-module registry**: it publishes
the signed index a Platform installs extension modules from
([ADR 0065](https://github.com/mosaic-media/architecture/blob/main/docs/adr/0065-module-distribution-and-trust.md),
[ADR 0079](https://github.com/mosaic-media/architecture/blob/main/docs/adr/0079-the-platform-manages-extension-modules.md)).
`README.md` is the working description; read it first.

## What this repo is, and is not

- **It is a catalogue.** `registry.yaml` names the module *repositories* and
  release versions in the official set; CI downloads each one's own signed
  manifest and turns them into a signed `index.json` on GitHub Pages. It holds
  no module code and no binaries — those live in each module's own repo and
  releases. It names the repository rather than the module id because the two
  differ: `module-stremio-addons` publishes a module whose id is `stremio`.
- **It is not the trust root by itself.** The index is signed with one ed25519
  key. The private half is the `REGISTRY_SIGNING_KEY` secret here; the public
  half is trusted by the Platform. GitHub is an *untrusted* host — the signature
  and digests protect a download, not the host.

## Non-negotiable facts

- **The private signing key never lands in the repository.** It is a CI secret,
  base64-encoded, and the workflow shreds its decoded copy after signing.
- **A module is catalogued only once it ships out-of-process binaries.** Today
  the extension modules publish a Go module tag and are composed into the
  Platform binary; they cannot be in the index until their release produces
  cross-compiled, signed binaries and a `manifest.json`. The publish workflow
  refuses to catalogue a module with no downloadable binary rather than emit a
  broken index.
- **`modulesign` is built from a `platform` checkout** because it depends on the
  Platform's internal packages today. Extracting the manifest/index format to a
  public module is a deliberate later decision, noted in `README.md`, not a
  thing to work around silently here.

## The roadmap and the decision records

These rules are identical in every Mosaic repository.

- **The roadmap is maintained, not consulted.** `docs/roadmap.md` in
  [`architecture`](https://github.com/mosaic-media/architecture) is the single
  record of where the build is, for every repository. A change here that dates
  it is a change to the roadmap, in the same session.
- **Decision records are append-only** and live only in `architecture/docs/adr/`.
  If the registry's shape changes a recorded decision, that is a new ADR, not an
  edit to an old one.
- **Commit author identity** must be `AdamNi-7080 <anicholls41@gmail.com>`.

## Working expectations

- The catalogue now has its first real entry (`module-stremio-addons@v0.24.0`),
  so the publish workflow's non-empty path runs for real: it fetches that
  release's manifest and builds a signed index. The empty-catalogue no-op path
  remains and must stay a clean no-op.
- When something is undecided, say so rather than inventing a convention that a
  real module release then has to fight. The id/URL scheme *was* that live
  example and is now settled: a module's binary URLs live in its own
  `manifest.json` (it knows where it hosts its bytes; the registry never
  computes a URL), and the catalogue names the *repository* to fetch that
  manifest from — since a repo name does not follow from a module id — so the
  registry only aggregates and signs — it computes no URLs.
