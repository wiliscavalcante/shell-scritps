#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Uso: $0 <function_name> <region> [s3_backup_bucket]"
  exit 1
fi

FUNCTION_NAME="$1"
REGION="$2"
S3_BUCKET="${3:-}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-${BASE_DIR}/backups}"
TIMESTAMP="${BACKUP_TIMESTAMP:-$(date -u +"%Y-%m-%dT%H-%M-%SZ")}"
FUNCTION_ROOT="${BACKUP_ROOT}/${FUNCTION_NAME}"
BACKUP_DIR="${FUNCTION_ROOT}/${TIMESTAMP}"

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

mkdir -p "$FUNCTION_ROOT"

echo "[0/7] Lendo estado atual da Lambda"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" > "${TMP_DIR}/get-function-current.json"
aws lambda get-function-configuration --function-name "$FUNCTION_NAME" --region "$REGION" > "${TMP_DIR}/configuration-current.json"

readarray -t CURRENT_META < <(python3 - "${TMP_DIR}" <<'PY'
import hashlib
import json
import os
import sys

base = sys.argv[1]
with open(os.path.join(base, "get-function-current.json"), "r", encoding="utf-8") as f:
    gf = json.load(f)
with open(os.path.join(base, "configuration-current.json"), "r", encoding="utf-8") as f:
    cfg = json.load(f)

function_arn = cfg.get("FunctionArn") or gf.get("Configuration", {}).get("FunctionArn")
code_url = gf.get("Code", {}).get("Location")
aws_code_sha256 = cfg.get("CodeSha256")

fingerprint_payload = {
    "runtime": cfg.get("Runtime"),
    "handler": cfg.get("Handler"),
    "role": cfg.get("Role"),
    "timeout": cfg.get("Timeout"),
    "memory_size": cfg.get("MemorySize"),
    "architectures": cfg.get("Architectures"),
    "layers": cfg.get("Layers"),
    "vpc_config": cfg.get("VpcConfig"),
    "environment": cfg.get("Environment"),
    "ephemeral_storage": cfg.get("EphemeralStorage"),
    "file_system_configs": cfg.get("FileSystemConfigs"),
    "tracing_config": cfg.get("TracingConfig"),
    "dead_letter_config": cfg.get("DeadLetterConfig"),
    "kms_key_arn": cfg.get("KMSKeyArn"),
    "last_modified": cfg.get("LastModified"),
}
canonical = json.dumps(fingerprint_payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
config_fingerprint = hashlib.sha256(canonical.encode("utf-8")).hexdigest()

print(function_arn or "")
print(code_url or "")
print(aws_code_sha256 or "")
print(config_fingerprint)
PY
)

FUNCTION_ARN="${CURRENT_META[0]}"
CODE_URL="${CURRENT_META[1]}"
CURRENT_AWS_CODE_SHA256="${CURRENT_META[2]}"
CURRENT_CONFIG_FINGERPRINT="${CURRENT_META[3]}"

if [ -z "$FUNCTION_ARN" ] || [ -z "$CODE_URL" ]; then
  echo "Nao foi possivel identificar FunctionArn/Code.Location para ${FUNCTION_NAME}"
  exit 1
fi

LATEST_DIR="$(find "$FUNCTION_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n1 || true)"
if [ -n "$LATEST_DIR" ] && [ -s "${LATEST_DIR}/manifest.json" ]; then
  if python3 - "${LATEST_DIR}/manifest.json" "$CURRENT_AWS_CODE_SHA256" "$CURRENT_CONFIG_FINGERPRINT" <<'PY'
import json
import sys

manifest_path, cur_code, cur_cfg_fp = sys.argv[1:]
with open(manifest_path, "r", encoding="utf-8") as f:
    m = json.load(f)

prev_code = m.get("aws_code_sha256")
prev_cfg_fp = m.get("config_fingerprint")

if prev_code and prev_cfg_fp and prev_code == cur_code and prev_cfg_fp == cur_cfg_fp:
    raise SystemExit(0)
raise SystemExit(1)
PY
  then
    echo "BACKUP_SKIPPED function=${FUNCTION_NAME} region=${REGION} reason=no_change latest_backup_dir=${LATEST_DIR} backup_dir=${LATEST_DIR}"
    exit 0
  fi
fi

mkdir -p "$BACKUP_DIR"

echo "[1/7] Coletando metadata base"
cp "${TMP_DIR}/get-function-current.json" "${BACKUP_DIR}/get-function.json"
cp "${TMP_DIR}/configuration-current.json" "${BACKUP_DIR}/configuration.json"

# Optional APIs: function can have no policy, aliases, or versions beyond $LATEST.
aws lambda get-policy --function-name "$FUNCTION_NAME" --region "$REGION" > "${BACKUP_DIR}/policy.json" 2>/dev/null || echo '{"Policy":null}' > "${BACKUP_DIR}/policy.json"
aws lambda list-aliases --function-name "$FUNCTION_NAME" --region "$REGION" > "${BACKUP_DIR}/aliases.json"
aws lambda list-versions-by-function --function-name "$FUNCTION_NAME" --region "$REGION" > "${BACKUP_DIR}/versions.json"
aws lambda list-tags --resource "$FUNCTION_ARN" --region "$REGION" > "${BACKUP_DIR}/tags.json"

echo "[2/7] Baixando codigo implantado"
curl -L "$CODE_URL" -o "${BACKUP_DIR}/code.zip" >/dev/null

echo "[3/7] Gerando checksums"
sha256sum "${BACKUP_DIR}/code.zip" > "${BACKUP_DIR}/code.zip.sha256"
CODE_SHA256="$(awk '{print $1}' "${BACKUP_DIR}/code.zip.sha256")"

echo "[4/7] Gerando manifesto"
python3 - "${BACKUP_DIR}" "${FUNCTION_NAME}" "${FUNCTION_ARN}" "${REGION}" "${ACCOUNT_ID}" "${TIMESTAMP}" "${CODE_SHA256}" "$CURRENT_AWS_CODE_SHA256" "$CURRENT_CONFIG_FINGERPRINT" <<'PY'
import json
import os
import sys

(
    backup_dir,
    function_name,
    function_arn,
    region,
    account_id,
    timestamp,
    code_sha256,
    aws_code_sha256,
    config_fingerprint,
) = sys.argv[1:]

with open(os.path.join(backup_dir, "configuration.json"), "r", encoding="utf-8") as f:
    cfg = json.load(f)
with open(os.path.join(backup_dir, "versions.json"), "r", encoding="utf-8") as f:
    versions = json.load(f)
with open(os.path.join(backup_dir, "aliases.json"), "r", encoding="utf-8") as f:
    aliases = json.load(f)

manifest = {
    "backup_type": "lambda_single",
    "timestamp_utc": timestamp,
    "account_id": account_id,
    "region": region,
    "function_name": function_name,
    "function_arn": function_arn,
    "runtime": cfg.get("Runtime"),
    "handler": cfg.get("Handler"),
    "role": cfg.get("Role"),
    "timeout": cfg.get("Timeout"),
    "memory_size": cfg.get("MemorySize"),
    "architectures": cfg.get("Architectures"),
    "layers": cfg.get("Layers"),
    "vpc_config": cfg.get("VpcConfig"),
    "environment": cfg.get("Environment"),
    "last_modified": cfg.get("LastModified"),
    "code_sha256": code_sha256,
    "aws_code_sha256": aws_code_sha256,
    "config_fingerprint": config_fingerprint,
    "versions_count": len(versions.get("Versions", [])),
    "aliases_count": len(aliases.get("Aliases", [])),
    "files": [
        "get-function.json",
        "configuration.json",
        "policy.json",
        "aliases.json",
        "versions.json",
        "tags.json",
        "code.zip",
        "code.zip.sha256",
    ],
}

with open(os.path.join(backup_dir, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)
PY

echo "[5/7] Validando arquivos obrigatorios"
for f in get-function.json configuration.json policy.json aliases.json versions.json tags.json code.zip code.zip.sha256 manifest.json; do
  test -s "${BACKUP_DIR}/${f}"
done

echo "[6/7] Snapshot local pronto: ${BACKUP_DIR}"

if [ -n "$S3_BUCKET" ]; then
  echo "[7/7] Enviando para s3://${S3_BUCKET}/backups/lambda/${FUNCTION_NAME}/${TIMESTAMP}/"
  aws s3 cp "${BACKUP_DIR}/" "s3://${S3_BUCKET}/backups/lambda/${FUNCTION_NAME}/${TIMESTAMP}/" --recursive --region "$REGION" >/dev/null
  echo "Upload concluido"
else
  echo "[7/7] Upload S3 ignorado (bucket nao informado)"
fi

echo "BACKUP_OK function=${FUNCTION_NAME} region=${REGION} timestamp=${TIMESTAMP} backup_dir=${BACKUP_DIR}"
