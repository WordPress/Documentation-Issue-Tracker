---
name: wp-71-release-metadata
description: Populate or refresh 7-1-dev-notes/release-metadata.json from every JSON file in 7-1-dev-notes/components/ and validate it against release-metadata.schema.json. Use when asked to build, update, synchronize, reconcile, or validate WordPress 7.1 release metadata from the local component files.
---

# Populate WordPress 7.1 release metadata

Work only from repository files. Do not fetch Trac or GitHub data for this task.

## Files

Read:

- `7-1-dev-notes/components/*.json`
- `7-1-dev-notes/release-metadata.schema.json`
- the existing `7-1-dev-notes/release-metadata.json`, when it is non-empty and valid JSON

Write only:

- `7-1-dev-notes/release-metadata.json`

Treat the schema as authoritative. Never modify it to make generated data pass.

## Safety

Before writing, parse every component file and build the complete output in memory or in a temporary file. If any source, reconciliation, or schema check fails, leave `release-metadata.json` unchanged and report all failures.

Do not modify component files, classify tickets, invent review data, or infer whether a GitHub issue exists.

## Read component files

Support both repository component formats.

### Raw query export

A raw file contains top-level `count` and `tickets` fields. Require:

- `tickets` to be an array;
- `count` to be a non-negative integer equal to `tickets.length`;
- every ticket to have a unique integer `id`, a non-empty `component`, and a schema-supported `type`.

When no tickets in a raw file have `classification`, derive:

- component name from the single unique `tickets[].component` value;
- `ticket_count` from `tickets.length`;
- `reviewed_count: 0`;
- `status: "not_started"`;
- `issue_candidates: 0`;
- all four classification counts as `0`.

When tickets are classified, require every ticket in the file to have exactly one of `dev-note`, `misc-dev-note`, `field-guide`, or `exclude`; do not accept a partially classified file. Require `create_issue: false` for `exclude` and `create_issue: true` for the other three classifications. Derive:

- `reviewed_count` from the number of classified tickets, including exclusions;
- `status: "complete"` when all tickets are classified;
- all four classification counts from the tickets;
- `issue_candidates` from `dev-note + misc-dev-note + field-guide`, excluding `exclude`.

If a raw file has no tickets, require a usable component name in its metadata; otherwise stop because the display name cannot be derived safely.

### Reviewed component file

A reviewed file contains top-level `metadata` and `tickets` fields. Read:

- name from `metadata.component`;
- ticket count from `metadata.ticket_count` and verify it equals `tickets.length`;
- reviewed count from `metadata.reviewed_count`;
- status from `metadata.status`;
- classification counts from `metadata.statistics.by_classification` for `dev-note`, `misc-dev-note`, `field-guide`, and `exclude`;
- issue candidates from `metadata.statistics.issue_candidates`.

Require all counts to be non-negative integers. Require `reviewed_count <= ticket_count`. Require status to be one of `not_started`, `in_progress`, or `complete`. Require:

```text
issue_candidates = dev-note + misc-dev-note + field-guide
```

Record `exclude` in component and release classification statistics, but never include it in `issue_candidates`.

For either format, require every ticket in a file to identify the same component. Use `id` as the ticket identifier in raw exports and `ticket` in reviewed files. Require integer identifiers and reject duplicates within or across files.

## Create component entries

Derive the slug from the component filename by removing `.json`. Allow lowercase letters, numbers, hyphens, and underscores: `^[a-z0-9]+(?:[-_][a-z0-9]+)*$`.

Create exactly one entry per component file:

```json
{
  "name": "Component display name",
  "slug": "component-slug",
  "file": "components/component-slug.json",
  "ticket_count": 0,
  "reviewed_count": 0,
  "status": "not_started",
  "issue_candidates": 0,
  "issues_created_count": 0,
  "statistics": {
    "dev-note": 0,
    "misc-dev-note": 0,
    "field-guide": 0,
    "exclude": 0
  }
}
```

When populating metadata:

- derive slug from the filename by removing .json;
- preserve underscores and hyphens exactly as they appear in the filename;
- derive file as components/<original-filename>;
- read the human-readable component name from the component file;
- do not generate the display name by mechanically replacing separators;
- require each slug and file path to be unique;
- do not rename component files as part of metadata generation.

Set `file` relative to `7-1-dev-notes/`, not the repository root. Sort entries by `name` using case-insensitive comparison. Reject duplicate names, slugs, or file paths.

Derive `issues_created_count` from the number of distinct `github_issue_number` values on that component's tickets. Require `github_issue_number` and `github_issue_url` to appear together, require the number to be a positive integer, and require the URL to identify that number in `WordPress/Documentation-Issue-Tracker`. Excluded tickets must not have GitHub issue fields. Never discover issue data from ticket prose.

## Populate release metadata

Set `metadata` as follows:

- `release`: `"7.1"`
- `schema_version`: `2`
- `updated_at`: the actual write time as an ISO 8601 date-time with an explicit timezone offset
- `source_query`: preserve it from an existing valid target; otherwise use the common non-empty `metadata.source_query` from reviewed component files; if neither exists, use the repository's canonical query below
- `filtering.excluded_components`: `["Build/Test Tools", "Bundled Theme", "WordPress.org Site"]`
- `filtering.excluded_focuses`: `["tests"]`
- `filtering.resolution`: `["fixed"]`
- `filtering.excluded_types`: `[]`

```text
https://core.trac.wordpress.org/query?component=!Build%2FTest+Tools&component=!Bundled+Theme&component=!WordPress.org+Site&focuses=!tests&milestone=7.1&resolution=fixed&type=!&group=component&max=300&order=priority&col=id&col=summary&col=type&col=focuses&col=owner&col=time&col=changetime&col=keywords
```

If reviewed component files contain conflicting source queries, stop and report them. Do not fetch the query; it is provenance metadata only.

Calculate release statistics from the component entries and their tickets:

- `tickets_total_count_in_query`: sum of component `ticket_count`
- `tickets_indexed_in_component_files`: sum of component `reviewed_count`
- `tickets_reviewed`: sum of component `reviewed_count`
- `tickets_pending_review`: total tickets minus reviewed tickets
- `components_total`: number of component entries
- `components_completed`: count whose status is `complete`
- `components_not_started`: count whose status is `not_started`
- `by_classification`: sum each of the four component classification counts, including `exclude`
- `by_type`: count every ticket by its exact `type`
- `github_issue_candidates`: sum of component `issue_candidates`
- `github_issues_created_count`: number of distinct `github_issue_number` values across all component tickets

A grouped issue may cover tickets in multiple components. Count it once in each affected component's `issues_created_count`, but only once in the release-level `github_issues_created_count`. Therefore, the release count is not required to equal the sum of component counts.

Accept any non-empty set of ticket type keys in `by_type`. Every key must map to a non-negative integer.

## Reconcile and validate

Before replacing the target, verify:

1. Every source file was included exactly once.
2. Every source `count` or `metadata.ticket_count` equals its ticket array length.
3. All ticket IDs are globally unique.
4. The component ticket-count sum equals `tickets_total_count_in_query`.
5. The three type counts sum to `tickets_total_count_in_query`.
6. `tickets_indexed_in_component_files` equals `tickets_reviewed`.
7. Pending tickets equal total minus reviewed and are not negative.
8. No component has more reviewed tickets than tickets.
9. Every component's issue candidates equal its `dev-note`, `misc-dev-note`, and `field-guide` counts; `exclude` is not an issue candidate.
10. Global classification totals equal their component sums.
11. Every component's created count equals its distinct referenced issues and does not exceed its candidate count.
12. The global created count equals the number of distinct referenced issues across all tickets and does not exceed global candidates.
13. Names, slugs, and file paths are unique.

Validate the complete document against `7-1-dev-notes/release-metadata.schema.json` with a JSON Schema Draft 2020-12 validator. Enable format validation so `date-time` and URI formats are checked. Do not claim schema validation based only on parsing JSON. If no compatible validator is available, stop without writing and report that validation could not be completed.

## Write and verify

After every check passes:

1. Format JSON with UTF-8, two-space indentation, and one trailing newline.
2. Atomically replace `7-1-dev-notes/release-metadata.json` from the validated temporary file.
3. Parse and schema-validate the on-disk file again.
4. Re-run reconciliation checks against the on-disk data.
5. Inspect the diff and confirm no file other than `release-metadata.json` changed as a result of this task.

Do not commit, push, create a branch, or open a pull request unless the user explicitly requests it.

## Report

Report the target path, component count, ticket total, reviewed and pending totals, type totals, classification totals, issue candidate and created counts, and confirmation that the final on-disk file passed schema and reconciliation validation. On failure, state that the target was not modified and list the exact files and checks involved.
