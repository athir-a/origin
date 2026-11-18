# Origin 🌱

**Your progress changes more than just you.**

Origin is a gamified learning and productivity web application. You begin as a
student in a small village with limited resources. The community believes in
you and contributes what little it can. As you study, learn, and grow, the
village grows too — until one day you are the one who can help someone else
begin.

> Start with little → show up consistently → learn → grow → improve your
> community → succeed → give back.

## Status: Phase 1 — The Foundation

Phase 1 is **not** the game yet. It is the engineering foundation:

- ✅ React + Vite frontend
- ✅ Django + Django REST Framework backend
- ✅ Real accounts: **signup, login, logout**
- ✅ Protected dashboard (backend-enforced), with placeholder stats
- ✅ Demo API endpoint (`/api/health/`) proving the full stack round trip
- ✅ SQLite database, tests for the auth API
- ⏳ **Later phases:** study timer, XP & levels, the village, NPCs, weather,
  achievements, statistics, narrative — none of that exists yet, on purpose.

## The game (`Origin/`)

`Origin/` is a Godot 4.7 project holding the actual game: the village, the
study timer, XP and levels, villagers, weather and seasons, the journal,
achievements and the give-back ending. Game code lives in `Origin/scripts/origin/`.

How it plugs into the web app:

- **Build:** open `Origin/project.godot` in Godot 4.7, then choose
  *Project → Export → Web → Export Project*. The export writes to
  `frontend/public/game/`, which git ignores.
- **Play:** `/village` (React) shows the game in an iframe.
- **Saves:** when the game runs inside that page, `OriginState`
  (`Origin/scripts/origin/state.gd`) saves through `window.originBridge` to
  `GET/PUT/DELETE /api/progress/` instead of browser storage. Each account has
  its own journey. Run standalone, the game still saves locally.
- **Validation:** Django (`backend/apps/progress/rules.py`) rejects impossible
  saves: study time growing faster than real time, time going backwards, and
  XP above what the study time allows. If you change XP numbers in
  `content.gd` or `state.gd`, change them in `rules.py` too.
- The dashboard stats come from `/api/progress/`.

## Tech stack

| Layer     | Technology                                      |
| --------- | ----------------------------------------------- |
| Frontend  | React (JavaScript), Vite, React Router          |
| Backend   | Python, Django, Django REST Framework           |
| Database  | SQLite (development) → PostgreSQL (production)  |
| Auth      | DRF Token Authentication (hashed passwords)     |

## Architecture

```
┌─────────────────────┐   HTTP + JSON   ┌─────────────────────┐   ORM   ┌──────────────┐
│      React          │ ──────────────► │       Django        │ ──────► │   Database   │
│  (browser, UI)      │ ◄────────────── │  (server, rules)    │ ◄────── │   SQLite     │
└─────────────────────┘                 └─────────────────────┘         └──────────────┘
```

During development the browser only ever talks to **Vite** (`localhost:5173`).
Vite's dev server proxies every `/api/*` request to **Django** (`localhost:8000`).
This means no CORS configuration is needed and the browser sees one origin.

## Project structure

```
origin/
├── frontend/                 # React app (Vite)
│   └── src/
│       ├── components/       # Reusable UI pieces (ProtectedRoute, VillageScene)
│       ├── context/          # AuthContext — "who is logged in" app-wide
│       ├── pages/            # One file per screen (Login, Signup, Dashboard)
│       ├── services/         # api.js — the only file that talks to Django
│       ├── App.jsx           # Route table
│       └── main.jsx          # Entry point
└── backend/                  # Django project
    ├── config/               # Project settings + top-level URL routing
    ├── apps/
    │   ├── core/             # The demo /api/health/ endpoint
    │   └── users/            # signup, login, logout, me (+ tests)
    ├── requirements.txt
    └── manage.py
```

## Getting started (WSL)

The project lives on the WSL filesystem. Run everything from a **WSL terminal**
(open VS Code, then *Terminal → New Terminal* — it should say `user@host:~$`).

**1. Start the backend (Django):**

```bash
cd /home/seagull/origin/backend
python3 -m venv .venv                # first time only
.venv/bin/pip install -r requirements.txt   # first time only
.venv/bin/python manage.py migrate   # first time only
.venv/bin/python manage.py runserver
```

Django now serves the API on `http://127.0.0.1:8000`.

**2. Start the frontend (Vite) — second terminal:**

```bash
cd /home/seagull/origin/frontend
npm install      # first time only
npm run dev
```

**3. Open the app:** http://localhost:5173

Sign up for an account, and you land on your dashboard. Log out and try opening
`/dashboard` directly — you will be redirected to `/login`. That redirect is
frontend UX; the real protection is Django returning `401` for requests without
a valid token.

> The development database ships with a test account you can use right away:
> **username `athir` / password `village-pass-123`**. To start completely
> fresh, delete `backend/db.sqlite3` and run `migrate` again.

## API endpoints

| Method | URL                  | Auth required | Purpose                         |
| ------ | -------------------- | ------------- | ------------------------------- |
| GET    | `/api/health/`       | No            | Demo: full-stack round trip     |
| POST   | `/api/auth/signup/`  | No            | Create account (username, email, password, password2) |
| POST   | `/api/auth/login/`   | No            | Exchange credentials for a token |
| POST   | `/api/auth/logout/`  | Yes           | Revoke the token                |
| GET    | `/api/auth/me/`      | Yes           | Current user                    |

## Testing

```bash
cd /home/seagull/origin/backend
.venv/bin/python manage.py test
```

## Environment variables

| Variable          | Default (dev)                  | Purpose            |
| ----------------- | ------------------------------ | ------------------ |
| `DJANGO_SECRET_KEY` | insecure dev fallback        | Signing secrets — **must** be set to a real value in production |
| `DJANGO_DEBUG`    | `1`                            | Set to `0` in production |

## Security notes

- Passwords are hashed by Django (`create_user`) — plaintext is never stored.
- The API is **protected by default** (`IsAuthenticated`); public endpoints
  opt in explicitly with `AllowAny`.
- The frontend stores only the token; Django owns all data and authorization.
- Never commit real secrets. Production must set `DJANGO_SECRET_KEY`.

## Roadmap

- **Phase 2:** study timer, subjects, study history, XP & levels, consistency —
  the first real game loop (Farms → consistency).
- **Phase 3+:** the data-driven village (buildings, unlock conditions, visual
  states), NPCs with progression-aware dialogue, weather / day-night, statistics,
  achievements, and the give-back ending.

Every system above is deliberately **data-driven**: progression rules will live
in structured data (required XP, unlocked buildings, dialogue), not in
hardcoded `if` chains.


yikes we'll see how this goes
