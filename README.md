# LinkStack on Railway

Railway template for [LinkStack](https://linkstack.org), the open-source, self-hosted link-in-bio page (a Linktree alternative).

It deploys **LinkStack 4.8.8** from the official image `linkstackorg/linkstack:v4.8.8`, pinned by digest in the [`Dockerfile`](Dockerfile), as one service with a volume at `/htdocs`. LinkStack keeps its data in SQLite on that volume, so no separate database is needed.

## What the wrapper adds

- **No open installer.** LinkStack's web installer lets the first visitor create the admin account (and has a `/skip` route that logs in as a seeded admin). [`railway-bootstrap.php`](railway-bootstrap.php) finishes setup before Apache starts: it creates the admin account from the variables below, generates `APP_KEY`, switches to production mode (`APP_DEBUG=false`), keeps registration closed and removes the installer markers.
- **Persistent data.** On first boot [`railway-start.sh`](railway-start.sh) copies the app from the image into the empty volume at `/htdocs` (code, `.env`, `database/database.sqlite`, uploads, themes). Later boots keep what's there and run database migrations.
- **Railway networking.** Apache listens on `$PORT` (8080), TLS is left to Railway, and requests that reached Railway over HTTPS are treated as HTTPS, so links and assets use `https://`.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `LINKSTACK_ADMIN_EMAIL` | *(you enter it)* | Email of the admin account, used to log in. Read on first start only. |
| `LINKSTACK_ADMIN_PASSWORD` | `${{secret(24)}}` | Generated admin password. Read it in the service's Variables tab. Read on first start only: change it later in LinkStack. |
| `LINKSTACK_ADMIN_HANDLE` | `admin` | Admin's page name (`/@admin`). Optional, first start only. |
| `PORT` | `8080` | Port Apache listens on; the Railway domain points here. |

Optional: `UPLOAD_MAX_FILESIZE` (default `8M`), `PHP_MEMORY_LIMIT` (`256M`), `TZ` (`UTC`). Email (SMTP), registration, the homepage profile and other settings live in LinkStack's admin panel (**Admin → Config**), which edits `/htdocs/.env` on the volume.

## Health check

`/` answers 200 once LinkStack is set up.

## Updates

Railway tells deployers when this repo's `main` changes, and each deployer chooses when to apply it. See [`CHANGELOG.md`](CHANGELOG.md) before updating.

- A new image (Alpine, PHP, Apache) or wrapper reaches you through those updates.
- LinkStack's own code lives on the volume, like upstream's Docker setup, so an existing install updates its LinkStack version with the built-in updater (**Admin → Update**), which backs up first. A fresh deploy always starts on the version pinned here.

## License

LinkStack is AGPL-3.0, © LinkStack contributors ([LinkStackOrg/LinkStack](https://github.com/LinkStackOrg/LinkStack), [linkstack-docker](https://github.com/LinkStackOrg/linkstack-docker)). This repo only holds the Railway wrapper.
