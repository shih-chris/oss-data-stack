#!/usr/bin/env bash
set -euo pipefail

shutdown() {
  if [[ -n "${DAEMON_PID:-}" ]]; then
    kill "${DAEMON_PID}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${HEALTH_PID:-}" ]]; then
    kill "${HEALTH_PID}" >/dev/null 2>&1 || true
  fi
}

trap shutdown TERM INT

mkdir -p /var/log/dagster

dagster-daemon run -m orchestration.definitions --log-format json \
  > >(tee -a /var/log/dagster/daemon.log) \
  2>&1 &
DAEMON_PID="$!"
export DAGSTER_DAEMON_PID="${DAEMON_PID}"

python scripts/daemon_health.py &
HEALTH_PID="$!"

wait -n "${DAEMON_PID}" "${HEALTH_PID}"
EXIT_CODE="$?"
shutdown
exit "${EXIT_CODE}"
