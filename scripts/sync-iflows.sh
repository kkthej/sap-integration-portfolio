#!/usr/bin/env bash
# Pulls every iFlow in a Cloud Integration package via the OData API and
# unpacks it into cloud-integration/iflows/<IflowId>/.
# Keeps any README.md / flow.png you add next to the exported files.
set -euo pipefail

: "${CPI_URL:?}" "${CPI_TOKEN_URL:?}" "${CPI_CLIENT_ID:?}" "${CPI_CLIENT_SECRET:?}" "${PACKAGE_ID:?}"
OUT=cloud-integration/iflows

# 1. OAuth token (client credentials from the service key)
TOKEN=$(curl -sfS -u "$CPI_CLIENT_ID:$CPI_CLIENT_SECRET" \
  -X POST "$CPI_TOKEN_URL?grant_type=client_credentials" | jq -r .access_token)

api() { curl -sfS -H "Authorization: Bearer $TOKEN" "$@"; }

# 2. List the iFlows in the package
api -H "Accept: application/json" \
  "$CPI_URL/api/v1/IntegrationPackages('$PACKAGE_ID')/IntegrationDesigntimeArtifacts" \
  | jq -r '.d.results[] | "\(.Id)\t\(.Name)"' > /tmp/iflows.tsv

echo "Found $(wc -l < /tmp/iflows.tsv) iFlow(s) in $PACKAGE_ID"

# 3. Download + unzip each one
while IFS=$'\t' read -r ID NAME; do
  echo "→ $ID ($NAME)"
  DIR="$OUT/$ID"
  mkdir -p "$DIR"
  rm -rf "$DIR/META-INF" "$DIR/src" "$DIR/.project"   # replace export, keep your docs
  api -o /tmp/iflow.zip \
    "$CPI_URL/api/v1/IntegrationDesigntimeArtifacts(Id='$ID',Version='active')/\$value"
  unzip -oq /tmp/iflow.zip -d "$DIR"
  # The export writes a "#<date> UTC <year>" comment into these files on every
  # download. Strip it so unchanged iFlows don't produce a commit on each run.
  for f in "$DIR/metainfo.prop" "$DIR/src/main/resources/parameters.prop"; do
    [ -f "$f" ] && sed -i -E '/^#.* UTC [0-9]{4}$/d' "$f"
  done
done < /tmp/iflows.tsv
