---
name: wp-71-release-metadata
description: Fetch the WordPress 7.1 filtered Core Trac query and create or update release-metadata.json as the authoritative component index and cumulative triage statistics file. Use when initializing, refreshing, validating, or reconciling WordPress 7.1 Dev Notes release metadata.
---

# WordPress 7.1 release metadata

Use this skill in the `WordPress/Documentation-Issue-Tracker` repository.

The authoritative metadata file is:

```text
7-1-dev-notes/release-metadata.json
```

The authoritative Trac query is:

```text
https://core.trac.wordpress.org/query?focuses=!tests&milestone=7.1&status=closed&type=!defect+(bug)&group=component&max=200&order=priority&col=id&col=summary&col=type&col=status&col=focuses&col=keywords
```

## Purpose

Fetch the complete live query result, derive reliable release-level and component-level metadata, and create or update `release-metadata.json`.

This file is the source of truth for all later ticket-review and GitHub-issue workflows.

Accuracy is more important than completing the task. If the query cannot be fully fetched or the counts do not reconcile, do not modify `release-metadata.json`.

## Immutable schema

The JSON schema and key names below are fixed.

Never:

- rename a key;
- remove a key;
- add a key;
- move a key;
- change an object to an array or an array to an object;
- change a number to a string;
- change the order or meaning of classification names;
- add temporary status, error, note, or diagnostic fields;
- store individual Trac tickets in this file.

The file must always use exactly this structure:

```json
{
  "metadata": {
    "release": "7.1",
    "schema_version": 2,
    "updated_at": "ISO-8601 datetime with timezone",
    "source_query": "authoritative query URL",
    "filtering": {
      "excluded_types": [
        "defect (bug)"
      ],
      "excluded_focuses": [
        "tests"
      ]
    }
  },
  "components": [
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
        "field-guide": 0
      }
    }
  ],
  "statistics": {
    "tickets_total_count_in_query": 0,
    "tickets_indexed_in_component_files": 0,
    "tickets_reviewed": 0,
    "tickets_pending_review": 0,
    "components_total": 0,
    "components_completed": 0,
    "components_not_started": 0,
    "by_classification": {
      "dev-note": 0,
      "misc-dev-note": 0,
      "field-guide": 0
    },
    "by_type": {
      "enhancement": 0,
      "feature request": 0,
      "task (blessed)": 0
    },
    "github_issue_candidates": 0,
    "github_issues_created_count": 0
  }
}
```

## Fetch the complete query

Fetch the authoritative query URL exactly as stored above.

Do not remove, alter, reinterpret, or duplicate its filters.

The live result must exclude:

- tickets whose type is `defect (bug)`;
- tickets whose `focuses` field contains `tests`;
- tickets not in milestone `7.1`;
- tickets whose current status is not `closed`.

Do not infer the result from an older local file, a previous run, search-engine snippets, cached counts, or manually assembled component totals.

Obtain every result row from the live query.

If Trac pagination, HTML rendering, or a transient response prevents obtaining all rows:

1. try the query's CSV, tab-separated, or other machine-readable export;
2. retry the live endpoint conservatively;
3. use the query's reported total to verify completeness;
4. stop without modifying the file if completeness still cannot be proven.

Do not fabricate, estimate, or manually adjust missing counts.

## Parse each query row

For every result, collect:

- ticket ID;
- component;
- type;
- focuses.

The ticket ID is needed only to verify uniqueness and totals. Do not write ticket IDs to `release-metadata.json`.

Normalize only for comparison:

- trim surrounding whitespace;
- treat an empty component as an error;
- preserve the official Trac component display name in `components[].name`;
- preserve the official Trac type value when counting types.

Reject duplicate ticket IDs. A ticket must be counted exactly once.

## Component slugs

Create deterministic lowercase slugs from Trac component names:

1. convert to lowercase;
2. replace `&` with `and`;
3. replace `/` with `-`;
4. replace spaces and other non-alphanumeric separators with one hyphen;
5. collapse repeated hyphens;
6. remove leading and trailing hyphens.

Examples:

```text
Abilities API        -> abilities-api
Build/Test Tools     -> build-test-tools
Networks and Sites   -> networks-and-sites
Pings/Trackbacks     -> pings-trackbacks
Role/Capability      -> role-capability
```

A component's file path must be:

```text
components/<slug>.json
```

Sort `components` alphabetically by `name`, using case-insensitive comparison.

## First run

A first run occurs when `7-1-dev-notes/release-metadata.json` does not exist or is empty.

For every component in the live query, create one component entry:

```json
{
  "name": "Official Trac component name",
  "slug": "derived-slug",
  "file": "components/derived-slug.json",
  "ticket_count": 0,
  "reviewed_count": 0,
  "status": "not_started",
  "issue_candidates": 0,
  "issues_created_count": 0,
  "statistics": {
    "dev-note": 0,
    "misc-dev-note": 0,
    "field-guide": 0
  }
}
```

Set `ticket_count` to the number of live query tickets in that component.

On the first run, always set:

- `reviewed_count` to `0`;
- `status` to `not_started`;
- `issue_candidates` to `0`;
- `issues_created_count` to `0`;
- every component classification statistic to `0`;
- `tickets_indexed_in_component_files` to `0`;
- `tickets_reviewed` to `0`;
- `tickets_pending_review` to the full query count;
- `components_completed` to `0`;
- `components_not_started` to the number of components;
- every global classification statistic to `0`;
- `github_issue_candidates` to `0`.

## Later runs

On later runs, first read and validate the existing `release-metadata.json`.

Preserve these reviewed values for a component already present:

- `reviewed_count`;
- `status`;
- `issue_candidates`;
- `issues_created_count`;
- `statistics.dev-note`;
- `statistics.misc-dev-note`;
- `statistics.field-guide`.

Refresh from the live query:

- the component list;
- component `ticket_count`;
- component display name, slug, and file path;
- overall query count;
- type totals;
- `updated_at`.

When a new component appears:

- add it with zeroed review values and `status: not_started`;
- set `issues_created_count` to `0`.

The metadata refresh workflow must never infer `issues_created_count` from Trac data. Preserve the existing value for known components. Only the GitHub issue-management workflow may change it.

When a component disappears from the query:

- remove it only if its `reviewed_count`, `issue_candidates`, and all three classification statistics are zero;
- otherwise stop without modifying the file and report the conflict.

When a component's live `ticket_count` becomes lower than its stored `reviewed_count`:

- stop without modifying the file;
- report the component and both counts;
- do not silently reduce `reviewed_count`.

Do not infer that a removed or reopened ticket should erase prior triage work. That requires a separate reconciliation workflow.

## Status values

This metadata skill does not invent or change reviewed component statuses except on the first appearance of a component.

For new components, use:

```text
not_started
```

On later runs, preserve the existing `status` value exactly.

Other workflows may set statuses such as `in_progress`, `complete`, or another repository-approved value. This skill must not normalize or rewrite them.

## Calculate global statistics

Calculate:

### Query totals

```text
statistics.tickets_total_count_in_query
```

The number of unique tickets returned by the complete live filtered query.

```text
statistics.components_total
```

The number of unique components in the live query.

### Type totals

Count all live query tickets by exact Trac type into:

- `enhancement`;
- `feature request`;
- `task (blessed)`.

No other type is permitted by this filtered workflow.

If another type appears:

- stop without modifying the file;
- report the unexpected type and affected ticket IDs.

The three type totals must sum to `tickets_total_count_in_query`.

### Cumulative review totals

Calculate these exclusively from component entries:

```text
tickets_indexed_in_component_files
```

Sum of `reviewed_count` across all components.

```text
tickets_reviewed
```

Also the sum of `reviewed_count` across all components.

These two values must remain equal.

```text
tickets_pending_review
```

`tickets_total_count_in_query - tickets_reviewed`

This value must never be negative.

```text
components_completed
```

Number of components whose `status` is exactly `complete`.

```text
components_not_started
```

Number of components whose `status` is exactly `not_started`.

Do not add a `components_in_progress` field. It is not part of the schema.

### Classification totals

Calculate global classification totals by summing the corresponding values from every component:

- `statistics.dev-note`;
- `statistics.misc-dev-note`;
- `statistics.field-guide`.

Set:

```text
statistics.github_issue_candidates
```

to the sum of all component `issue_candidates` values.

Set:

```text
statistics.github_issues_created_count
```

to the sum of all component `issues_created_count` values.

`issues_created_count` represents the number of GitHub issues that already exist for that component's triaged tickets. This skill does not discover, create, close, or modify GitHub issues. It only preserves component-level values already recorded by the issue-management workflow and recalculates the release-level total.

For every component, validate:

```text
issue_candidates =
statistics.dev-note +
statistics.misc-dev-note +
statistics.field-guide
```

If this does not hold, stop without modifying the file and report the component.

## Required reconciliation checks

Before writing the file, verify all of the following:

1. Every ticket ID is unique.
2. The number of parsed unique ticket IDs equals the query's reported total.
3. The sum of all component `ticket_count` values equals `tickets_total_count_in_query`.
4. The sum of `enhancement`, `feature request`, and `task (blessed)` equals `tickets_total_count_in_query`.
5. `tickets_indexed_in_component_files` equals `tickets_reviewed`.
6. `tickets_pending_review` equals `tickets_total_count_in_query - tickets_reviewed`.
7. `tickets_pending_review` is not negative.
8. No component has `reviewed_count > ticket_count`.
9. Every component slug is unique.
10. Every component file path is unique.
11. Every component's `issue_candidates` equals the sum of its three classification statistics.
12. The global `github_issue_candidates` equals the sum of component `issue_candidates`.
13. Every component `issues_created_count` is a non-negative integer.
14. No component has `issues_created_count > issue_candidates`.
15. The global `github_issues_created_count` equals the sum of component `issues_created_count`.
16. No global count has `github_issues_created_count > github_issue_candidates`.
17. Every key and nesting level exactly matches the immutable schema.
18. No extra keys exist anywhere in the file.

If any check fails:

- do not modify `release-metadata.json`;
- do not partially write the file;
- report every failed check with actual values.

## Pull request workflow

Build and validate the complete new JSON document in memory first.

Never commit directly to the repository's default branch.

After all fetch, schema, and reconciliation checks pass:

1. confirm the working tree is clean before making changes;
2. create a new branch from the current default branch;
3. use a branch name in this format:

   ```text
   update/wp-71-release-metadata-YYYY-MM-DD
   ```

4. write the validated document to:

   ```text
   7-1-dev-notes/release-metadata.json
   ```

5. parse the written file again as JSON;
6. re-run all schema and reconciliation checks against the on-disk file;
7. inspect the Git diff and confirm that:
   - only `7-1-dev-notes/release-metadata.json` changed;
   - the immutable schema was not modified;
   - no unrelated formatting or repository changes were introduced;
8. commit the change with this commit-message format:

   ```text
   Update WordPress 7.1 release metadata
   ```

9. push the branch to the repository;
10. open a pull request against the default branch.

Use this pull-request title:

```text
Update WordPress 7.1 release metadata
```

Use a pull-request body that reports:

- the authoritative Trac query;
- whether the run initialized or refreshed the file;
- total tickets in the filtered query;
- total components;
- totals by ticket type;
- new or removed components;
- components whose ticket counts changed;
- preserved reviewed-ticket count;
- pending-review count;
- total GitHub issue candidates;
- total GitHub issues already created;
- confirmation that all schema and reconciliation checks passed.

Do not merge the pull request.

If the branch name already exists, append a short unique suffix rather than overwriting or force-pushing another run.

If validation fails at any point:

- do not commit;
- do not push;
- do not open a pull request;
- restore `release-metadata.json` to its previous state if it was written;
- report every failed check.

Format the JSON with:

- UTF-8;
- two-space indentation;
- one trailing newline;
- JSON booleans and numbers, not string equivalents.

Set `metadata.updated_at` to the actual run time in ISO 8601 format with an explicit timezone offset.

Do not update `activity-log.jsonl` as part of this skill.

## Final report

After a successful run, report:

- whether this was the first run or an update;
- total tickets in the filtered query;
- total components;
- totals by type;
- new components;
- removed components;
- components whose ticket count changed;
- preserved reviewed ticket count;
- pending review count;
- path to the updated file;
- confirmation that all reconciliation checks passed.

After a failed run, report:

- that `release-metadata.json` was not modified;
- the exact fetch, schema, or reconciliation failures;
- any component or ticket IDs involved.

Never claim success unless the final on-disk file has been parsed and validated.
