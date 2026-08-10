#!/usr/bin/env bash
# Assemble the module index from registry.yaml (platform#40).
#
# The model is aggregation, not construction: each catalogued module publishes
# its OWN manifest.json in its release — id, version, name, SDK major, roles and
# its binaries' digests AND their download URLs, produced by the module's CI with
# the Platform's modulesign tool. This script downloads those manifests and runs
# build-index over them, so the registry never re-derives a module's properties,
# re-hashes its bytes, or computes a URL. It adds nothing to a manifest; it only
# aggregates and (in publish.yml) signs.
#
# The one thing the catalogue must supply that a manifest cannot is *where to
# fetch that manifest from*: a module's repository name is not its module id
# (module-stremio-addons publishes a module whose id is "stremio"), so the id
# cannot locate the repo. Each entry therefore names its repository outright.
#
# The empty catalogue is a clean no-op rather than a failure. It is no longer the
# expected state: all three extension modules ship out-of-process binaries and
# are catalogued, so nothing reaches that branch today. It stays because a
# catalogue emptied deliberately must publish an empty index rather than fail.
set -euo pipefail

python3 -m pip install --quiet pyyaml >/dev/null 2>&1 || true

read -r REPO_URL MODULE_COUNT < <(python3 - <<'PY'
import yaml
c = yaml.safe_load(open("registry.yaml")) or {}
repo = c.get("repository", {})
mods = c.get("modules") or []
print(repo.get("url", ""), len(mods))
PY
)

if [ "${MODULE_COUNT:-0}" -eq 0 ]; then
  echo "registry.yaml lists no modules — publishing an empty index."
  echo "That is a clean no-op, not a failure, but it is no longer the expected"
  echo "state: the catalogue normally lists every extension module. If you did"
  echo "not empty it deliberately, check what removed the entries; see README.md."
  echo "empty=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

# ── Non-empty path ──────────────────────────────────────────────────────────
# This is the live path — every publish takes it, since the catalogue has three
# modules in it. It glues tools that are themselves tested (modulesign
# build-index/sign-index), so the risk is confined to this orchestration; what
# has no test of its own is the orchestration, and a publish is what exercises
# it.
mkdir -p manifests out

# Emit each module as "repo<TAB>version"; repo is the GitHub repository (under
# mosaic-media) that publishes its manifest and binaries as release assets.
python3 - <<'PY' > /tmp/modules.tsv
import yaml
c = yaml.safe_load(open("registry.yaml"))
for m in c["modules"]:
    print(f'{m["repo"]}\t{m["version"]}')
PY

while IFS=$'\t' read -r repo version; do
  manifest_url="https://github.com/mosaic-media/${repo}/releases/download/${version}/manifest.json"
  echo "fetching manifest from ${repo}@${version}"
  if ! curl -fsSL "$manifest_url" -o "manifests/${repo}.json"; then
    echo "::error::${repo}@${version} publishes no manifest.json at ${manifest_url}." >&2
    echo "An extension module must ship a manifest.json and its binaries in its release" >&2
    echo "before it can be catalogued; a Go module tag alone is not enough." >&2
    echo "The manifest is not signed by the module — 'modulesign build-manifest' emits" >&2
    echo "it unsigned, carrying each binary's digest, and the index signature over it" >&2
    echo "is what authenticates both (platform#40)." >&2
    exit 1
  fi
done < /tmp/modules.tsv

# build-index wraps the manifests — which already carry their binaries' URLs and
# digests — into the catalogue, and validates the result parses before writing.
./modulesign build-index -out out/index.json manifests/*.json

echo "empty=false" >> "$GITHUB_OUTPUT"
