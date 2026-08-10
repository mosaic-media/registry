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
## Rules every Mosaic repository shares

*Generated. The source is `architecture/shared/repository-rules.md`; edit it there
and run `scripts/shared_rules.py --write` across the fleet. A copy edited in place
fails its repository's gate, which is the point: these rules were eleven
hand-kept copies in four variants, and the abridged ones had quietly dropped the
reasoning while keeping the rules — and in one case dropped a rule outright.*

### What this file may say

**A `CLAUDE.md` states rules, and facts about its own repository. It does not
state facts about another one — it links instead.**

An audit of all twelve of these files against their source found 74 stale claims.
None of roughly 180 rules was wrong; 62 of the 74 were facts about somebody
else's repository. Ownership predicts rot: a fact about this repository stays true
because whoever changes the code changes the sentence in the same session, and a
fact about another one dies the moment they edit it with nothing here going red.

The same applies to facts this repository already publishes in a generated
artefact — counts, versions, what is built. Point at the artefact.

### Decision records live with the code they govern

Each repository owns the records whose *mechanism* it holds — the spec file, the
lint gate, the conformance corpus, the composition root, the release workflow.
A decision can bind five repositories and still have exactly one steward.

- **`docs/adr/`**, numbered from 1 in every repository, with `docs/adr/README.md`
  a **generated** index. Read the index first; it is the bounded thing.
- **A record's heading carries no number.** The number lives in the filename and
  the index only, so a record's anchor survives being renumbered.
- **Cite a record as `repo#N`, and make it a link** — a relative path within a
  repository, an absolute URL across them, and the bare label only where no URL
  is possible, such as a code comment or a Dockerfile. The old `ADR NNNN`
  spelling is refused by a lint: once every repository numbers from 1, that form
  resolves quietly to a *different* record instead of dangling, and no tool in
  the fleet could detect it.
- **Cross-cutting records stay in [`architecture`](https://github.com/mosaic-media/architecture)** —
  the ones with no enforcing mechanism anywhere: licensing, repository naming and
  topology, the module tier model.

### Decision records are append-only

An ADR is an account of what was decided and why, at a time. It is evidence, not
documentation, and its value is that it was not edited afterwards.

- **Never rewrite a record's body** — not to correct it, not to annotate it, not
  to add "as built, this differs". That turns a record into a running commentary
  and destroys the thing it is for.
- **State changes go in the `**Status:**` line and nowhere else** — built, built
  in part (naming the part), or superseded, wholly or partly.
- **A changed decision earns a new record that supersedes it**, with its own
  Context / Decision / Alternatives / Consequences, and both records then point
  at each other through their Status lines. The old body stays exactly as it was.
- **An unbuilt decision is not a superseded one.** "Not done yet" belongs in the
  Status line and the roadmap; only a reversal earns a new record.

### The roadmap is maintained, not consulted

**`docs/roadmap.md` in [`architecture`](https://github.com/mosaic-media/architecture)
is the single record of where the build is, across every repository.** It stays
there because a milestone spans repositories by construction. Read it before
starting, and **update it in the same session as the change that dates it** — not
in a follow-up, which does not happen.

- A slice that lands is marked landed, **with what it left out named in the same
  sentence**. "Built" with no qualifier claims the whole slice shipped.
- Implementation that departed from its record is recorded where it departed.
  The surprises are the most valuable thing in it.
- **Do not restate the roadmap here.** A second copy of "what is built" in a
  `CLAUDE.md` is how the first copy goes stale unnoticed.
- A capability with no client path is not done — it is
  [owed](https://github.com/mosaic-media/architecture/blob/main/docs/unreachable-capability.md).

### Demonstrated, not asserted

**Say what you actually ran.** A skipped test is not a passed test, and "it should
work" is not evidence.

Each repository's container is the authority on its own gate, and the command is
in that repository's section below. It exists because the checks that matter fail
*soft*: a missing PostgreSQL skips storage tests and still prints `ok`, a missing
generator toolchain produces a drift guard that passes by not running. Where the
container cannot be run, running what you can on the host is better than running
nothing — **provided you report which checks ran and which did not.** Claiming a
gate passed when it was not executed is the one thing this rule exists to stop.

### Commit and push

- **Commit and push each repository separately.** They are siblings on disk and
  independent in git.
- **Commit author identity** must be `AdamNi-7080 <anicholls41@gmail.com>`. If git
  has no identity configured, set it repo-locally rather than globally.
- **Push once the change has been demonstrated working in this session.** Commit
  locally and say so otherwise. **Force-push always requires asking.**
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
