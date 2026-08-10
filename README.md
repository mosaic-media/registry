# Mosaic registry

Mosaic's **official extension-module registry**: the signed index a Platform
fetches to discover and install extension modules
([platform#40](https://github.com/mosaic-media/platform/blob/main/docs/adr/0040-module-distribution-and-trust.md),
managed by the Platform per
[platform#49](https://github.com/mosaic-media/platform/blob/main/docs/adr/0049-the-platform-manages-extension-modules.md)).

## What this is, in one paragraph

A repository, in Mosaic's sense, is **signed static files over HTTPS** — nothing
more. This repo holds the catalogue of official extension modules, and its CI
builds that catalogue into a signed `index.json`, publishes it to GitHub Pages,
and lets the modules' own release binaries be the download targets. A Platform
fetches the index, verifies its signature against the one key it trusts by
default, then downloads and verifies each module before running it. **GitHub is
an untrusted host here** — the signature and per-binary digests protect a
download, not the host — which is exactly why static hosting is enough.

```
a module release ──(dispatch: module-released)──▶  registry.yaml  (bumped by PR)
                                                         │
                                 (CI: build-index + sign-index) │ on merge to main
                                                         ▼
                                              index.json + index.json.sig
     │                                                   │
     │ names repositories + versions                     │ published to GitHub Pages
     ▼                                                   ▼
module release binaries  ◀──── the Platform downloads, verifies, spawns ────  Platform
   (in each module's own GitHub Releases)                  (gRPC over a Unix socket)
```

## How it works

- **`registry.yaml`** is the source of truth: which module repositories, at which
  versions, belong in the official catalogue. It names the *repository* rather
  than the module id, because the two differ — `module-stremio-addons` publishes
  a module whose id is `stremio` — and only the repository locates the release to
  fetch a manifest from.
- **`.github/workflows/publish.yml`** turns that into a signed index: it
  downloads each catalogued release's own `manifest.json`, runs `build-index`
  and `sign-index` over them, and deploys the result to Pages. The binaries
  themselves stay in each module's own releases and are referenced by URL. The
  registry aggregates and signs; it computes nothing.
- The index is signed with **one ed25519 key** — the official repository key.
  Its public half is trusted by the Platform by default; its private half is the
  `REGISTRY_SIGNING_KEY` CI secret here and nowhere else.

## The catalogue moves itself

A module's release dispatches `module-released` here once it has uploaded its
binaries and its `manifest.json`, and `publish.yml`'s `bump` job moves that
module's version in `registry.yaml` by opening a pull request. Merging is what
republishes: `registry.yaml` is the index's only input, so a change to it on
`main` triggers the publish.

The reason it is automated rather than remembered is that **forgetting is
silent**. Hand-curation left the catalogue three releases behind on all three
modules for two days, and nothing anywhere went red, because a stale catalogue
publishes a perfectly valid, correctly signed index — it just offers versions
nobody released. The only visible symptom is a user installing an old module.

A dispatch can only ever **move** an entry. A repository that is not already
catalogued is refused, because enrolling in the official set is the trust
decision this whole repository is about — one key vouches for everything the
index carries — and a repository must not be able to make that decision on its
own behalf. Adding a module stays a deliberate edit to `registry.yaml`.

Two secrets carry it: `REGISTRY_DISPATCH_TOKEN` (on the modules, org-wide) to
send the dispatch, and `CATALOGUE_BUMP_TOKEN` here to open and merge the pull
request. The second must be a PAT rather than the default `github.token`,
because a merge performed by `github.token` raises no further workflow run — the
catalogue would move and the index would stay exactly as stale as before.

## The signing key

It exists and the index is signed with it. Generating or rotating one is the
Platform's tool — `go run ./tools/modulesign genkey -out mosaic-official.key` in
a `platform` checkout — with the private half stored here as the base64
`REGISTRY_SIGNING_KEY` secret and the public half trusted in the Platform. **It
is the trust anchor for the whole extension ecosystem**: treat it accordingly,
and prefer a KMS over a raw secret once past the prototype. Rotating it means
re-trusting the public half in the Platform first, or every install breaks.

## A known interim

`build-index`/`sign-index` live in `platform/tools/modulesign`, which depends on
the Platform's internal packages, so the workflow builds the tool from a
`platform` checkout. The manifest and index *format* is something third-party
publishers must also produce, so it should eventually be extracted to a public
module — noted here so it is a deliberate later decision, not a surprise.

## License

MIT (see [`LICENSE`](LICENSE)). The catalogue is metadata; the modules it points
at carry their own licenses.
