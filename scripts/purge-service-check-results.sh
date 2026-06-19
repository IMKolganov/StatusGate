#!/usr/bin/env bash
# Purge excess check_results for one monitored service (production-safe preview + delete).
#
# Usage (on dg-monitoring, from repo root):
#   ./scripts/purge-service-check-results.sh --slug helsinki-3-openvpn --dry-run
#   ./scripts/purge-service-check-results.sh --slug helsinki-3-openvpn --keep 100
#   ./scripts/purge-service-check-results.sh --name 'Helsinki 3' --keep 100
#
# Requires: docker compose, postgres service running.

set -euo pipefail

SERVICE_SLUG=""
SERVICE_NAME=""
KEEP=100
DRY_RUN=1
COMPOSE="docker compose"
PSQL_USER="${POSTGRES_USER:-statusgate}"
PSQL_DB="${POSTGRES_DB:-statusgate}"

usage() {
  sed -n '2,8p' "$0"
  echo ""
  echo "Options:"
  echo "  --slug SLUG     monitored_components.slug (exact match)"
  echo "  --name PATTERN  monitored_components.name ILIKE pattern (e.g. '%Helsinki%')"
  echo "  --keep N        keep newest N check_results (default: 100)"
  echo "  --dry-run       show counts only, do not delete (default)"
  echo "  --apply         actually delete"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SERVICE_SLUG="$2"; shift 2 ;;
    --name) SERVICE_NAME="$2"; shift 2 ;;
    --keep) KEEP="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --apply) DRY_RUN=0; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

if [[ -z "$SERVICE_SLUG" && -z "$SERVICE_NAME" ]]; then
  echo "Provide --slug or --name" >&2
  usage 1
fi

if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [[ "$KEEP" -lt 0 ]]; then
  echo "--keep must be a non-negative integer" >&2
  exit 1
fi

run_psql() {
  $COMPOSE exec -T db psql -v ON_ERROR_STOP=1 -U "$PSQL_USER" -d "$PSQL_DB" "$@"
}

FILTER_SQL=""
if [[ -n "$SERVICE_SLUG" ]]; then
  FILTER_SQL="mc.slug = '$SERVICE_SLUG'"
else
  FILTER_SQL="mc.name ILIKE '$SERVICE_NAME'"
fi

echo "=== Service lookup ==="
run_psql -c "
SELECT mc.id, mc.slug, mc.name, mc.check_type, mc.is_active,
       (SELECT count(*) FROM check_results cr WHERE cr.monitored_component_id = mc.id) AS check_results_total
FROM monitored_components mc
WHERE $FILTER_SQL;
"

echo ""
echo "=== Outcome breakdown ==="
run_psql -c "
SELECT cr.outcome, count(*) AS cnt
FROM check_results cr
JOIN monitored_components mc ON mc.id = cr.monitored_component_id
WHERE $FILTER_SQL
GROUP BY cr.outcome
ORDER BY cnt DESC;
"

echo ""
echo "=== Rows that would be deleted (keep newest $KEEP) ==="
run_psql -c "
WITH target AS (
  SELECT mc.id AS component_id
  FROM monitored_components mc
  WHERE $FILTER_SQL
),
ranked AS (
  SELECT cr.id,
         cr.checked_at,
         cr.outcome,
         row_number() OVER (PARTITION BY cr.monitored_component_id ORDER BY cr.checked_at DESC) AS rn
  FROM check_results cr
  JOIN target t ON t.component_id = cr.monitored_component_id
)
SELECT count(*) AS to_delete,
       min(checked_at) AS oldest_to_delete,
       max(checked_at) AS newest_to_delete
FROM ranked
WHERE rn > $KEEP;
"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "Dry run only. Re-run with --apply to delete."
  exit 0
fi

echo ""
read -r -p "Delete excess rows? Type yes: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

echo "=== Deleting ==="
run_psql -c "
WITH target AS (
  SELECT mc.id AS component_id
  FROM monitored_components mc
  WHERE $FILTER_SQL
),
ranked AS (
  SELECT cr.id,
         row_number() OVER (PARTITION BY cr.monitored_component_id ORDER BY cr.checked_at DESC) AS rn
  FROM check_results cr
  JOIN target t ON t.component_id = cr.monitored_component_id
),
 doomed AS (
  SELECT id FROM ranked WHERE rn > $KEEP
)
DELETE FROM check_results cr
USING doomed d
WHERE cr.id = d.id;
"

echo ""
echo "=== After purge ==="
run_psql -c "
SELECT mc.slug, count(cr.id) AS remaining
FROM monitored_components mc
LEFT JOIN check_results cr ON cr.monitored_component_id = mc.id
WHERE $FILTER_SQL
GROUP BY mc.slug;
"

echo "Done."
