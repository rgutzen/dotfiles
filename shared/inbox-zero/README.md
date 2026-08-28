# inbox-zero (self-hosted)

Self-hosted [inbox-zero](https://github.com/elie222/inbox-zero) — AI email
assistant for the personal Outlook account, running as a local Docker
Compose stack. Local models only (see `shared/ai/README.md`); no data leaves
the machine.

## What's tracked here vs. what isn't

`~/.inbox-zero/` is the CLI's fixed working directory (`@inbox-zero/cli
setup`/`start`), not a repo. Only the non-secret pieces are symlinked in from
here:

- `docker-compose.yml` — pure env-var substitution, no literal secrets.
- `.env.example` — a redacted copy of the real `.env`, documenting every
  value that matters for this deployment (queue backend, Microsoft OAuth
  shape, the Ollama tier split). Placeholder values are `CHANGEME`.

`~/.inbox-zero/.env` itself holds real secrets (DB password, auth/encryption
keys, the Microsoft client secret) and is **never** tracked — this repo is
public. It's a plain file on the machine, created once via `cp
~/.inbox-zero/.env.example ~/.inbox-zero/.env` and then hand-filled.

## Setting up on a new machine

1. `npx @inbox-zero/cli setup` — installs Docker Compose config, walks
   through provider choices. It writes to `~/.inbox-zero/`, overwriting
   `docker-compose.yml`; re-run `./bootstrap.sh` afterward to symlink the
   tracked copy back over it.
2. `cp ~/.inbox-zero/.env.example ~/.inbox-zero/.env`, then fill in:
   - `POSTGRES_PASSWORD` / `DATABASE_URL` / `DIRECT_URL` — any password, kept
     consistent between the three.
   - `UPSTASH_REDIS_TOKEN`, `AUTH_SECRET`, `EMAIL_ENCRYPT_SECRET`,
     `EMAIL_ENCRYPT_SALT`, `INTERNAL_API_KEY`, `API_KEY_SALT`, `CRON_SECRET`,
     `MICROSOFT_WEBHOOK_CLIENT_STATE` — each `openssl rand -hex 32` (or the
     wizard generates them for you).
   - `MICROSOFT_CLIENT_ID` / `MICROSOFT_CLIENT_SECRET` — from a fresh Entra
     ID app registration (below). Client secrets are deployment-specific and
     can't be copied from another machine.
3. `./bootstrap.sh` — symlinks `docker-compose.yml`/`.env.example` in and
   enables `inbox-zero.service` (only if `~/.inbox-zero/.env` already
   exists — see below).

### Microsoft Entra ID app registration

A plain outlook.com account has no Azure tenant by default — sign up at
azure.microsoft.com/free first to provision one.

- **Supported account types**: "Accounts in any organizational directory
  ... and personal Microsoft accounts" — *not* "Personal accounts only".
  The app pairs with the `common` OAuth endpoint (`MICROSOFT_TENANT_ID=common`
  in `.env`); a personal-only registration rejects login with AADSTS error
  "account does not exist in tenant 'Microsoft Services'".
- Redirect URI: `http://localhost:3000/api/auth/callback/microsoft` (adjust
  the host if `NEXT_PUBLIC_BASE_URL` differs).
- **Certificates & secrets** → New client secret → copy the **Value**
  column, not the **Secret ID**. Both are GUID-shaped and easy to confuse;
  the ID is rejected at token-exchange time with
  `AADSTS7000215: Invalid client secret provided`. The Value is shown only
  once, at creation — if you've navigated away, create a new secret.
- Delegated Graph scopes needed (granted via the app's normal OAuth consent,
  no admin consent required): `openid`, `profile`, `email`, `User.Read`,
  `offline_access`, `Mail.ReadWrite`, `Mail.Send`, `MailboxSettings.ReadWrite`,
  `Contacts.Read`, `Calendars.Read`, `Calendars.ReadWrite`.

## LLM backend

Runs entirely on the local Ollama models from `shared/ai/README.md`, split
by inbox-zero's own reasoning-effort tiers
(`apps/web/utils/llms/model.ts`, `REASONING_EFFORT_BY_MODEL_TYPE`):

| Tier | Use | Model |
|---|---|---|
| `DEFAULT` / `ECONOMY` / `NANO` | high-volume per-email classification, low reasoning effort | `qwen3:4b-instruct-2507-q4_K_M` (small, always-on) |
| `CHAT` / `DRAFT` | reply drafting / chat, medium reasoning effort | `qwen3:30b-a3b-thinking-2507-q4_K_M` (thinking) |

The CLI setup wizard only lets you pick one model for every tier, so this
split is applied by hand afterward, editing the "Deprecated legacy LLM env
vars" block in `.env` directly (`*_LLM_PROVIDER`/`*_LLM_MODEL`, still read at
startup) rather than the newer `*_LLMS=provider:model` format.

`QUEUE_BACKEND=internal`: the `worker` compose service (for `bullmq`) sits
behind a `queue-worker` profile that isn't started by default. `internal`
processes jobs in the `web` container itself — no separate worker or Redis
queue needed for a single-user deployment. Leaving `QUEUE_BACKEND` unset
crashes `web` at boot with a zod validation error.

## Autostart

`inbox-zero.service` (in `shared/systemd/`) runs `docker compose up -d` at
login via `WantedBy=default.target`; lingering is enabled for this user, so
it also starts on boot without an interactive login. Containers already
carry `restart: always`, so this mainly matters for a full reboot where
Docker itself starts before any container existed to auto-restart.

```bash
systemctl --user status inbox-zero.service
systemctl --user stop inbox-zero.service    # docker compose stop
systemctl --user start inbox-zero.service   # docker compose up -d
journalctl --user -u inbox-zero.service
```

Day-to-day container logs/exec go through `docker compose` directly in
`~/.inbox-zero/` (or `npx @inbox-zero/cli logs`), not through this unit.
