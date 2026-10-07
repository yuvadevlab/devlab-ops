# DevLab Ops — Platform Operations & Orchestration Suite

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue.svg)](#)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Architecture](https://img.shields.io/badge/architecture-modular%20IaC-purple.svg)](#architecture-overview)

`devlab-ops` is the centralized operations, process supervision, disaster recovery, and deployment orchestration platform for Yuva DevLab services (**FinAI**, **OrchestrAI**, and future ecosystem applications).

It bridges the gap between active multi-repo feature engineering and stable, isolated production runtimes without container overhead or complex cloud infrastructure.

---

## Architecture Overview

```text
/production/
│
├── devlab-ops/                     # 🚀 Platform Orchestrator (This Repository)
│   ├── devlab                     # Master CLI Entrypoint
│   │
│   ├── config/                    # Declarative Configurations
│   │   ├── platform.env           # Dynamic root resolution & global settings
│   │   └── apps/
│   │       ├── finai.env          # FinAI service blueprint & ports
│   │       └── orchestrai.env     # OrchestrAI service blueprint & ports
│   │
│   ├── lib/                       # Modular Platform Engines
│   │   ├── config-loader.sh       # Dynamic path & config parser
│   │   ├── runner.sh              # Multi-process supervisor & health probes
│   │   ├── logger.sh              # Stream-splitting log multiplexer
│   │   ├── backup.sh              # Gzip snapshot engine & TTL retention
│   │   ├── restore.sh             # Interactive disaster recovery engine
│   │   ├── sync-db.sh             # Production-to-development database cloning engine
│   │   ├── updater.sh             # Git main pull, lockfile diff & migrations
│   │   ├── env-check.sh           # Environment drift & secret validator
│   │   ├── doctor.sh              # Full runtime & database health checker
│   │   ├── stats.sh               # Storage footprint & metrics telemetry
│   │   ├── install.sh             # Global CLI installer & Zsh completion
│   │   └── colors.sh              # Terminal telemetry & ANSI formatting
│   │
│   ├── .gitignore
│   └── README.md
│
├── devlab -> devlab-ops/devlab    # ⚡ Root Shortcut (run ./devlab anywhere in /production)
│
├── finai/                         # Pure Git Worktree (origin/main)
├── orchestrai/                    # Pure Git Worktree (origin/main)
│
├── logs/                          # Date-Partitioned Multi-Stream Logs
│   ├── finai/YYYY-MM-DD/
│   └── orchestrai/YYYY-MM-DD/
│
└── backups/                       # Compressed Database Snapshots (.sql.gz)
    ├── finai/
    └── orchestrai/
```

---

## Core Capabilities

### 1. Process Supervision & Port Protection

- Automatically inspects configured service ports via `lsof` and safely terminates orphaned processes before booting.
- Traps termination signals (`SIGINT`, `SIGTERM`, `EXIT`) to guarantee clean, coordinated shutdowns of both API and Web processes without leaving zombie ports.

### 2. Startup Readiness Health Probes

- Rather than declaring a service "live" prematurely, asynchronous health probes poll the configured `HEALTH_URL` and `WEB_URL` until HTTP `200 OK` is returned.
- Reports exact boot latency in real-time (e.g., `✓ [FinAI API] Verified ready in 1.4s`).

### 3. Date-Partitioned Stream Splitting

- High-performance stream multiplexing powered by `awk` that simultaneously:
  - Emits color-tagged output to the interactive terminal.
  - Writes a unified, chronological `e2e.log` containing all service logs.
  - Segregates application logs into `api/api.log` and `web/web.log`.
  - Isolates warnings and exceptions into dedicated `error.log` files.
  - Filters HTTP request paths, methods, and durations into `api/http.log`.
  - Automatically strips ANSI escape sequences for pristine disk files.

### 4. Database Snapshotting & Disaster Recovery

- On-demand and pre-update database snapshots compressed on the fly via `gzip` (~85% disk reduction).
- Configurable 14-day TTL retention policy that purges obsolete snapshots automatically.
- Interactive 1-command restore engine that lists backups, takes a pre-restore safety snapshot, terminates active database connections, and restores data safely.

### 5. Zero-Downtime Safe Updates

- Updating an app automatically triggers:
  1. A pre-flight safety backup.
  2. `git pull origin main` in the target worktree.
  3. Automatic `pnpm install` **only if** `pnpm-lock.yaml` changed.
  4. Automatic database migrations **only if** schema files changed.
  5. Full monorepo production rebuild.

### 6. Environment Drift & Secret Auditing

- Scans all `.env.example` templates across packages and compares required keys against active production `.env` and `.env.local` files, flagging omissions before runtime failures occur.

---

## CLI Command Reference (`devlab`)

The CLI can be executed via `./devlab` from `/production/`, via `./devlab-ops/devlab`, or globally as `devlab` after running `./devlab install`.

### Application Lifecycle

#### `devlab start <app>`

Starts all processes for `<app>` (API and Web) with port verification, date-stamped logging, and readiness health probes:

```bash
devlab start finai
devlab start orchestrai
```

#### `devlab stop <app>`

Terminates running processes and frees ports for `<app>`:

```bash
devlab stop finai
```

#### `devlab update <app>`

Safely updates an application from the latest `main` branch:

```bash
devlab update finai
```

_Flow: Pre-backup ➔ Git pull ➔ Lockfile diff check ➔ Migration diff check ➔ Rebuild._

---

### Real-Time Log Inspection

#### `devlab logs <app> [stream]`

Inspects real-time logs for today's active partition:

```bash
# Master end-to-end timeline (API + Web chronologically merged)
devlab logs finai e2e

# Errors & warnings only (with full stack traces)
devlab logs finai error

# API backend logs only
devlab logs finai api

# Next.js frontend logs only
devlab logs finai web

# HTTP access traffic & endpoint latencies
devlab logs finai http

# List today's log files and disk sizes
devlab logs finai list
```

---

### Database & Disaster Recovery

#### `devlab backup [app|all]`

Creates compressed `.sql.gz` snapshots and prunes snapshots older than 14 days:

```bash
# Snapshot FinAI database only
devlab backup finai

# Snapshot OrchestrAI database only
devlab backup orchestrai

# Snapshot all configured databases
devlab backup all
```

#### `devlab restore <app> [snapshot-file]`

Interactively lists and restores a previous database backup:

```bash
devlab restore finai
```

_Sample Interactive Flow:_

```text
======================================================
   🚀 DevLab Ops — FinAI — Database Restore
======================================================
Available database backups in /production/backups/finai:

  [1] finai_2026-10-06_130415.sql.gz (80K) — 2026-10-06 13:04:15
  [2] finai_2026-10-06_121722.sql.gz (80K) — 2026-10-06 12:17:22

Select backup to restore [1-2, default: 1]: 1
⚠️  WARNING: Restoring will overwrite existing data in 'finai'.
Are you sure you want to restore 'finai_2026-10-06_130415.sql.gz'? (yes/N): yes

Step 1/2: Taking safety snapshot of current state before restore...
✓ Saved: /production/backups/finai/finai_2026-10-06_141000.sql.gz
Step 2/2: Restoring database 'finai'...
✓ Database 'finai' restored successfully!
```

#### `devlab sync-db <app> [-y]`

Clones the production database into the local development database (`<app>_dev`) for safe local testing:

```bash
# Sync FinAI production data (finai) -> dev database (finai_dev)
devlab sync-db finai

# Sync OrchestrAI production data (orchestrai) -> dev database (orchestrai_dev)
devlab sync-db orchestrai

# Skip confirmation prompt in automated scripts
devlab sync-db finai -y
```

_Features:_

- Takes an automatic pre-sync snapshot of your existing dev database before overwriting.
- Terminates lingering dev connections and resets schema cleanly.
- Streams data directly over `pg_dump | psql` with zero intermediate disk overhead.
- Verifies cloned table count matches production.

---

### Platform Quality & Diagnostics

#### `devlab env <app>`

Audits environment variables against template declarations to prevent configuration drift:

```bash
devlab env finai
devlab env orchestrai
```

#### `devlab doctor`

Executes an end-to-end diagnostic check across runtime tools, ports, database connections, and services:

```bash
devlab doctor
```

#### `devlab stats`

Displays current storage footprint across logs and backup snapshots:

```bash
devlab stats
```

#### `devlab install`

Installs the global CLI binary symlink (`~/.local/bin/devlab`) and configures rich Zsh shell completion:

```bash
./devlab install
source ~/.zshrc
```

##### 🌟 Global Usage & Terminal Superpowers

After running `devlab install` and `source ~/.zshrc`, you can use `devlab` globally from **any terminal tab or directory** on your machine:

1. **Global Execution Anywhere:**
   ```bash
   devlab start finai
   devlab sync-db finai
   devlab doctor
   ```
2. **Interactive Tab Autocompletion:**
   Press `<Tab>` after `devlab` or any subcommand to see an interactive menu with descriptions and arrow-key selection:
   ```text
   $ devlab <TAB>
     start     -- Start application services with live streaming logs
     stop      -- Stop running services and free ports
     update    -- Backup DB, pull latest main, migrate & rebuild
     logs      -- Inspect logs (e2e, error, api, web, http)
     backup    -- Create timestamped gzipped database snapshots
     restore   -- Interactive database restore from backup
     sync-db   -- Clone production database to development for testing
     doctor    -- Run platform diagnostic & port check
     env       -- Audit environment variables and check for drift
     stats     -- Inspect log and backup storage consumption
   ```
3. **App & Option Tab Completion:**

   ```text
   $ devlab start <TAB>
     finai        orchestrai

   $ devlab logs finai <TAB>
     api    e2e    error  http   list   web
   ```

4. **Real-Time Inline Ghost Autosuggestions (Fish-like as you type):**
   Powered by `zsh-autosuggestions` and `zsh-syntax-highlighting` (installed via Homebrew):
   - As you type, grey ghost text automatically suggests past commands.
   - Press **Right Arrow (`→`)** or **`End`** to accept the suggestion instantly.
   - Press **`Tab`** to open the interactive arrow-key autocompletion menu.
   - Valid commands highlight in green; typos highlight in red before pressing Enter.

---

## Log Architecture Specification

Logs are organized by date partitions (`YYYY-MM-DD`) under `/production/logs/<app>/`:

```text
logs/finai/
├── latest -> 2026-10-06                  # Symlink pointing to today's active folder
└── 2026-10-06/                           # Date-partitioned log directory
    ├── e2e.log                           # Master timeline with all services merged
    ├── error.log                         # Consolidated errors and warnings
    ├── api/
    │   ├── api.log                       # Clean API application logs
    │   ├── error.log                     # API warnings, exceptions & stack traces
    │   └── http.log                      # HTTP requests, response codes & latencies
    └── web/
        ├── web.log                       # Clean Next.js server logs
        └── error.log                     # Next.js SSR exceptions
```

- All disk logs are stripped of ANSI color codes for compatibility with standard text processing tools (`grep`, `awk`, `less`).
- Date partitions older than 14 days are automatically pruned on each application boot.

---

## Service Port Matrix

| Service        | Environment | Frontend Port           | Backend / Gateway Port  | Companion Services        | Database (Prod)      | Database (Dev)           |
| :------------- | :---------- | :---------------------- | :---------------------- | :------------------------ | :------------------- | :----------------------- |
| **FinAI**      | Production  | `http://localhost:3010` | `http://localhost:4010` | N/A                       | `finai` (:5432)      | `finai_dev` (:5432)      |
| **OrchestrAI** | Production  | `http://localhost:3011` | `http://localhost:4011` | RT `:4012`<br>WRK `:4013` | `orchestrai` (:5432) | `orchestrai_dev` (:5432) |

---

## Onboarding a New Application

To onboard an additional application into `devlab-ops`, create a single configuration file under `config/apps/<app-id>.env`:

```bash
# config/apps/my-new-app.env
APP_ID="my-new-app"
APP_NAME="My New App"
APP_DIR="${DEVLAB_ROOT}/my-new-app"
DEV_REPO_DIR="${REPOS_DIR}/my-new-app"

# Database Configuration
DB_NAME="my_app_prod"
DB_HOST="${DEFAULT_DB_HOST}"
DB_PORT="${DEFAULT_DB_PORT}"
DB_USER="${DEFAULT_DB_USER}"

# Port Blueprint
WEB_PORT=3012
API_PORT=4012

# Endpoints
WEB_URL="http://localhost:3012"
API_URL="http://localhost:4012"
HEALTH_URL="http://localhost:4012/health"
DOCS_URL="http://localhost:4012/api/docs"

# Lifecycle Commands (Executed inside APP_DIR)
API_START_CMD="node apps/api/dist/main.js"
WEB_START_CMD="pnpm next start -p 3012"
BUILD_CMD="pnpm build"
MIGRATE_CMD="pnpm db:migrate:deploy"

# Build Verification Targets
BUILD_CHECK_API="apps/api/dist/main.js"
BUILD_CHECK_WEB="apps/web/.next"
```

The new application will automatically appear in `./devlab help` and be supported by `start`, `stop`, `update`, `logs`, `backup`, `restore`, and `doctor`.

---

## Automated Scheduled Backups (Optional)

To enable automatic daily database backups at 2:00 AM, add the following cron schedule:

```cron
0 2 * * * /Users/yuvarajpattabi/Yuva/yuva-devlab/production/devlab-ops/devlab backup all >> /Users/yuvarajpattabi/Yuva/yuva-devlab/production/backups/cron.log 2>&1
```

---

## License

MIT © [Yuva DevLab](https://github.com/yuvadevlab)
