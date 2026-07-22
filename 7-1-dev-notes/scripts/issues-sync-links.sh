#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPONENTS_DIR="$NOTES_DIR/components"
REPOSITORY="WordPress/Documentation-Issue-Tracker"

command -v gh >/dev/null || { printf 'Error: gh is required.\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'Error: jq is required.\n' >&2; exit 1; }
gh auth status >/dev/null

issues_file="$(mktemp)"
map_file="$(mktemp)"
trap 'rm -f "$issues_file" "$map_file"' EXIT

gh issue list --repo "$REPOSITORY" --state all --label "7.1" --limit 1000 \
  --json number,url,title,body,labels > "$issues_file"

jq -r '
  .[] as $issue |
  ([ $issue.labels[].name ] | if index("dev-note") then "dev-note" elif index("misc-dev-note") then "misc-dev-note" elif index("field-guide") then "field-guide" else empty end) as $kind |
  select($kind != null and $kind != "") |
  (([($issue.title | match("#[0-9]+"; "g") | .string)] + [($issue.body // "" | match("#[0-9]+"; "g") | .string)]) | unique)[] as $token |
  "\($token | ltrimstr("#"))\t\($kind)\t\($issue.number)\t\($issue.url)"
' "$issues_file" > "$map_file"

map_count="$(wc -l < "$map_file" | tr -d ' ')"
printf 'Collected %s ticket-to-issue references from GitHub issues.\n' "$map_count"

find "$COMPONENTS_DIR" -name '*.json' -print0 | while IFS= read -r -d '' file; do
  jq --rawfile map "$map_file" '
    def parse_map:
      ($map | split("\n") | map(select(length > 0))
        | map(split("\t") | {id:(.[0]|tonumber), cls:.[1], number:(.[2]|tonumber), url:.[3]}));
    def map_for($id; $cls):
      [parse_map[] | select(.id == $id and .cls == $cls)]
      | if length == 0 then null else .[0] end;

    .tickets |= map(
      if (.create_issue == true and (.classification == "dev-note" or .classification == "misc-dev-note" or .classification == "field-guide")) then
        (map_for(.id; .classification)) as $m
        | if $m == null then . else . + {github_issue_number:$m.number, github_issue_url:$m.url} end
      elif .classification == "exclude" then
        del(.github_issue_number, .github_issue_url)
      else
        .
      end
    )
  ' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
done

missing="$(jq -s '[.[].tickets[] | select(.create_issue == true and (.classification == "dev-note" or .classification == "misc-dev-note" or .classification == "field-guide") and ((.github_issue_number|type)!="number" or (.github_issue_url|type)!="string"))] | length' "$COMPONENTS_DIR"/*.json)"
printf 'Tickets still missing issue links: %s\n' "$missing"
