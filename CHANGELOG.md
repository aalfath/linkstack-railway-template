# Changelog

## 4.8.8-railway.1 (2026-11-16)

- First release: LinkStack 4.8.8 (`linkstackorg/linkstack:v4.8.8@sha256:deba986fc1f7391af629c0bbcca67a1508284176bd3accf69d041ecc887dc7dd`).
- One service with a volume at `/htdocs` (SQLite). The admin account is created from `LINKSTACK_ADMIN_EMAIL` and a generated `LINKSTACK_ADMIN_PASSWORD` before Apache starts, so the web installer is never exposed.
