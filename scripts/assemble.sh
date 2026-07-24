#!/usr/bin/env bash
# Assemble the module index from registry.yaml (ADR 0065).
#
# The model is aggregation, not construction: each catalogued module publishes
# its OWN manifest.json in its release — id, version, name, SDK major, roles and
# its binaries' digests, produced by the module's CI with the Platform's
# modulesign tool. This script downloads those manifests and runs build-index
# over them, so the registry never re-derives a module's properties or re-hashes
# its bytes. The one thing it adds is the download URL per binary, from the
# template in registry.yaml.
#
# The empty catalogue is the current, expected state — no extension module ships
# out-of-process binaries yet — and it is a clean no-op, not a failure.
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
  echo "registry.yaml lists no modules — nothing to publish."
  echo "This is the expected state until an extension module ships out-of-process"
  echo "binaries; see README.md."
  echo "empty=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

# ── Non-empty path ──────────────────────────────────────────────────────────
# Reached only once a module publishes binaries; untested until one does,
# because there is nothing real to download. It glues tools that are themselves
# tested (modulesign build-index/sign-index), so the risk is confined to this
# orchestration.
mkdir -p manifests out

# Emit each module as "repo<TAB>version"; repo is the module-<suffix> repository,
# which is where its manifest and binaries are released.
python3 - <<'PY' > /tmp/modules.tsv
import yaml
c = yaml.safe_load(open("registry.yaml"))
for m in c["modules"]:
    print(f'{m["id"]}\t{m["version"]}')
PY

while IFS=$'\t' read -r id version; do
  repo="mosaic-media/module-${id}"
  manifest_url="https://github.com/${repo}/releases/download/${version}/manifest.json"
  echo "fetching manifest for ${id}@${version}"
  if ! curl -fsSL "$manifest_url" -o "manifests/${id}.json"; then
    echo "::error::${id}@${version} publishes no manifest.json at ${manifest_url}." >&2
    echo "An extension module must ship a signed manifest and binaries in its release" >&2
    echo "before it can be catalogued; a Go module tag alone is not enough." >&2
    exit 1
  fi
done < /tmp/modules.tsv

# build-index wraps the manifests — which already carry their binaries' URLs and
# digests — into the catalogue, and validates the result parses before writing.
./modulesign build-index -out out/index.json manifests/*.json

echo "empty=false" >> "$GITHUB_OUTPUT"
