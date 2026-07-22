# Field Guide prep for 7.1 WordPress release

This document aims to explain the workflow behind [dev-related tickets](https://github.com/WordPress/Documentation-Issue-Tracker/issues?q=is%3Aissue%20label%3A7.1%20AND%20(label%3A%22dev-note%22%20OR%20label%3A%22misc-dev-note%22%20OR%20label%3A%22field-guide%22)) for 7.1 WordPress release.

## A bit of context

The Field Guide is a specific type of software documentation that addresses developer facing changes. It informs about new and modified functionality in a new software version, which can have impact on how developers extend, and build with and on top of the software.

WordPress release cycle includes publishing the [Field Guide](https://make.wordpress.org/core/tag/field-guide/) together with RC1 (Release candidate 1). This is the time when all changes in upcoming version are known, so developers are invited to test it against their WordPress installs, and report any bugs found, as well as mitigate all possible incompatibilities so that update can go as smooth as possible.

The Field Guide gathers all the Dev Notes for the release, other smaller changes that are not merit for a dedicated Dev note (e.g. external libraries updates, new hooks added etc.), as well as some stats, such as how many bugs are fixed, enhancements, pull requests etc.

## A bit of history

WordPress core development happens in Trac. The number of [tickets per release](https://core.trac.wordpress.org/query?milestone=7.1&order=priority&col=id&col=summary&col=status&col=owner&col=type&col=priority&col=milestone) go anywhere between 200 and 400. Gutenberg plugin development happens in [GitHub](https://github.com/WordPress/gutenberg). Usually, around 10 Gutenberg plugin releases get [merged into core via Trac](https://core.trac.wordpress.org/query?milestone=7.1&summary=~Sync+changes+from+Gutenberg&group=component&order=priority&col=id&col=summary&col=type&col=milestone&col=owner&col=status&col=priority).

Triaging all of the tickets in order to determine which ticket should be mentioned in the Field Guide, and in which capacity, is a tedious work that takes a lot of manual effort, as well as brain power and understanding which change is valuable information for developers.

### The work

Publishing Field Guide consists of following:

- Triaging [fixed Trac tickets for the milestone](https://core.trac.wordpress.org/query?component=!Build%2FTest+Tools&component=!Bundled+Theme&component=!WordPress.org+Site&focuses=!tests&milestone=7.1&resolution=fixed&type=!&group=component&max=300&order=priority&col=id&col=summary&col=type&col=focuses&col=owner&col=time&col=changetime&col=keywords) to determine which ticket needs to be:
    - a dedicated Dev note,
    - a part of misc Dev note,
    - just mentioned in the Field Guide, or
    - none of the above.
- Adding all selected tickets to some kind of project management tool. It used to be Google Spreadsheet, but the Documentation team worked through 10 releases to develop a workflow that uses [GitHub Projects](https://github.com/orgs/WordPress/projects/295/).
- Communicating with developers who worked on the code in selected tickets, to gather all the Dev notes. Most of the times, developers write the Dev note as well. But, sometimes that's not the case, especially for Misc dev notes. If no one volunteers to take over, the person who is publishing the Field Guide, is responsible for writing missing Dev notes.
- Gathering all the release stats and published Dev notes, and writing the Field Guide.
- Publishing the Field Guide when RC1 is released; and updating it with newly published Dev notes, if those happen. Technically, _ALL_ Dev notes should be published _before_ the Field Guide but, a couple of late ones happen here and there.

This whole work can take two full weeks of manual labor for one person. And it's not sustainable for an average volunteer.

## The change in 7.1 release cycle

The WordPress Documentation team has been discussing different ways of using AI to help with processes and workflows, and to minimise unnecessary manual work by humans. New AI tools are being developed and published every day, and we wanted to include some in the release documentation workflows, as those represent the most time pressured contributions to the WordPress docs.

The idea was to develop AI Agent SKILLs and GitHub workflows which will enable almost any documentation contributor to prepare and publish release Field Guide. Triaging tickets and creating GitHub issues are two processes we wanted to automate and delegate the most.

However, at this moment of time, this idea is not quite possible.

### Authentication

Every step of this workflow needs some kind of user authentication, which makes it very difficult to "open-source" the process.

Querying Trac tickets by AI to collect the raw data and reviewing tickets to classify the docs type, is impossible without user authentication and with free tools. GitHub Copilot can not access Trac at all. Paid tier of ChatGPT can, but it's a paid tier.

The idea was split into several steps and querying Trac tickets was separated from reviewing and classifying them.

Querying Trac can be successfully (but not without limits) done with [MCP Context WPORG](https://github.com/Automattic/mcp-context-wporg/) by Automattic. While `make` and `github` providers can be used out of the box, `trac` "requires WordPress.org auth for bot-like traffic". That means I need to provide my core.trac.wordpress.org cookie (and providing cookies I know :cookie:). So this was done in my local.

Reviewing raw data and classifying tickets (Dev note, Misc dev note, Field guide, exclude) was best done by Codex (I used VSC extension), but it needed my OpenAI API key or ChatGPT paid tier. This, too, was done in my local for obvious reasons.

Once I had all the data I needed for creating GitHub issues and adding them to GitHub project, I was ready to use GitHub's Copilot. As Copilot didn't behave well with any of previous tasks, I decided to use good old CLI and finish this for free. Doing this from my local required GitHub user authentication, so I created a new classic Token with specific set of permissions.

## The workflow

1. [MCP Context WPORG](https://github.com/Automattic/mcp-context-wporg/) to collect all the Trac tickets, grouped by [components](./components/).
2. [Codex for VSC](https://marketplace.visualstudio.com/items?itemName=openai.chatgpt):
    - populated [release-metadata.json](./release-metadata.json) based on raw data in `components/*.json` files,
    - analyzed `components/*.json` files and categorised tickets per docs type (`Dev note`, `Misc dev note`, and `Field guide`), and
    - built bash scripts for creating GitHub issues via GitHub CLI tool.
3. [GitHub CLI](https://cli.github.com/):
    - created GitHub issues inside [WordPress/Documentation-Issue-Tracker](https://github.com/WordPress/Documentation-Issue-Tracker/issues?q=is%3Aissue%20label%3A7.1%20AND%20(label%3A%22dev-note%22%20OR%20label%3A%22misc-dev-note%22%20OR%20label%3A%22field-guide%22)),
    - applied issue template as defined in [issue-template.md](./issue-template.md),
    - applied 7.1 and appropriate docs type labels (`Dev note`, `Misc dev note`, and `Field guide`),
    - added issues to [WordPress 7.1 Documentation](https://github.com/orgs/WordPress/projects/295),
    - applied project's custom fields to issues (`Docs type` and `Component`), and
    - assigned [Field guide issue](https://github.com/WordPress/Documentation-Issue-Tracker/issues/2430) to my GitHub account (@zzap).
4. [Codex for VSC](https://marketplace.visualstudio.com/items?itemName=openai.chatgpt) updated metadata stats and [activity-log.jsonl](./activity-log.jsonl)

### Relevant PRs

- Add tickets per components files [#2399](https://github.com/WordPress/Documentation-Issue-Tracker/pull/2399)
- Add metadata schema [#2400](https://github.com/WordPress/Documentation-Issue-Tracker/pull/2400)
- Update release metadata SKILL to match new file structure [#2401](https://github.com/WordPress/Documentation-Issue-Tracker/pull/2401)
- Update SKILL to allow underscore in component file name [#2404](https://github.com/WordPress/Documentation-Issue-Tracker/pull/2404) and [#2405](https://github.com/WordPress/Documentation-Issue-Tracker/pull/2405)
- Populate release-metadata.json, classify tickets, and create bash scripts for creating issues [#2406](https://github.com/WordPress/Documentation-Issue-Tracker/pull/2406)