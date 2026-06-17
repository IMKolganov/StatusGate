# StatusGate

Open-source service status platform with public status pages, uptime timelines, incident history, and a self-hosted admin dashboard.

**Live example:** [status.datagateapp.com](https://status.datagateapp.com/) — DataGate VPN service status (public home with per-project uptime timelines, project detail pages, Google sign-in, white-label branding).

StatusGate helps teams publish transparent health information for their products: HTTP/JSON/XML monitoring, background checks, grouped component views, and incident updates — similar to modern status pages, but fully under your control.

## What's new in `develop`

This release brings the full StatusGate stack from initial scaffolding to a deployable status page product.

### Public status pages

- **Home page** lists published projects; each card embeds the same **System status** panel as the project page (90-day timeline, component groups, uptime %, date range navigation).
- **Project pages** show grouped uptime timelines, current component health, latency, and incident history.
- **Contact page** and simplified public footer.
- **Header navigation:** Home, About, Contact; user menu with Google avatar and name; account sidebar for Account / Security / Admin.

### Authentication

- **Google Identity Services** sign-in (idToken flow) instead of redirect OAuth.
- Google **avatar URL** stored on the account and refreshed on each sign-in.
- Login rate limiting, JWT + refresh tokens, optional MFA (TOTP).

### Branding

- White-label via build-time env: `VITE_BRAND_NAME`, `VITE_BRAND_LOGO_URL`, `VITE_BRAND_TAGLINE`.
- Logo and header text are independent (logo-only header supported).

### Backend API

- FastAPI + PostgreSQL + Alembic migrations.
- Public APIs for projects, services, system status timelines, incidents.
- Monitoring scheduler and HTTP/JSON/XML check workers.
- **Project uptime** in the public project list API (90-day worst-per-day across components).

### Infrastructure

- Docker Compose for local and production deployment.
- Nginx frontend with API proxy; `X-Forwarded-Proto` support behind reverse proxy.

## Repository structure

This is the main orchestration repository. Application code lives in Git submodules:

| Path | Repository | Description |
|------|------------|-------------|
| [`backend/`](backend/) | [StatusGateBackend](https://github.com/IMKolganov/StatusGateBackend) | FastAPI API, PostgreSQL, Alembic, monitoring worker |
| [`frontend/`](frontend/) | [StatusGateFrontend](https://github.com/IMKolganov/StatusGateFrontend) | React + Vite UI, public status pages, admin panel |

## Clone

```bash
git clone --recurse-submodules -b develop git@github.com:IMKolganov/StatusGate.git
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
cd backend && git pull origin develop && cd ..
cd frontend && git pull origin develop && cd ..
git add backend frontend
git commit -m "Update submodules"
```

## License

MPL-2.0 — see [LICENSE](LICENSE).
