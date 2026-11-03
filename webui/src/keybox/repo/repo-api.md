# Keybox Repository · Iframe Integration API

Connect a self-hosted repository to TrickyAddon's settings page through `postMessage`. The protocol covers handshake, download and error responses.

## Protocol

### 1. Handshake

When your site is loaded inside the iframe, Tricky Addon starts sending this message repeatedly every 500ms:

```
Parent → Your Iframe
{ "type": "handshake" }
```

Reply once to establish the channel:

```
Your Iframe → Parent
{ "type": "handshake_ack" }
```

Capture `event.origin` from the handshake and use that origin as `targetOrigin` for outgoing messages.

### 2. Download

When a user picks a keybox in iframe mode, send the download URL to the parent:

```
Your Iframe → Parent
{ "type": "download", "url": "<absolute URL to the keybox content>" }
```

| Field  | Type     | Description                                  |
|--------|----------|----------------------------------------------|
| `type` | `string` | Always `"download"`                          |
| `url`  | `string` | Absolute URL your backend serves the keybox from |

Tricky Addon fetches this URL and sets the response body as the active keybox.

### 3. Error

Send an error response when a download fails:

```
Your Iframe → Parent
{ "type": "error", "error": "<code>", "identity": "<identity>" }
```

| Field      | Type     | Description                            |
|------------|----------|----------------------------------------|
| `type`     | `string` | Always `"error"`                       |
| `error`    | `string` | Error code (convention: `"download_failed"`) |
| `identity` | `string` | The keybox identity that failed         |

Tricky Addon will show an error snackbar to the user and close the repo overlay.

---

## Iframe Detection

Use the standard check `window.top !== window.self` to detect iframe mode. When embedded:

- **Embedded layout** — Show the repository cards, with theme and upload management handled by the parent application.
- **Card selection** — Send the download message immediately when the user selects a card.

---

## Reference Implementation

The reference below implements iframe detection, handshake and download responses:

```typescript
class IframeHandler {
  private static parentOrigin: string | null = null;

  static isIframe(): boolean {
    return window.top !== window.self;
  }

  static sendDownload(url: string) {
    if (IframeHandler.parentOrigin) {
      window.parent.postMessage({ type: 'download', url }, IframeHandler.parentOrigin);
    }
  }

  static sendError(identity: string) {
    if (IframeHandler.parentOrigin) {
      window.parent.postMessage(
        { type: 'error', error: 'download_failed', identity },
        IframeHandler.parentOrigin,
      );
    }
  }
}

// React hook — mount once in iframe mode
useEffect(() => {
  if (!IframeHandler.isIframe()) return;

  const handler = (event: MessageEvent) => {
    if (event.data?.type === 'handshake') {
      IframeHandler.parentOrigin = event.origin;
      window.parent.postMessage({ type: 'handshake_ack' }, event.origin);
    }
  };
  window.addEventListener('message', handler);
  return () => window.removeEventListener('message', handler);
}, []);
```

---

## Reference: How Tricky Addon Integrates

TrickyAddon handles the parent side as follows:

1. Creates an iframe pointing to your repo URL with permissions `clipboard-read; clipboard-write`
2. Sends `{ type: "handshake" }` every 500ms until it receives `handshake_ack`
3. Validates `event.origin` matches the configured repo URL
4. On `download`: fetches the URL via `fetch()`, sets the response as the active keybox, closes the overlay
5. On `error`: closes the overlay, shows an error snackbar
6. Pushes history state so the back button closes the repo overlay

---

## Backend API Example

A backend serves repository listings and download files. Example endpoints:

| Method | Path                               | Purpose                                   |
|--------|------------------------------------|-------------------------------------------|
| `GET`  | `/api/keyboxes`                    | List/search keyboxes                      |
| `GET`  | `/api/keyboxes/:identity`          | Get a single keybox's metadata            |
| `POST` | `/api/keyboxes/:identity/download` | Generate a download URL                   |
| `POST` | `/api/keyboxes`                    | Upload a new keybox (standalone mode only) |
| `GET`  | `/download/:token`                 | Serve the keybox file                     |

The example uses **one-time tokens**. `POST /api/keyboxes/:identity/download` returns a URL valid for one download within 24 hours. A repository can also use direct file URLs or signed URLs.

```json
// POST /api/keyboxes/:identity/download → 200
{ "token": "uuid", "url": "/download/uuid", "expires_at": "2026-06-06T..." }

// GET /download/:token → 200
// Content-Type: application/xml
// Content-Disposition: attachment; filename="keybox.xml"

// GET /download/:token → 404 (expired or already consumed)
{ "error": "token not found" }
```
