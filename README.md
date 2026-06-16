# StatusGate

Open-source service status platform with public status pages, uptime timelines, incident history, and a self-hosted admin dashboard.

StatusGate helps teams publish transparent health information for their products: HTTP/JSON/XML monitoring, background checks, grouped component views, and incident updates — similar to modern status pages, but fully under your control.

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

docker compose up -d --build
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- OpenAPI docs: http://localhost:8000/docs

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
