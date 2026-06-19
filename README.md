# StatusGate

Open-source service status platform with public status pages, uptime timelines, incident history, and a self-hosted admin dashboard.

**Live example:** [status.datagateapp.com](https://status.datagateapp.com/) — DataGate VPN service status (public home with per-project uptime timelines, project detail pages, Google sign-in, white-label branding).

StatusGate helps teams publish transparent health information for their products: HTTP/JSON/XML monitoring, VPN checks (OpenVPN, Xray), background checks, grouped component views, and incident updates — similar to modern status pages, but fully under your control.

## Features

### Public status pages

- Home page with per-project **System status** timelines (same panel as on the project page)
- Project pages: uptime timelines, current service health, latency, incidents
- Contact page, public header (Home / About / Contact), mobile menu

### Monitoring

- HTTP / JSON / XML health checks
- **OpenVPN** and **Xray**: paste config, connect, probe through tunnel/proxy, show network details (IP, exit IP, DNS, latency)
- Background worker with configurable poll intervals

### Authentication & admin

- Google Identity Services sign-in, avatar in header
- JWT + refresh tokens, optional MFA (TOTP)
- Admin dashboard: projects, services, incidents, service types

### Branding

- White-label via `VITE_BRAND_NAME`, `VITE_BRAND_LOGO_URL`, `VITE_BRAND_TAGLINE`

## Repository structure

This is the main orchestration repository. Application code lives in Git submodules:

| Path | Repository | Description |
|------|------------|-------------|
| [`backend/`](backend/) | [StatusGateBackend](https://github.com/IMKolganov/StatusGateBackend) | FastAPI API, PostgreSQL, Alembic, monitoring worker |
| [`frontend/`](frontend/) | [StatusGateFrontend](https://github.com/IMKolganov/StatusGateFrontend) | React + Vite UI, public status pages, admin panel |

## Clone

```bash
git clone --recurse-submodules git@github.com:IMKolganov/StatusGate.git
cd StatusGate
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

## Quick start (Docker)

```bash
cp .env.example .env
# Set JWT_SECRET in .env (at least 32 characters)
# Optional: GOOGLE_CLIENT_ID for Google sign-in
# Optional: VITE_BRAND_NAME, VITE_BRAND_LOGO_URL for white-label

docker compose up -d --build
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- OpenAPI docs: http://localhost:8000/docs

## Production deploy

```bash
git pull && git submodule update --init --recursive
docker compose up -d --build
```

Put a reverse proxy (nginx, Caddy, etc.) in front of the frontend container and set `REQUIRE_HTTPS=true`, `COOKIE_SECURE=true` when serving over HTTPS.

## Development

Work in submodule directories and commit changes in their respective repositories:

```bash
cd backend
# backend changes → commit & push in StatusGateBackend

cd ../frontend
# frontend changes → commit & push in StatusGateFrontend
```

Update submodule pointers in this repo when you want to pin new versions:

```bash
cd backend && git pull origin main && cd ..
cd frontend && git pull origin main && cd ..
git add backend frontend
git commit -m "Update submodules"
```

## License

MPL-2.0 — see [LICENSE](LICENSE).
