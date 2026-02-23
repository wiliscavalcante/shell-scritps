#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  backup_batch.sh <region> <vpc_id> [s3_backup_bucket] [max_parallel] [recent_hours]

Exemplos:
  ./scripts/backup_batch.sh sa-east-1 vpc-0123456789abcdef
  ./scripts/backup_batch.sh sa-east-1 vpc-0123456789abcdef meu-bucket-backup 4
  ./scripts/backup_batch.sh sa-east-1 vpc-0123456789abcdef meu-bucket-backup 4 24
EOF
}

if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
  usage
  exit 1
fi

REGION="$1"
VPC_ID="$2"
S3_BUCKET="${3:-}"
MAX_PARALLEL="${4:-3}"
RECENT_HOURS="${5:-24}"

if ! [[ "$MAX_PARALLEL" =~ ^[0-9]+$ ]] || [ "$MAX_PARALLEL" -lt 1 ]; then
  echo "max_parallel deve ser inteiro >= 1"
  exit 1
fi
if ! [[ "$RECENT_HOURS" =~ ^[0-9]+$ ]] || [ "$RECENT_HOURS" -lt 1 ]; then
  echo "recent_hours deve ser inteiro >= 1"
  exit 1
fi

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SINGLE_SCRIPT="${BASE_DIR}/scripts/backup_lambda.sh"
if [ ! -x "$SINGLE_SCRIPT" ]; then
  echo "Script nao encontrado/executavel: $SINGLE_SCRIPT"
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BATCH_ID="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
BATCH_ROOT="${BASE_DIR}/backups/_batches/${BATCH_ID}"
FUNCTION_BACKUP_ROOT="${BASE_DIR}/backups/functions"
LOG_DIR="${BATCH_ROOT}/logs"
REPORT_DIR="${BATCH_ROOT}/reports"
FUNCTIONS_FILE="${BATCH_ROOT}/functions.txt"

mkdir -p "$FUNCTION_BACKUP_ROOT" "$LOG_DIR" "$REPORT_DIR"

echo "[1/6] Descobrindo Lambdas da VPC ${VPC_ID} em ${REGION}"
aws lambda list-functions \
  --region "$REGION" \
  --max-items 10000 \
  --query "Functions[?VpcConfig.VpcId=='${VPC_ID}'].FunctionName" \
  --output text | tr '\t' '\n' | sed '/^$/d' | sort > "$FUNCTIONS_FILE"

TOTAL="$(wc -l < "$FUNCTIONS_FILE" | tr -d ' ')"
if [ "$TOTAL" = "0" ]; then
  echo "Nenhuma Lambda encontrada para VPC ${VPC_ID} em ${REGION}."
  exit 1
fi

echo "[2/6] Lambdas encontradas: ${TOTAL}"

cp "$FUNCTIONS_FILE" "${REPORT_DIR}/identified-lambdas.txt"
python3 - "$FUNCTIONS_FILE" "$REGION" "$VPC_ID" "$ACCOUNT_ID" "$BATCH_ID" "${REPORT_DIR}/identified-lambdas.json" <<'PY'
import json
import sys
from datetime import datetime, timezone

functions_file, region, vpc_id, account_id, batch_id, output_json = sys.argv[1:]
with open(functions_file, "r", encoding="utf-8") as f:
    functions = [line.strip() for line in f if line.strip()]

payload = {
    "batch_id": batch_id,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "account_id": account_id,
    "region": region,
    "vpc_id": vpc_id,
    "total_identified": len(functions),
    "functions": functions,
}

with open(output_json, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
PY

run_one() {
  local fn="$1"
  local log_file="${LOG_DIR}/${fn}.log"
  local status_file="${LOG_DIR}/${fn}.status"

  if BACKUP_ROOT="$FUNCTION_BACKUP_ROOT" BACKUP_TIMESTAMP="$BATCH_ID" "$SINGLE_SCRIPT" "$fn" "$REGION" "$S3_BUCKET" >"$log_file" 2>&1; then
    local marker
    marker="$(grep -E 'BACKUP_(OK|SKIPPED)' "$log_file" | tail -n1 || true)"
    local backup_dir
    backup_dir="$(echo "$marker" | sed -n 's/.*backup_dir=\([^ ]*\).*/\1/p')"
    if echo "$marker" | grep -q 'BACKUP_SKIPPED'; then
      printf 'SKIP|%s\n' "$backup_dir" > "$status_file"
    else
      printf 'OK|%s\n' "$backup_dir" > "$status_file"
    fi
  else
    printf 'FAIL|\n' > "$status_file"
  fi
}

echo "[3/6] Executando backup em lote (paralelismo=${MAX_PARALLEL})"
PIDS=()
COUNT=0
while IFS= read -r fn; do
  run_one "$fn" &
  PIDS+=("$!")
  COUNT=$((COUNT + 1))

  if [ "${#PIDS[@]}" -ge "$MAX_PARALLEL" ]; then
    for pid in "${PIDS[@]}"; do
      wait "$pid" || true
    done
    PIDS=()
  fi

done < "$FUNCTIONS_FILE"

for pid in "${PIDS[@]}"; do
  wait "$pid" || true
done

SUCCESS=0
SKIPPED=0
FAILED=0
while IFS= read -r fn; do
  if [ -f "${LOG_DIR}/${fn}.status" ] && grep -q '^OK|' "${LOG_DIR}/${fn}.status"; then
    SUCCESS=$((SUCCESS + 1))
  elif [ -f "${LOG_DIR}/${fn}.status" ] && grep -q '^SKIP|' "${LOG_DIR}/${fn}.status"; then
    SKIPPED=$((SKIPPED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done < "$FUNCTIONS_FILE"

echo "[4/6] Gerando relatorios"
python3 - "$BATCH_ROOT" "$FUNCTION_BACKUP_ROOT" "$LOG_DIR" "$FUNCTIONS_FILE" "$REGION" "$VPC_ID" "$ACCOUNT_ID" "$BATCH_ID" "$SUCCESS" "$SKIPPED" "$FAILED" "$RECENT_HOURS" <<'PY'
import csv
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone

(
    batch_root,
    backup_root,
    log_dir,
    functions_file,
    region,
    vpc_id,
    account_id,
    batch_id,
    success,
    skipped,
    failed,
    recent_hours,
) = sys.argv[1:]

with open(functions_file, "r", encoding="utf-8") as f:
    functions = [line.strip() for line in f if line.strip()]

recent_hours_int = int(recent_hours)
recent_threshold = datetime.now(timezone.utc) - timedelta(hours=recent_hours_int)

def get_last_invocation_utc(function_name, region):
    log_group = f"/aws/lambda/{function_name}"
    try:
        out = subprocess.check_output(
            [
                "aws",
                "logs",
                "describe-log-streams",
                "--region",
                region,
                "--log-group-name",
                log_group,
                "--order-by",
                "LastEventTime",
                "--descending",
                "--max-items",
                "1",
                "--query",
                "logStreams[0].lastEventTimestamp",
                "--output",
                "text",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return None

    if not out or out in ("None", "null", "NULL"):
        return None

    try:
        ts_ms = int(out)
    except ValueError:
        return None

    dt = datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc)
    return dt.isoformat()

items = []
for fn in functions:
    status_path = os.path.join(log_dir, f"{fn}.status")
    log_path = os.path.join(log_dir, f"{fn}.log")

    status = "FAIL"
    snapshot_dir = os.path.join(backup_root, fn, batch_id)
    if os.path.exists(status_path):
        with open(status_path, "r", encoding="utf-8") as sf:
            raw = sf.read().strip()
        if raw:
            parts = raw.split("|", 1)
            status = parts[0]
            if len(parts) > 1 and parts[1]:
                snapshot_dir = parts[1]

    manifest_path = os.path.join(snapshot_dir, "manifest.json")

    error = None
    code_sha256 = None
    runtime = None
    handler = None
    files = []
    last_invocation_utc = get_last_invocation_utc(fn, region)
    executed_recently = None
    if last_invocation_utc:
        last_dt = datetime.fromisoformat(last_invocation_utc)
        executed_recently = last_dt >= recent_threshold

    if status in ("OK", "SKIP") and os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as mf:
            m = json.load(mf)
        code_sha256 = m.get("code_sha256")
        runtime = m.get("runtime")
        handler = m.get("handler")
        files = m.get("files", [])
    else:
        if os.path.exists(log_path):
            with open(log_path, "r", encoding="utf-8", errors="replace") as lf:
                lines = [ln.strip() for ln in lf.readlines() if ln.strip()]
            if lines:
                error = lines[-1]

    items.append(
        {
            "function_name": fn,
            "status": status,
            "backup_dir": snapshot_dir,
            "manifest": manifest_path if os.path.exists(manifest_path) else None,
            "runtime": runtime,
            "handler": handler,
            "code_sha256": code_sha256,
            "last_invocation_utc": last_invocation_utc,
            "executed_recently": executed_recently,
            "recent_window_hours": recent_hours_int,
            "files": files,
            "error": error,
        }
    )

summary = {
    "batch_id": batch_id,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "account_id": account_id,
    "region": region,
    "vpc_id": vpc_id,
    "total_functions": len(functions),
    "success_count": int(success),
    "skipped_count": int(skipped),
    "failed_count": int(failed),
    "recent_window_hours": recent_hours_int,
    "batch_root": batch_root,
    "items": items,
}

report_json = os.path.join(batch_root, "reports", "backup-report.json")
with open(report_json, "w", encoding="utf-8") as f:
    json.dump(summary, f, indent=2)

report_csv = os.path.join(batch_root, "reports", "backup-report.csv")
with open(report_csv, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow([
        "function_name",
        "status",
        "backup_dir",
        "runtime",
        "handler",
        "code_sha256",
        "last_invocation_utc",
        "executed_recently",
        "recent_window_hours",
        "files_count",
        "error",
    ])
    for i in items:
        writer.writerow([
            i["function_name"],
            i["status"],
            i["backup_dir"],
            i["runtime"],
            i["handler"],
            i["code_sha256"],
            i["last_invocation_utc"],
            i["executed_recently"],
            i["recent_window_hours"],
            len(i["files"]),
            i["error"],
        ])

print(report_json)
print(report_csv)
PY

echo "[5/6] Relatorios gerados"
echo "Identificadas na VPC:"
cat "${REPORT_DIR}/identified-lambdas.txt"
echo "---"
cat "${REPORT_DIR}/backup-report.csv"

echo "[6/6] Final"
echo "BATCH_ID=${BATCH_ID}"
echo "BATCH_ROOT=${BATCH_ROOT}"
echo "REPORT_JSON=${REPORT_DIR}/backup-report.json"
echo "REPORT_CSV=${REPORT_DIR}/backup-report.csv"
echo "IDENTIFIED_TXT=${REPORT_DIR}/identified-lambdas.txt"
echo "IDENTIFIED_JSON=${REPORT_DIR}/identified-lambdas.json"
echo "RECENT_HOURS=${RECENT_HOURS}"
echo "TOTAL=${TOTAL} SUCCESS=${SUCCESS} SKIPPED=${SKIPPED} FAILED=${FAILED}"

if [ "$FAILED" -gt 0 ]; then
  exit 2
fi
