#!/usr/bin/env bash
# Safe wrapper: ./scripts/tf.sh <staging|production> <terraform args...>
#   STATE_BUCKET=lontong-tfstate-123456789012 ./scripts/tf.sh staging plan
# Refuses unknown environments and asks for confirmation before a production apply.
set -euo pipefail
env="${1:?usage: tf.sh <staging|production> <terraform args>}"; shift
[[ "$env" =~ ^(staging|production)$ ]] || { echo "unknown environment: $env" >&2; exit 2; }
: "${STATE_BUCKET:?set STATE_BUCKET to the bucket created by bootstrap/}"
cd "$(dirname "$0")/../environments/$env"
terraform init -input=false -backend-config="bucket=${STATE_BUCKET}" > /dev/null
if [[ "$env" == "production" && "${1:-}" == "apply" && -z "${CONFIRM_PRODUCTION:-}" ]]; then
  read -r -p "You are about to APPLY to PRODUCTION. Type 'production' to continue: " answer
  [[ "$answer" == "production" ]] || { echo "aborted"; exit 1; }
fi
exec terraform "$@"
