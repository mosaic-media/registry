# Mosaic registry

Mosaic's **official extension-module registry**: the signed index a Platform
fetches to discover and install extension modules
([ADR 0065](https://github.com/mosaic-media/architecture/blob/main/docs/adr/0065-module-distribution-and-trust.md),
managed by the Platform per
[ADR 0079](https://github.com/mosaic-media/architecture/blob/main/docs/adr/0079-the-platform-manages-extension-modules.md)).

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
registry.yaml  ──(CI: build-index + sign-index)──▶  index.json + index.json.sig
     │                                                        │
     │ names modules + versions                               │ published to GitHub Pages
     ▼                                                        ▼
module release binaries  ◀───── the Platform downloads, verifies, spawns ─────  Platform
   (in each module's own GitHub Releases)                    (gRPC over a Unix socket)
```

## How it works

- **`registry.yaml`** is the source of truth: which modules, at which versions,
  belong in the official catalogue.
- **`.github/workflows/publish.yml`** turns that into a signed index: it digests
  each module's release binaries, assembles a manifest per module, runs
  `build-index` and `sign-index`, and deploys the result to Pages. The binaries
  themselves stay in each module's own releases and are referenced by URL.
- The index is signed with **one ed25519 key** — the official repository key.
  Its public half is trusted by the Platform by default; its private half is a
  CI secret here and nowhere else.

## What it is waiting on

This is scaffolding, and it is honest about that. Publishing a real index needs
two things that do not exist yet:

1. **The signing key.** Generate it with the Platform's tool —
   `go run ./tools/modulesign genkey -out mosaic-official.key` in the `platform`
   checkout — store the private half as this repo's `REGISTRY_SIGNING_KEY`
   secret (base64), and trust the public half in the Platform. The private key
   is the trust anchor for the whole extension ecosystem; treat it accordingly,
   and prefer a KMS over a raw secret once past the prototype.
2. **Extension modules that produce binaries.** Today the extension modules
   (`module-stremio-addons`, `module-aiostreams`, `module-fanart-tv`) are still
   composed *into* the Platform binary and publish only a Go module tag. The
   registry catalogues *out-of-process* modules — cross-compiled, signed
   binaries — so each must first switch its release to produce those (the shape
   its `release.yml` changes to when it moves out of process). Until then, this
   registry has nothing real to publish, and the workflow says so rather than
   inventing an entry.

## A known interim

`build-index`/`sign-index` live in `platform/tools/modulesign`, which depends on
the Platform's internal packages, so the workflow builds the tool from a
`platform` checkout. The manifest and index *format* is something third-party
publishers must also produce, so it should eventually be extracted to a public
module — noted here so it is a deliberate later decision, not a surprise.

## License

MIT (see [`LICENSE`](LICENSE)). The catalogue is metadata; the modules it points
at carry their own licenses.
