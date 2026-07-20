#!/usr/bin/env bash

set -euo pipefail

readonly REPOSITORY="WordPress/Documentation-Issue-Tracker"
readonly PROJECT_OWNER="WordPress"
readonly PROJECT_NUMBER="295"
readonly RELEASE_LABEL="7.1"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly NOTES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly TEMPLATE_FILE="$NOTES_DIR/issue-template.md"
readonly COMPONENTS_DIR="$NOTES_DIR/components"
readonly MISC_GROUPS_FILE="$NOTES_DIR/misc-dev-note-groups.json"

EXECUTE=false
EXISTING_ISSUES_FILE=""
PROJECT_DATA_FILE=""

usage_common() {
    printf 'Usage: %s [--dry-run|--execute]\n' "$(basename "$0")"
    printf '  --dry-run  Validate and print proposed issues without creating them (default).\n'
    printf '  --execute  Create missing issues and add them to WordPress project %s.\n' "$PROJECT_NUMBER"
}

parse_mode() {
    if (( $# > 1 )); then
        usage_common >&2
        exit 2
    fi

    case "${1:---dry-run}" in
        --dry-run) EXECUTE=false ;;
        --execute) EXECUTE=true ;;
        -h|--help) usage_common; exit 0 ;;
        *) usage_common >&2; exit 2 ;;
    esac
}

cleanup_common() {
    [[ -z "$EXISTING_ISSUES_FILE" ]] || rm -f "$EXISTING_ISSUES_FILE"
    [[ -z "$PROJECT_DATA_FILE" ]] || rm -f "$PROJECT_DATA_FILE"
}

require_tools_and_files() {
    command -v gh >/dev/null || { printf 'Error: gh is required.\n' >&2; exit 1; }
    command -v jq >/dev/null || { printf 'Error: jq is required.\n' >&2; exit 1; }
    [[ -f "$TEMPLATE_FILE" ]] || { printf 'Error: missing template: %s\n' "$TEMPLATE_FILE" >&2; exit 1; }
    compgen -G "$COMPONENTS_DIR/*.json" >/dev/null || { printf 'Error: no component JSON files found.\n' >&2; exit 1; }

    gh auth status >/dev/null

    local labels
    labels="$(gh label list --repo "$REPOSITORY" --limit 1000 --json name --jq '.[].name')"
    local required_label
    for required_label in "$RELEASE_LABEL" dev-note misc-dev-note field-guide; do
        grep -Fxq "$required_label" <<<"$labels" || {
            printf 'Error: required label %s does not exist in %s.\n' "$required_label" "$REPOSITORY" >&2
            exit 1
        }
    done

    EXISTING_ISSUES_FILE="$(mktemp)"
    gh issue list --repo "$REPOSITORY" --state all --limit 1000 \
        --json number,title,body,url > "$EXISTING_ISSUES_FILE"
}

load_project_data() {
    [[ "$EXECUTE" == true ]] || return 0

    PROJECT_DATA_FILE="$(mktemp)"
    gh api graphql -f query='query($owner:String!,$number:Int!){organization(login:$owner){projectV2(number:$number){id fields(first:100){nodes{... on ProjectV2Field{id name dataType} ... on ProjectV2SingleSelectField{id name dataType options{id name}}}}}}}' \
        -F owner="$PROJECT_OWNER" -F number="$PROJECT_NUMBER" \
        --jq '.data.organization.projectV2' > "$PROJECT_DATA_FILE"

    jq -e '.id and (.fields.nodes | map(.name) | index("Docs Type") != null) and (.fields.nodes | map(.name) | index("Component") != null)' \
        "$PROJECT_DATA_FILE" >/dev/null || {
        printf 'Error: project or required project fields were not found.\n' >&2
        exit 1
    }
}

all_tickets_json() {
    jq -s '[.[].tickets[]]' "$COMPONENTS_DIR"/*.json
}

same_issue_url() {
    local title="$1"
    local marker="$2"
    jq -r --arg title "$title" --arg marker "$marker" '
        [.[] | select(.title == $title or ((.body // "") | contains($marker)))] |
        if length == 0 then "" elif length == 1 then .[0].url else error("multiple matching issues") end
    ' "$EXISTING_ISSUES_FILE"
}

ticket_conflicts_json() {
    local tickets_json="$1"
    jq -n --slurpfile issues "$EXISTING_ISSUES_FILE" --argjson tickets "$tickets_json" '
        [$tickets[] as $ticket |
            $issues[0][] |
            select((.body // "") | contains($ticket.url)) |
            {ticket_id:$ticket.id, issue_number:.number, issue_url:.url}
        ] | unique_by([.ticket_id,.issue_number])
    '
}

render_body() {
    local output_file="$1"
    local marker="$2"
    local decision="$3"
    local overview="$4"
    local tickets_json="$5"

    {
        printf '<!-- %s -->\n\n' "$marker"
        printf '## Trac ticket%s\n\n' "$(jq -r 'if length == 1 then "" else "s" end' <<<"$tickets_json")"
        jq -r '.[] | "- [#\(.id)](\(.url)) — \(.summary)"' <<<"$tickets_json"
        printf '\n## Summary\n\n%s\n' "$overview"
        printf '\n## Documentation decision\n\n**%s**\n' "$decision"
        printf '\n## Affected developers\n\n'
        jq -r '[.[].component] | unique | .[] | "- Developers integrating with the \(.) component"' <<<"$tickets_json"
        printf '\n## Related work\n\n### Trac tickets\n\n'
        jq -r '.[] | "- [#\(.id)](\(.url))"' <<<"$tickets_json"
        printf '\n### Pull requests\n\n- See the linked Trac tickets for associated pull requests.\n'
        printf '\n### Changesets\n\n- See the linked Trac tickets for committed changesets.\n'
        printf '\n## Suggested Dev Note coverage\n\n'
        case "$decision" in
            "Dev Note")
                printf '%s\n' '- New API or behavior' '- Code examples' '- Backward-compatibility considerations' '- Migration and integration guidance'
                ;;
            "Misc Dev Note")
                printf '%s\n' '- Summarize the related changes together' '- Link to relevant API references and examples' '- Note compatibility or integration considerations'
                ;;
            "Field Guide")
                printf '%s\n' '- Briefly list each developer-facing change' '- Link each item to its Trac ticket' '- Call out compatibility considerations where relevant'
                ;;
        esac
        printf '\n## Triage metadata\n\n'
        printf -- '- Components: %s\n' "$(jq -r '[.[].component] | unique | join(", ")' <<<"$tickets_json")"
        printf -- '- Trac types: %s\n' "$(jq -r '[.[].type] | unique | join(", ")' <<<"$tickets_json")"
        printf -- '- Ticket count: %s\n' "$(jq 'length' <<<"$tickets_json")"
    } > "$output_file"
}

project_field_value() {
    local item_id="$1"
    local field_name="$2"
    local value="$3"
    local project_id field_id data_type option_id

    project_id="$(jq -r '.id' "$PROJECT_DATA_FILE")"
    field_id="$(jq -r --arg name "$field_name" '.fields.nodes[] | select(.name == $name) | .id' "$PROJECT_DATA_FILE")"
    data_type="$(jq -r --arg name "$field_name" '.fields.nodes[] | select(.name == $name) | .dataType' "$PROJECT_DATA_FILE")"

    case "$data_type" in
        SINGLE_SELECT)
            option_id="$(jq -r --arg name "$field_name" --arg value "$value" '
                [.fields.nodes[] | select(.name == $name) | .options[] | select((.name|ascii_downcase) == ($value|ascii_downcase)) | .id][0] // ""
            ' "$PROJECT_DATA_FILE")"
            if [[ -z "$option_id" ]]; then
                printf 'Warning: project field %s has no option matching %s; field left unset.\n' "$field_name" "$value" >&2
                return 0
            fi
            gh project item-edit --id "$item_id" --project-id "$project_id" \
                --field-id "$field_id" --single-select-option-id "$option_id" >/dev/null
            ;;
        TEXT)
            gh project item-edit --id "$item_id" --project-id "$project_id" \
                --field-id "$field_id" --text "$value" >/dev/null
            ;;
        *)
            printf 'Warning: unsupported project field type %s for %s; field left unset.\n' "$data_type" "$field_name" >&2
            ;;
    esac
}

add_issue_to_project() {
    local issue_url="$1"
    local docs_type="$2"
    local component_value="$3"
    local item_id

    item_id="$(gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --url "$issue_url" --format json --jq '.id')"
    project_field_value "$item_id" "Docs Type" "$docs_type"
    project_field_value "$item_id" "Component" "$component_value"
}

create_or_reuse_issue() {
    local key="$1"
    local title="$2"
    local label="$3"
    local docs_type="$4"
    local component_value="$5"
    local tickets_json="$6"
    local assignee="${7:-}"
    local marker="wp71-issue-key:$key"
    local existing_url conflicts body_file issue_url

    existing_url="$(same_issue_url "$title" "$marker")"
    if [[ -n "$existing_url" ]]; then
        printf 'EXISTS %s %s\n' "$existing_url" "$title"
        if [[ "$EXECUTE" == true ]]; then
            add_issue_to_project "$existing_url" "$docs_type" "$component_value"
        fi
        return 0
    fi

    conflicts="$(ticket_conflicts_json "$tickets_json")"
    if [[ "$(jq 'length' <<<"$conflicts")" -gt 0 ]]; then
        if [[ "$(jq '[.[].ticket_id] | unique | length' <<<"$conflicts")" == "$(jq 'length' <<<"$tickets_json")" \
            && "$(jq '[.[].issue_url] | unique | length' <<<"$conflicts")" == "1" ]]; then
            existing_url="$(jq -r '.[0].issue_url' <<<"$conflicts")"
            printf 'EXISTS %s %s\n' "$existing_url" "$title"
            if [[ "$EXECUTE" == true ]]; then
                add_issue_to_project "$existing_url" "$docs_type" "$component_value"
            fi
            return 0
        fi
        printf 'CONFLICT %s\n%s\n' "$title" "$(jq -r '.[] | "  Trac #\(.ticket_id) already appears in \(.issue_url)"' <<<"$conflicts")" >&2
        return 1
    fi

    body_file="$(mktemp)"
    render_body "$body_file" "$marker" "$docs_type" "$title" "$tickets_json"

    if [[ "$EXECUTE" == false ]]; then
        printf 'WOULD CREATE %s [%s, %s]\n' "$title" "$RELEASE_LABEL" "$label"
        rm -f "$body_file"
        return 0
    fi

    local -a create_args=(
        issue create --repo "$REPOSITORY" --title "$title" --body-file "$body_file"
        --label "$RELEASE_LABEL" --label "$label"
    )
    [[ -z "$assignee" ]] || create_args+=(--assignee "$assignee")
    issue_url="$(gh "${create_args[@]}")"
    rm -f "$body_file"
    printf 'CREATED %s %s\n' "$issue_url" "$title"
    add_issue_to_project "$issue_url" "$docs_type" "$component_value"
}
