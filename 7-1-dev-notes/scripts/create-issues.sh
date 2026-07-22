#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPONENTS_DIR="$NOTES_DIR/components"

MODE="${1:---dry-run}"
case "$MODE" in
	--dry-run|--execute) ;;
	-h|--help)
		printf 'Usage: %s [--dry-run|--execute]\n' "$(basename "$0")"
		printf '  --dry-run  Report missing mappings and simulate issue sync (default).\n'
		printf '  --execute  Perform issue sync in GitHub and project metadata updates.\n'
		exit 0
		;;
	*)
		printf 'Invalid mode: %s\n' "$MODE" >&2
		exit 2
		;;
esac

all_tickets="$(jq -s '[.[].tickets[]]' "$COMPONENTS_DIR"/*.json)"
eligible="$(jq -c '[.[] | select((.classification == "dev-note" or .classification == "misc-dev-note" or .classification == "field-guide") and .create_issue == true)]' <<<"$all_tickets")"
missing="$(jq -c '[.[] | select((.github_issue_number | type) != "number" or (.github_issue_url | type) != "string")] | sort_by(.classification,.component,.id)' <<<"$eligible")"

printf 'Eligible tickets: %s\n' "$(jq 'length' <<<"$eligible")"
printf 'Tickets without linked GitHub issue in local files: %s\n' "$(jq 'length' <<<"$missing")"
if [[ "$(jq 'length' <<<"$missing")" -gt 0 ]]; then
	jq -r '.[] | "- #\(.id) | \(.classification) | \(.component) | \(.summary)"' <<<"$missing"
fi

"$SCRIPT_DIR/issues-dev-note" "$MODE"
"$SCRIPT_DIR/issues-misc-dev-note" "$MODE"
"$SCRIPT_DIR/issues-field-guide" "$MODE"

if [[ "$MODE" == "--execute" ]]; then
	"$SCRIPT_DIR/issues-sync-links.sh"
fi

