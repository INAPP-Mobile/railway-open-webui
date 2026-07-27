# Open WebUI — Railway Template

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/new/template/open-webui-4)

Self-hosted Open WebUI is a multi-provider chat UI for any Large Language Model, deployable on Railway in minutes. Drop an OpenAI-style API key on the deploy form for instant access, pair it with [Railway Ollama](#connecting-to-a-local-ollama-instance) for a fully local setup, or use the in-app admin UI to plug in Anthropic and any other provider. All chat history lives in a persistent Railway volume; your data never leaves your own infrastructure.

## Features

- **Instant chat** — Deploy form ships with `DEFAULT_MODELS=gpt-4o` and auto-generated `OPENAI_API_KEY` placeholder. Replace with your real `sk-...` key and the UI is live.
- **Multi-provider** — OpenAI, OpenRouter, Groq, Together AI, or any OpenAI-compatible endpoint via the same base URL.
- **Single-container** — One Railway service, one persistent `/data` volume for SQLite. PostgreSQL optional from the admin UI.
- **Full admin UI** — Sign-up toggles, OAuth/OIDC, LDAP, RAG, image generation, web search — all at `/admin/settings`.
- **Per-user API keys** — Each user stores their own keys; admins set a global default in Settings → Connections.
- **Volume-backed persistence** — SQLite at `/data` survives deploys, restarts, and region changes.

```
┌─────────────────┐
│   Railway CDN   │ ◄── Production traffic
└────────┬────────┘
         │
┌────────▼────────┐
│  Open WebUI      │ ◄── FastAPI + Svelte (Docker)
│  Container       │     - /health endpoint
│                  │     - PORT=8080
├──────────────────┤
│  /data volume    │ ◄── Persistent SQLite DB
└──────────────────┘
```

## Deploy and Host

### About Hosting

Open WebUI runs as a single Docker container with a persistent volume for SQLite database storage. It requires no external database dependencies and can connect to any OpenAI-compatible API or Ollama instance.

Railway provides automatic HTTPS, global CDN, health monitoring, and scalable infrastructure. The default health check at `/health` ensures Railway can monitor service availability.

- **Default Port:** 8080 (Railway auto-injects `PORT`; upstream start.sh uses it)
- **Health Check:** `GET /health` — returns HTTP 200 when ready
- **Startup Time:** ~30-60 seconds (alembic migrations + lifespan init on cold volume)
- **Resource Usage:** ~256MB RAM baseline

## Why Deploy

Open WebUI is the most popular self-hosted LLM interface (20K+ GitHub stars) with features that rival ChatGPT:

- **Full privacy** — All conversations stay in your infrastructure
- **Model flexibility** — Switch between OpenAI, Anthropic, Google, Ollama, or any OpenAI-compatible API
- **No vendor lock-in** — Self-hosted means you control costs and data
- **Zero external dependencies** — SQLite backend works out of the box

With Railway, you get automatic HTTPS, global CDN, health monitoring, and scalable infrastructure — without managing servers.

## Common Use Cases

- **Local LLM interface** — Connect to a self-hosted Ollama or other local model server
- **Multi-API gateway** — Use multiple LLM providers from one interface
- **Team AI portal** — Share a self-hosted ChatGPT experience with your team
- **Privacy-focused chat** — Keep all AI interactions private and auditable
- **Custom tooling** — Extend with JavaScript functions and custom integrations

## Dependencies for Open WebUI

### Deployment Dependencies

- **Runtime:** Open WebUI v0.10.2 (upstream ghcr.io image, pinned in the Dockerfile)
- **Storage:** Persistent volume mounted at `/data` (Railway `[[deploy.volumeMounts]] mountPath`; `DATA_DIR=/data` is baked into the Dockerfile, and the entrypoint precreates + chmod 777's it on first boot so the upstream non-root user can write)
- **External access:** Port 8080 for the web interface and API
- **Optional:** Ollama or OpenAI-compatible API endpoint (set `OLLAMA_BASE_URL` or provider API keys)

## Environment Variables

The deploy form only asks for the **up-front** knobs. Every other Open WebUI setting (sign-up toggles, OAuth/OIDC, LDAP, RAG, image generation, etc.) is configurable from the in-app admin UI after your first login — see [Configuring after deploy](#configuring-after-deploy). Defaults are safe for everyone else.

| Variable              | Default                                 | Description |
|-----------------------|-----------------------------------------|-------------|
| `WEBUI_SECRET_KEY`    | _auto (Railway generates 32 chars)_     | Signs session cookies and JWTs. Auto-generated at deploy time. Do not edit unless you intentionally want to invalidate every active session. |
| `WEBUI_URL`    | `https://<railway-domain>`              | Public URL of this deployment. Auto-resolves to `https://${{RAILWAY_PUBLIC_DOMAIN}}` so OAuth callbacks and CORS work out of the box. Override in the **Variables** tab for custom domains. |
| `DEFAULT_MODELS`      | `gpt-4o`                                | Comma-separated list of model IDs in the chat picker. Default `gpt-4o`. Override with models from your configured provider (e.g., `llama3.1:latest` for Railway Ollama, `gpt-4o,claude-3-5-sonnet` for multi-provider). |
| `OPENAI_API_KEY`      | _auto (random placeholder)_             | Random placeholder (`${{secret(32)}}`); replace with your real `sk-...` key. |
| `OPENAI_API_BASE_URL` | `https://api.openai.com/v1`             | Base URL for the OpenAI-compatible provider above. Override with `http://ollama.railway.internal:11434/v1` for Railway Ollama, `https://openrouter.ai/api/v1` for OpenRouter, etc. |

These are the only variables rendered on the Railway template deploy form. Other Open WebUI variables (PostgreSQL URL, RAG embedding model, web search key, etc.) can be added from the Railway **Variables** tab and are also exposed in the admin UI.

## Getting Started

1. Click the **Deploy on Railway** button above.
2. Wait for the build to complete (usually < 2 minutes).
3. Visit your Railway app URL — the **first signup is automatically promoted to admin**.
4. Open the admin panel (`/admin/settings`) and configure sign-up, OAuth, API keys, and providers — see [Configuring after deploy](#configuring-after-deploy).
5. Hit `/health` — returns `200 OK` once the app is fully up.

## Configuring after deploy

Sign-up toggles, OAuth/OIDC, LDAP, and ~150 environment variables are exposed in the admin UI at `/admin/settings`.

**Enable/disable sign-up:** Admin Panel → Settings → General → toggle "Enable Sign-Up". Flip off after creating admin to lock to invited users.

**Set up OAuth (Google, GitHub, Microsoft, OIDC):** Admin Panel → Settings → Authentication → toggle Enable OAuth/OIDC Sign-In → fill Client ID + Secret → set Redirect URL to `https://<your-app-url>/auth/<provider>/callback` → Save. `WEBUI_URL` auto-resolves to `https://<railway-domain>` so callbacks work out of the box.

**Add LLM providers (Anthropic, OpenAI, OpenRouter):** Settings → Connections → toggle provider → paste API key. Per-user keys live in each user's profile; set a global default here.

**Advanced (RAG, image gen, web search, speech):** Most settings have admin UI controls. For env-var-only settings, add them in Railway's Variables tab. See [Open WebUI docs](https://docs.openwebui.com) for the full list.

## Connecting to a Local Ollama Instance

If you're running Open WebUI alongside a separate Ollama service on Railway:

1. Deploy the [railway-ollama](https://railway.com/new/template/ollama) template in the same project.
2. In the **Variables** tab, set `OPENAI_API_BASE_URL=http://ollama.railway.internal:11434/v1` (Ollama ≥0.3 ships with an OpenAI-compatible gateway).
3. Restart the Open WebUI service and pull a model from the Ollama service's settings.
4. In the **Variables** tab, set `DEFAULT_MODELS=llama3.1:latest` (or whatever model you pulled) to surface it in the chat picker.

## Troubleshooting

**Database empty after redeploy:** `DATA_DIR` is baked into the image as `/data` (Dockerfile ENV), and the persistent volume is `open-webui-volume` mounted at `/data`. If you change the volume's name in the **Volumes** tab, update `[[deploy.volumeMounts]] name =` to match — otherwise Railway creates a SECOND volume and the app starts fresh every deploy.

**Build fails:** Check the latest build log in the **Deployments** tab — the Dockerfile is a single `FROM ghcr.io/open-webui/open-webui:v0.10.2` line that should complete in under 30s. If it stalls on `apt-get update` or `pip install`, the upstream image tag was rebuilt and our pinned version went stale; update the FROM line.

**Login page errors or app won't start:** `WEBUI_URL` auto-fills to `https://${{RAILWAY_PUBLIC_DOMAIN}}` — secure cookies and OAuth callbacks work out of the box. Override only for custom domains.**OAuth button missing on login page:** Confirm two things — `WEBUI_URL` matches the URL you're logging in through (default is `https://<railway-domain>`, with `https://` prefix included automatically), and OAuth is toggled on in **Settings → Authentication**. Re-test after saving.

## Resources

- [Open WebUI Documentation](https://docs.openwebui.com)
- [Railway Docs](https://docs.railway.com)
- [Repository](https://github.com/INAPP-Mobile/railway-open-webui)