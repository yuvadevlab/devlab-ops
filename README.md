# DevLab Ops — Platform Operations & Orchestration Suite

`devlab-ops` is the centralized operations, process supervision, and deployment orchestration platform for Yuva DevLab services (FinAI, OrchestrAI, and future ecosystem applications).

---

## Architecture Overview

```text
devlab-ops/
├── devlab                     # Master CLI Executable
├── config/
│   ├── platform.env           # Global platform settings & dynamic pathing
│   └── apps/
│       ├── finai.env          # FinAI service definitions & ports
│       └── orchestrai.env     # OrchestrAI service definitions & ports
├── lib/
│   ├── config-loader.sh       # Dynamic environment resolver
│   ├── runner.sh              # Multi-process supervisor & port manager
│   ├── logger.sh              # Stream-splitting log multiplexer
│   ├── backup.sh              # Gzip database snapshot engine & TTL pruner
│   ├── updater.sh             # Branch sync, lockfile diff, migrations & build
│   ├── doctor.sh              # Health diagnostics & port verifier
│   └── colors.sh              # ANSI styling & terminal telemetry
├── .gitignore
└── README.md
```

---

## Core Capabilities

1. **Process Supervision & Port Protection**: Automated port collision detection (`lsof`) and graceful multi-service lifecycle control (`SIGINT`/`SIGTERM` traps).
2. **Date-Partitioned Stream Splitting**: Real-time multiplexing separating `e2e.log`, `error.log`, `api/`, and `web/` logs with automated ANSI escape sequence stripping.
3. **Automated Database Safeguards**: Pre-flight timestamped `pg_dump` backups with Gzip compression and a configurable 14-day TTL retention policy.
4. **Zero-Downtime Updates**: Safe updates from `main` that pull code, detect lockfile differences, trigger migrations only when schema diffs exist, and rebuild artifacts.
5. **Declarative App Configuration**: Modular `.env` profiles under `config/apps/` allowing new services to be onboarded in seconds.

---

## CLI Reference (`devlab`)

```bash
# Display help and configured applications
./devlab help

# Start an application with live logs & port protection
./devlab start finai
./devlab start orchestrai

# Stop running application instances
./devlab stop finai
./devlab stop orchestrai

# Safe update from 'main' (Backup -> Pull -> Migrate -> Rebuild)
./devlab update finai
./devlab update orchestrai

# Inspect real-time logs
./devlab logs finai e2e        # Master end-to-end chronological stream
./devlab logs finai error      # Master error & warning stream
./devlab logs finai api        # API backend logs
./devlab logs finai web        # Web frontend logs
./devlab logs finai http       # HTTP access & latency traffic
./devlab logs finai list       # Inspect today's log directory

# Trigger database backups
./devlab backup finai          # Snapshot FinAI database
./devlab backup orchestrai     # Snapshot OrchestrAI database
./devlab backup all            # Snapshot all configured databases

# Platform Diagnostics
./devlab doctor                # Check runtime versions, ports, databases & health
```

---

## Service Port Matrix

| Service | Environment | Web Port | API / Gateway Port | Database Target |
| :--- | :--- | :--- | :--- | :--- |
| **FinAI** | Production | `http://localhost:3010` | `http://localhost:4010` | `finai` (PostgreSQL :5432) |
| **OrchestrAI** | Production | `http://localhost:3011` | `http://localhost:4011` | `orchestrai` (PostgreSQL :5432) |

---

## Automated Daily Scheduling (Optional)

To enable automated daily database backups at 2:00 AM, add the following cron entry:

```cron
0 2 * * * /Users/yuvarajpattabi/Yuva/yuva-devlab/production/devlab-ops/devlab backup all >> /Users/yuvarajpattabi/Yuva/yuva-devlab/production/backups/cron.log 2>&1
```

---

## License

MIT © Yuva DevLab
