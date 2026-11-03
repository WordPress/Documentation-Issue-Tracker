# Block screenshots for HelpHub

Retakes the screenshots of a HelpHub block article (for example the [Post Comments Form block](https://wordpress.org/documentation/article/post-comments-form-block/)) in a throwaway [WordPress Playground](https://wordpress.org/playground/) instance. No local WordPress, database, or AI tokens are needed: it is a plain [Playwright](https://playwright.dev/) script.

Each run:

1. Starts a fresh WordPress (latest by default) with Playground CLI and a generated Blueprint that activates the theme and creates two posts containing the block (comments open and closed).
2. Opens the block editor, selects the block through the `core/block-editor` data store, and opens the real UI for each shot (inserter, block switcher, alignment and options menus).
3. Saves cropped screenshots at 2× resolution, framed around the toolbar and the open menu.

## Run it

With Docker (nothing else to install):

```sh
docker run --rm -v "$PWD:/work" -w /work mcr.microsoft.com/playwright:v1.49.1-jammy \
	sh -c "npm install && node capture.mjs examples/post-comments-form.json"
```

Or with Node.js 20+:

```sh
npm install
npx playwright install chromium
node capture.mjs examples/post-comments-form.json
```

Screenshots are written to `out/<config name>/`. A run takes about 3 minutes, most of it Playground downloading and installing WordPress.

## Config

One JSON file per article; see [`examples/post-comments-form.json`](examples/post-comments-form.json).

| Key | Meaning |
|---|---|
| `article`, `issue` | Links for reference only |
| `wp` | WordPress version for Playground (`latest`, `beta`, `nightly`, or e.g. `6.8`) |
| `theme` | Theme folder to activate (default `twentytwentyfive`) |
| `block` | Block name to select, e.g. `core/post-comments-form` |
| `search` | Text typed in the inserter search |
| `content` | Serialized block markup for the sample post |
| `shots` | Which screenshots to take, in order (see below) |

Available shots: `block`, `inserter`, `toolbar`, `transform`, `movers`, `align`, `options`, `comments-closed`.

Tip: put a Spacer block before the target block in `content`, so the floating toolbar does not overlap other text.

## Ideas for next steps

- A before/after view an editor can open inside the same Playground instance to review what changed.
- Checking the new screenshots and text against what the issue asked for.
