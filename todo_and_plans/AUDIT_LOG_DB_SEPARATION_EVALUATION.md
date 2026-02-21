# Evaluation: Should Audit/AI Logs Move to a Separate Database?

## Context

Projulous uses two append-only log tables — `AuditLogs` (entity CUD tracking, ~7K rows / 11 MB) and `AIInteractionLogs` (LLM call tracking, ~1.1K rows / 3.9 MB) — in the same PostgreSQL database as all business data. Both use a fire-and-forget pattern and share the same TypeORM connection pool. The concern is that as the platform scales, unbounded log growth could degrade performance of business operations.

## Recommendation: Do NOT Separate Databases Now

**Both the architect and DBA analyses reached the same conclusion.** Database separation is premature and would add significant complexity without solving a problem that doesn't yet exist. Instead, implement a tiered mitigation strategy that scales with actual growth.

### Why Not Now

| Factor | Current State | Verdict |
|--------|--------------|---------|
| **Total DB size** | 132 MB (logs = 15 MB / 11%) | Trivial |
| **Active users** | 4 | Far too early |
| **Connection pool** | 17 of 100 connections used | Massive headroom |
| **Buffer cache** | 128 MB shared_buffers, entire DB fits | No cache pressure |
| **WAL from logs** | ~18 MB/day (inflated by seed data) | Negligible |
| **Autovacuum cost** | INSERT-only = zero dead tuples | Non-issue |

### What Separation Would Break

- **Foreign keys** to `Users` and `Conversations` tables (used in admin UI JOINs)
- **Admin UI queries** that do `LEFT JOIN user` to show who performed actions
- **AI audit analysis** feature that enriches logs with user details before Gemini analysis
- Adds a 3rd TypeORM DataSource, 2nd migration history, 2nd RDS instance ($15-30/mo+)
- Estimated 5-10 days of refactoring for moderate architectural gain

---

## Tiered Action Plan

### Tier 1: Do Now (1-2 days)

**1a. Explicit connection pool sizes** in `app.module.ts`
- Add `extra: { max: 15 }` to write DataSource, `extra: { max: 10 }` to read DataSource
- File: `projulous-svc/src/app.module.ts` (lines 63-76)

**1b. Retention CRON service**
- New `LogRetentionService` with `@Cron('0 2 * * *')` (daily at 2 AM)
- Delete `AIInteractionLogs` older than 6 months (debug/observability data, large rows)
- Delete `AuditLogs` older than 12 months (or archive to S3 first if compliance requires)
- Batched deletes (1,000 rows per transaction) to avoid long locks
- Files: new `projulous-svc/src/audit/logRetention.service.ts`, register in `audit.module.ts`

**1c. Tune autovacuum for log tables** (migration SQL)
- After retention introduces DELETEs, set per-table aggressive autovacuum:
  ```sql
  ALTER TABLE "AuditLogs" SET (autovacuum_vacuum_scale_factor = 0.05, autovacuum_vacuum_threshold = 1000);
  ALTER TABLE "AIInteractionLogs" SET (autovacuum_vacuum_scale_factor = 0.05, autovacuum_vacuum_threshold = 500);
  ```

**1d. Monitoring query** (add to admin or run manually monthly)
- Track `pg_total_relation_size` + `n_live_tup` for both log tables
- Alert threshold: either table exceeds 1 GB or 500K rows

### Tier 2: At 500K+ Rows (~1,000 DAU, est. 6-12 months out)

**Monthly time-based partitioning** on `createdDate` for both tables
- Convert to `PARTITION BY RANGE (createdDate)` via migration
- CRON to auto-create next month's partition + drop expired partitions
- Instant retention: `DROP TABLE partition_name` instead of slow batch DELETEs
- Admin queries get partition pruning on date filters (already indexed)
- TypeORM works transparently (writes to parent table, PG routes to partition)

### Tier 3: At 10M+ Rows (~10,000 DAU, est. 2+ years out)

**Re-evaluate database separation** at this scale. Options:
- Separate RDS instance for logs (full isolation)
- External logging (CloudWatch, OpenSearch, S3+Athena)
- Decision depends on actual pain points observed (pool contention, cache pressure, backup times)

---

## Growth Projections

| Scale | DAU | Audit rows/yr | AI rows/yr | Combined size/yr | Action Level |
|-------|-----|---------------|------------|------------------|-------------|
| Current | 4 | ~15K | ~5K | ~25 MB | Monitor only |
| Small | 30 | ~165K | ~73K | ~340 MB | Tier 1 (retention) |
| Medium | 200 | ~1.5M | ~440K | ~2.6 GB | Tier 2 (partition) |
| Large | 2,000 | ~18M | ~7.3M | ~28 GB | Tier 3 (re-evaluate) |

---

## Key Files

| File | Role |
|------|------|
| `projulous-svc/src/app.module.ts` | TypeORM config — add pool sizes |
| `projulous-svc/src/audit/audit.service.ts` | Audit write/read service |
| `projulous-svc/src/audit/audit.module.ts` | Register retention CRON |
| `projulous-svc/src/audit/auditEventHandler.service.ts` | Fire-and-forget event handler |
| `projulous-svc/src/projulousAI/services/aiInteractionLogger.service.ts` | AI log write service |
| `projulous-shared-dto-node/audit/auditLog.entity.ts` | AuditLog entity |
| `projulous-shared-dto-node/projulousAI/aiInteractionLog.entity.ts` | AIInteractionLog entity |

## Implementation Scope

**If you want to proceed, Tier 1 is the recommended scope:**
1. Add explicit pool sizes to `app.module.ts` (~5 min)
2. Create `LogRetentionService` with daily CRON for batched cleanup (~2-3 hours)
3. Add autovacuum tuning migration (~30 min)
4. Add a size monitoring query to admin or as a CRON log (~30 min)

This is entirely a backend change — no shared-dto or frontend modifications needed. No migrations that alter table structure (autovacuum settings are ALTER TABLE SET, not schema changes).
