<h1 align="center">
  Infuse Artwork WebDAV Server<br /><a href="https://infuse-artwork.andrewe.dev">infuse-artwork.andrewe.dev</a>
</h1>

This public WebDAV endpoint serves custom artwork for [Infuse], allowing you to personalize the artwork for categories and favorites. Infuse is a popular media player for Apple TV, iOS, and macOS that supports fetching custom artwork via WebDAV.

<p align="center">
  <img src="./docs/images/cast-atv.png" alt="Cast artwork" width="200" />
  <img src="./docs/images/link-atv.png" alt="Link artwork" width="200" />
</p>

## Infuse Documentation

Using custom artwork with Infuse:
- [Adding Custom Favorite Artwork (tvOS)](https://support.firecore.com/hc/en-us/articles/360003185773-Adding-Custom-Favorite-Artwork-tvOS)
- [Overriding Artwork and Metadata](https://support.firecore.com/hc/en-us/articles/4405042929559-Overriding-Artwork-and-Metadata)

## Using with Infuse

### Adding as a Network Share

1. Settings → Shares → Add Share → WebDAV
2. Server: \
`https://infuse-artwork.andrewe.dev`
3. Advanced: Auto Scan: Off
4. Save

## Deployment

- built on [r2-webdav] a WebDAV server implementation for Cloudflare Workers and R2

### Prerequisites

- [Wrangler CLI] installed
- [rclone] installed: `brew install rclone`
- Cloudflare account with Workers and R2 enabled
- Node.js 18+ and npm

### Initial Setup

```bash
git clone https://github.com/andesco/infuse-artwork-webdav-worker.git
cd infuse-artwork-webdav-worker
npm install
wrangler r2 bucket create infuse-artwork
```

### Configuration

Update `wrangler.toml`:
```toml
name = "infuse-artwork-webdav"
main = "src/index.ts"
compatibility_date = "2025-12-22"
compatibility_flags = ["nodejs_compat"]
workers_dev = true

# Custom domain (auto-creates DNS)
routes = [
  { pattern = "infuse-artwork.andrewe.dev", custom_domain = true }
]

[[r2_buckets]]
binding = "bucket"
bucket_name = "infuse-artwork"

[observability]
enabled = true
head_sampling_rate = 1
```

### Deploy

```bash
wrangler deploy
```

## Managing Images

### Sync Local Folder to R2

Use `rclone` for true synchronization (handles adds, updates, deletes, and renames):

#### Setup `rclone`

1. Get your Cloudflare Account ID:
   ```bash
   wrangler whoami
   ```

2. Create R2 API credentials:
   - Cloudflare Dashboard → R2 → Overview  → [Manage R2 API Tokens](https://dash.cloudflare.com/?to=/:account/r2/api-tokens) → Create API Token
   - Permissions: Admin Read & Write
   - Copy: **Access Key ID** and **Secret Access Key**

3. Configure `rclone`:
   ```bash
   rclone config
   ```

   Follow the prompts:
   - `n` for new remote
   - Name: `r2`
   - Storage: Amazon S3 compatible
   - Provider: `Cloudflare`
   - Access Key ID: [paste from step 2]
   - Secret Access Key: [paste from step 2]
   - Region: `auto`
   - Endpoint: `https://{ACCOUNT_ID}.r2.cloudflarestorage.com`
   - ACL: `private`
   - accept defaults for remaining options

#### Sync folder to R2

```bash
rclone sync infuse-artwork/ r2:infuse-artwork -v
```

> [!Note]
> `rclone sync` makes the R2 bucket identical to your local folder and will **delete** remote files that do not exist locally. Use the `--dry-run` flag to see what will change when syncing:
> ```
> rclone sync infuse-artwork/ r2:infuse-artwork --dry-run -v
> ```

### Upload Images with Wrangler

> [!Important]
> Always use the `--remote` flag to upload to the production R2 bucket (not to local development storage).

upload a single image:
```bash
wrangler r2 object put infuse-artwork/filename.png \
  --file=./filename.png \
  --content-type=image/png \
  --remote
```

upload multiple images:

```bash
for file in *.png; do
  echo "Uploading $file..."
  wrangler r2 object put "infuse-artwork/$file" \
    --file="$file" \
    --content-type=image/png \
    --remote
done
```

delete images:

```bash
wrangler r2 object delete infuse-artwork/filename.png --remote
```

## Development

### Local Development

```bash
npm run dev
```

### Testing

test HTML directory listing:
```bash
curl https://infuse-artwork-webdav.andrewe.workers.dev/
```

test specific image:
```bash
curl -I https://infuse-artwork-webdav.andrewe.workers.dev/cast.png
```

test WebDAV PROPFIND:
```bash
curl -X PROPFIND https://infuse-artwork-webdav.andrewe.workers.dev/ \
  -H "Depth: 1" \
  -H "Content-Type: text/xml" \
  --data '<?xml version="1.0"?><propfind xmlns="DAV:"><prop><resourcetype/><getcontentlength/><getlastmodified/></prop></propfind>'
```

verify write protection (401):
```bash
curl -X PUT https://infuse-artwork-webdav.andrewe.workers.dev/test.txt \
  -H "Content-Type: text/plain" \
  --data "test"
```

## Security Model

**publicly accessible** without authentication: `GET` `HEAD` `PROPFIND` `OPTIONS`

**require authentication**: `PUT` `DELETE` `MKCOL` `COPY`
 `MOVE` `PROPPATCH`

> [!NOTE]
> Since no credentials are configured, all write operations will return `401 Unauthorized` .

## Technical Details

### WebDAV Implementation

- **protocol**: WebDAV Class 1, 3
- **hosting**: Cloudflare Workers
- **storage**: Cloudflare R2
- **framework**: [r2-webdav]

### Modifications to `r2-webdav`

This deployment includes a modification to [r2-webdav] to enable public read-only access:

**File**: `src/index.ts`

```typescript
// Allow public read-only access (GET, HEAD, PROPFIND)
// Require authentication for write operations
const readOnlyMethods = ['OPTIONS', 'GET', 'HEAD', 'PROPFIND'];
const requiresAuth = !readOnlyMethods.includes(request.method);

if (
  requiresAuth &&
  !is_authorized(request.headers.get('Authorization') ?? '', env.USERNAME, env.PASSWORD)
) {
  return new Response('Unauthorized', {
    status: 401,
    headers: {
      'WWW-Authenticate': 'Basic realm="webdav"',
    },
  });
}
```

## License

The project is based on abersheeran/[r2-webdav].

[Infuse]: https://firecore.com/infuse
[r2-webdav]: https://github.com/abersheeran/r2-webdav
[Wrangler CLI]: https://developers.cloudflare.com/workers/wrangler/
[rclone]: https://rclone.org/

