# X Sync

Chrome extension that adds a `Sync` button to X/Twitter posts and sends the post's outbound link to the protected bookmark endpoint in `personal-blog`.

## Behavior

- If a post contains an outbound link, that link is submitted.
- If no outbound link exists, the post URL is submitted instead.
- `t.co` links are resolved server-side by `personal-blog` before the bookmark is stored.
- The write key is never bundled into the extension. You add it through the popup UI.

## Build

```bash
npm install
npm run build
```

The unpacked extension output is written to `dist/`.

## Load In Chrome

1. Open `chrome://extensions`.
2. Enable Developer Mode.
3. Click `Load unpacked`.
4. Select `extensions/x-sync/dist`.

## Configure

1. Click the extension icon.
2. Pick `DEV` or `PROD` as the active environment.
3. Set the `Action URL (Convex Site)` for that environment.
4. Paste the matching `Studio Write Key`.
5. Save settings.

The popup also supports a connection check against `/studio/overview` before you start syncing.
