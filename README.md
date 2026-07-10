# Open WebUI — Railway Template

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/new/template/open-webui-3)

Self-hosted Open WebUI (formerly Ollama WebUI) — a beautiful, feature-rich interface for running LLMs locally or via API. Deploy in minutes on Railway.

## Features

- **Chat with any LLM** — connect to local Ollama instances or remote APIs
- **Beautiful web interface** — dark/light themes, markdown/code rendering, streaming responses
- **Fully self-hosted** — no data leaves your infrastructure
- **SQLite-first deployment** — zero external dependencies; PostgreSQL optional
- **OAuth support** — integrate with Google, GitHub, or any OpenID provider
- **Plugin-ready** — extensible architecture for custom tools and integrations

## Architecture

```
┌─────────────────┐
│   Railway CDN   │ ◄── Production traffic
└────────┬────────┘
         │
┌────────▼────────┐
│  Open WebUI      │ ◄── Express + WebUI (Docker)
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

- **Default Port:** 8080 (Railway auto-injects `PORT`; the entrypoint falls back to 8080 if absent)
- **Health Check:** `GET /health` — returns HTTP 200 when ready
- **Startup Time:** ~2 seconds (Open WebUI is lightweight)
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

- **Runtime:** Open WebUI v0.10.2 (bundled in the container image)
- **Storage:** Persistent volume at `/data` for SQLite database
- **External access:** Port 8080 for the web interface and API
- **Optional:** Ollama or OpenAI-compatible API endpoint (set `OLLAMA_BASE_URL` or provider API keys)

## Environment Variables

The deploy form only asks for the **up-front** knobs. Every other Open WebUI setting (sign-up toggles, OAuth/OIDC, LDAP, RAG, image generation, etc.) is configurable from the in-app admin UI after your first login — see [Configuring after deploy](#configuring-after-deploy). Defaults are safe for everyone else.

| Variable              | Default                                 | Description |
|-----------------------|-----------------------------------------|-------------|
| `WEBUI_SECRET_KEY`    | _auto (Railway generates 32 chars)_     | Signs session cookies and JWTs. Auto-generated at deploy time. Do not edit unless you intentionally want to invalidate every active session. |
| `WEBSITE_HOSTNAME`    | `https://<railway-domain>`              | Public URL of this deployment. Auto-resolves to `https://${{RAILWAY_PUBLIC_DOMAIN}}` so OAuth callbacks and CORS work out of the box. Override in the **Variables** tab for custom domains. |
| `DEFAULT_MODELS`      | _(empty)_                               | Comma-separated model IDs shown in the chat picker (e.g. `llama3.1:latest,gpt-4o`). Leave empty and add models once a provider is connected. |
| `OPENAI_API_KEY`      | _(empty)_                               | API key for OpenAI, OpenRouter, Groq, Together AI, or any OpenAI-compatible provider. Leave empty if you only use a local Ollama server. |
| `OPENAI_API_BASE_URL` | _(empty)_                               | Base URL for the provider above. Leave empty for `https://api.openai.com/v1`. Examples: `https://openrouter.ai/api/v1`, `http://ollama.railway.internal:11434/v1`. |

These are the only variables rendered on the Railway template deploy form. Other Open WebUI variables (PostgreSQL URL, RAG embedding model, web search key, etc.) can be added from the Railway **Variables** tab and are also exposed in the admin UI.

## Getting Started

1. Click the **Deploy on Railway** button above.
2. Wait for the build to complete (usually < 2 minutes).
3. Visit your Railway app URL — the **first signup is automatically promoted to admin**.
4. Open the admin panel (`/admin/settings`) and configure sign-up, OAuth, API keys, and providers — see [Configuring after deploy](#configuring-after-deploy).
5. Hit `/health` — returns `200 OK` once the app is fully up.

## Configuring after deploy

The deploy form is intentionally short. Sign-up toggles, OAuth/OIDC, LDAP, and the bulk of Open WebUI's ~150 environment variables are exposed in the admin UI at `/admin/settings`.

### Enable or disable sign-up

1. Log in as the admin (the first account created).
2. Click your avatar → **Admin Panel**.
3. Open **Settings → General** (`/admin/settings`).
4. Toggle **Enable Sign-Up**. Flip it off once you've created your admin account to lock the deployment to invited users.
5. Use **Default User Role** to pre-stage new accounts as `pending`, `user`, or another role.

### Set up OAuth / OIDC

Open WebUI has first-class OAuth/OIDC support for Google, GitHub, Microsoft, and generic OIDC, plus LDAP/AD for enterprise. As of v0.6+ these settings live on a dedicated **Authentication** page (moved out of General):

1. `WEBSITE_HOSTNAME` already auto-resolves to `https://<railway-domain>` at deploy time, so OAuth callbacks work out of the box. Only override it if you front the service with a custom domain (e.g., `https://chat.example.com`). OAuth callbacks reject mismatched origins — set this **before** testing the login button.
2. In the admin UI, open **Settings → Authentication**.
3. Toggle **Enable OAuth/OIDC Sign-In**.
4. Fill in **Client ID**, **Client Secret**, and the discovery URLs (`/.well-known/openid-configuration`) — inline placeholders are provided for Google, GitHub, Microsoft, and generic OIDC.
5. Save, log out, and re-test the login page — the provider button should appear.

### Add LLM provider keys

Per-user API keys live in each user's profile. To set a default for new users or configure a global admin key, go to **Settings → Connections** in the admin UI. This avoids setting environment variables per user.

### Adjust other advanced settings

Almost every env var in upstream [Open WebUI `.env.example`](https://github.com/open-webui/open-webui/blob/main/.env.example) has an equivalent admin UI control — search the **Settings** page for `RAG`, `Web Search`, `Image Generation`, `Default User Role`, etc. If a setting is only exposed as an env var, set it directly from the Railway **Variables** tab.

## Connecting to a Local Ollama Instance

If you're running Open WebUI alongside a separate Ollama service on Railway:

1. Deploy the [railway-ollama](https://railway.com/new/template/ollama) template in the same project.
2. On your Open WebUI service, set `OPENAI_API_BASE_URL=http://ollama.railway.internal:11434/v1` (Ollama ≥0.3 ships with an OpenAI-compatible gateway).
3. Restart the Open WebUI service and pull a model from the Ollama service's settings.
4. Set `DEFAULT_MODELS=llama3.1:latest` (or whatever model you pulled) in the Open WebUI service to surface it in the chat picker.

## Troubleshooting

**Build fails:** Ensure `DOCKERFILE` builder is selected and your git branch is up to date.

**Login page errors or app won't start:** `WEBSITE_HOSTNAME` auto-fills to `https://${{RAILWAY_PUBLIC_DOMAIN}}` — secure cookies and OAuth callbacks work out of the box. Override only for custom domains.

**OAuth button missing on login page:** Confirm two things — `WEBSITE_HOSTNAME` matches the URL you're logging in through (default is `https://<railway-domain>`, with `https://` prefix included automatically), and OAuth is toggled on in **Settings → Authentication**. Re-test after saving.

**No models in the chat picker:** Either set `DEFAULT_MODELS` to a model you've configured, or open **Settings → Connections** in the admin UI and add a provider + API key.

**Database empty after redeploy:** Make sure your Railway volume (mounted at `/data`) persists across deploys. Delete and recreate the volume only if you intentionally want a fresh SQLite store.

## Resources

- [Open WebUI Documentation](https://docs.openwebui.com)
- [Railway Docs](https://docs.railway.com)
- [Repository](https://github.com/INAPP-Mobile/railway-open-webui)