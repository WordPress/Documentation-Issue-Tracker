---
name: wp-71-dev-note-issues
description: Create missing WordPress 7.1 Dev Note and Field Guide tracking issues from 7-1-dev-notes/tickets.json in WordPress/Documentation-Issue-Tracker. Use when asked to import, sync, or create GitHub issues for triaged WordPress 7.1 Trac tickets.
---

# WordPress 7.1 documentation issue importer

Use this skill only in the `WordPress/Documentation-Issue-Tracker` repository.

## Source files

Read:

- `7-1-dev-notes/tickets.json`
- `7-1-dev-notes/issue-template.md`
- `7-1-dev-notes/activity-log.jsonl`

Treat `tickets.json` as the source of truth. Do not reclassify tickets and do not rewrite its summaries.

## Eligible tickets

Create GitHub issues only for tickets whose `classification` is exactly one of:

- `dev-note`
- `misc-dev-note`
- `field-guide`

Never create an issue for:

- `exclude`
- a missing or unknown classification
- a ticket whose `create_issue` value is explicitly `false`

If `create_issue` conflicts with `classification`, stop and report the conflicting ticket instead of guessing.

## Authentication and repository checks

Before doing anything:

1. Confirm the current repository is `WordPress/Documentation-Issue-Tracker`.
2. Confirm GitHub CLI is authenticated with `gh auth status`.
3. Confirm these repository labels exist:
   - `7.1`
   - `dev-note`
   - `misc-dev-note`
   - `field-guide`
4. Do not create, rename, or delete labels automatically.
5. If any required label is missing, stop before creating issues and report it.

## Find existing issues

Load all open and closed issues in `WordPress/Documentation-Issue-Tracker` carrying the `7.1` label.

Use a command equivalent to:

```bash
gh issue list \
  --repo WordPress/Documentation-Issue-Tracker \
  --state all \
  --label "7.1" \
  --limit 1000 \
  --json number,title,body,url,labels
```

For every eligible Trac ticket, consider an existing GitHub issue a match when any of the following is true:

1. Its title contains the exact token `#<Trac-ID>` and begins with `[7.1]`.
2. Its body contains the exact Trac URL from `trac_url`.
3. Its body contains a clearly identified Trac reference in the form `#<Trac-ID>`.

Match the Trac ID as a complete number. For example, ticket `#123` must not match `#1234`.

Search both open and closed issues. A closed matching issue still counts as an existing issue.

If more than one existing issue matches the same Trac ticket:

- do not create another issue;
- record the ticket as a duplicate conflict;
- report all matching GitHub issue numbers and URLs.

Do not reopen or edit existing issues unless the user explicitly requests that separately.

## Create missing issues

For each eligible ticket without a matching GitHub issue:

### Title

Use this exact format:

```text
[7.1] #<Trac-ID> <Trac title>
```

Example:

```text
[7.1] #65164 Responsive styles for blocks
```

Use the `ticket` and `title` values from `tickets.json` without paraphrasing the Trac title.

### Body

Use `7-1-dev-notes/issue-template.md` as the body template.

Populate the template only from fields present in the ticket object. Common fields include:

- `ticket`
- `title`
- `trac_url`
- `summary`
- `classification`
- `documentation_rationale`
- `component`
- `type`
- `focuses`
- `keywords`
- `affected_audience`
- `related_trac_tickets`
- `github_pull_requests`
- `changesets`
- `confidence`

When replacing template placeholders:

- support placeholders written as `{{field_name}}`;
- render arrays as Markdown bullet lists;
- render an empty array as `None identified`;
- preserve URLs exactly;
- do not invent missing relationships, pull requests, changesets, audiences, or explanations;
- if a required placeholder cannot be populated, stop for that ticket and report the missing field;
- ensure no unresolved `{{...}}` placeholders remain before issue creation.

Write the rendered body to a temporary file and pass it with `--body-file`. Do not modify `issue-template.md`.

### Labels

Apply exactly:

- `7.1`
- the ticket's classification label:
  - `dev-note`
  - `misc-dev-note`
  - `field-guide`

Do not apply `exclude`.

Create the issue with a command equivalent to:

```bash
gh issue create \
  --repo WordPress/Documentation-Issue-Tracker \
  --title "$title" \
  --body-file "$body_file" \
  --label "7.1" \
  --label "$classification"
```

Process tickets one at a time. Continue after an individual failure, but collect every failure for the final report.

## Dry run

When the user requests a dry run:

- do all validation and duplicate checks;
- render and validate proposed titles, bodies, and labels;
- do not create or modify GitHub issues;
- do not append to `activity-log.jsonl`;
- report what would be created, skipped, or blocked.

Never infer that a real import is authorized from a request to inspect, preview, validate, or dry-run the data.

## Activity log

After a real import, append one JSON object as a single new line to:

`7-1-dev-notes/activity-log.jsonl`

Never overwrite previous lines.

Include:

- `event`: `github_issue_import`
- `tickets_json_updated_at`: value from `tickets.json` metadata
- `import_run_at`: current ISO 8601 datetime
- `tickets_total`: total tickets in `tickets.json`
- `eligible_tickets`: number with an issue-creating classification
- `github_issues_created`
- `created_issue_ticket_ids`
- `created_issue_numbers`
- `created_issue_urls`
- `tickets_skipped_by_classification`
- `classification_skipped_ticket_ids`
- `existing_github_issues_skipped`
- `existing_issue_ticket_ids`
- `existing_issue_numbers`
- `duplicate_conflicts`
- `duplicate_conflict_ticket_ids`
- `failed`
- `failed_ticket_ids`

Use ticket IDs as numbers, not strings.

Do not count `exclude` tickets as existing-issue skips. They belong only in `tickets_skipped_by_classification`.

## Final report

At the end, report:

- eligible tickets checked;
- issues created;
- tickets skipped because a matching issue already existed;
- tickets skipped because of classification;
- duplicate conflicts;
- failures;
- created issue URLs.

If nothing was created, say so explicitly.

## Safety and integrity rules

- Never create an issue before completing the duplicate search.
- Never create issues in another repository.
- Never use the `7.0` label; this workflow is for WordPress `7.1`.
- Never alter ticket classifications.
- Never delete, close, reopen, or edit existing issues as part of this skill.
- Never fabricate issue body content.
- Never write an import log entry during a dry run.
