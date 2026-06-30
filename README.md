# Open WebUI — Railway Template

[![Deploy on Railway](https://railway.com/button/deploy.svg)](https://railway.com/template/open-webui-3)

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

- **Default Port:** 8080 (configurable via `PORT`)
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

- **Runtime:** Open WebUI v0.10.1 (bundled in the container image)
- **Storage:** Persistent volume at `/data` for SQLite database
- **External access:** Port 8080 for the web interface and API
- **Optional:** Ollama or OpenAI-compatible API endpoint (set `OLLAMA_BASE_URL` or provider API keys)

## Environment Variables

Copy `.env.example` to `.env` after deployment and set these variables in your Railway project settings:

| Variable                 | Default                                    | Description                                                    |
|--------------------------|--------------------------------------------|----------------------------------------------------------------|
| `DATABASE_URL`           | `sqlite:////data/open_webui.db`            | Database path (SQLite file or PostgreSQL URL)                  |
| `PORT`                   | `8080`                                     | HTTP port the app listens on                                   |
| `WEBSITE_HOSTNAME`       | *(empty - set to your Railway URL)*         | Public URL for OAuth and CORS                                  |
| `ENABLE_SIGNUP`          | `true`                                     | Allow new user registration                                    |
| `DISABLE_SIGNUP`         | `false`                                    | Disable sign-up entirely                                       |
| `ENABLE_OAUTH_SIGN_IN`   | `false`                                    | Enable OAuth provider login                                    |
| `OAUTH_CLIENT_ID`        | *(empty)*                                  | OAuth client ID from your provider                              |
| `OAUTH_CLIENT_SECRET`    | *(empty)*                                  | OAuth client secret from your provider                          |
| `DEFAULT_MODELS`         | `llama3.1:latest`                          | Available default models list                                  |
| `PRIMARY_MODEL`          | `llama3.1:latest`                          | Default LLM model to use                                       |
| `CHAT_DEFAULT_MODEL`     | `llama3.1:latest`                          | Model selected by default in chat                              |

## Getting Started

1. Click the **Deploy on Railway** button above
2. Wait for the build to complete (usually < 2 minutes)
3. Set `WEBSITE_HOSTNAME` to your Railway app URL in project settings
4. Visit your app at `/health` — should return `200 OK`

## Connecting to a Local Ollama Instance

If you're running Open WebUI alongside a local Ollama server:

1. Deploy the [railway-ollama](https://railway.com/template/ollama) template separately
2. Set `OLLAMA_BASE_URL=http://database.internal` on your Open WebUI project
3. Restart the application

## Troubleshooting

**Build fails:** Ensure `DOCKERFILE` builder is selected and your git branch is up to date.

**App won't start after deploy:** Verify `WEBSITE_HOSTNAME` includes the correct protocol (`https://`). Open WebUI requires this for secure cookies.

**Database empty after redeploy:** Make sure your Railway volume (mounted at `/data`) persists across deploys. Delete and recreate the volume if needed.

**OAuth not working:** OAuth callbacks require `WEBSITE_HOSTNAME` to be set to your actual production URL before you first configure OAuth credentials in Open WebUI settings.

## Resources

- [Open WebUI Documentation](https://docs.openwebui.com)
- [Railway Docs](https://docs.railway.com)
- [Repository](https://github.com/INAPP-Mobile/railway-open-webui)