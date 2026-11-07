#!/bin/sh
# Check a Mifos X install: Fineract health, login on the default tenant, web app page.
# Waits up to 7 minutes for Fineract to report UP. Exits 0 only if all checks pass,
# 1 if a check fails, 2 if Mifos X isn't installed or a local port is taken.
# Usage: verify-install.sh   (KUBECTL="microk8s kubectl" on MicroK8s)
# No set -e: a failing check must still reach the report below.
# zsh doesn't split $KUBECTL or $pids into words unless it emulates sh.
[ -z "${ZSH_VERSION:-}" ] || emulate sh
set -u

KUBECTL="${KUBECTL:-kubectl}"
HEALTH=http://localhost:8080/fineract-provider/actuator/health
FINERACT_PORT=18080
WEBAPP_PORT=19090
WAIT_SECONDS=420

# All curl calls go to localhost; a proxy from the environment must not handle them.
local_curl() { curl --noproxy '*' "$@"; }

$KUBECTL get deploy fineract-server mifos-webapp >/dev/null || {
  echo "error: deploy/fineract-server or deploy/mifos-webapp not found; is Mifos X installed?" >&2
  exit 2
}
for port in $FINERACT_PORT $WEBAPP_PORT; do
  # curl exits 7 only when nothing accepts the connection. Any other result, including a
  # listener that doesn't speak HTTP, means the port is taken.
  local_curl -s -m 1 -o /dev/null "http://localhost:$port/"
  if [ $? -ne 7 ]; then
    echo "error: localhost:$port is already in use; stop whatever is listening there" >&2
    exit 2
  fi
done

health=""
deadline=$(( $(date +%s) + WAIT_SECONDS ))
while :; do
  health=$($KUBECTL exec deploy/fineract-server -- wget -qO- -T 5 "$HEALTH" 2>&1)
  case "$health" in *'"status":"UP"'*) break ;; esac
  [ "$(date +%s)" -ge "$deadline" ] && break
  sleep 10
done

pids=""
cleanup() { [ -z "$pids" ] || kill $pids 2>/dev/null; return 0; }
trap cleanup EXIT
trap 'exit 130' INT TERM
$KUBECTL port-forward svc/fineract-server "$FINERACT_PORT:8080" >/dev/null 2>&1 &
pids="$!"
$KUBECTL port-forward svc/mifos-webapp "$WEBAPP_PORT:9090" >/dev/null 2>&1 &
pids="$pids $!"

wait_for_port() { # wait_for_port <port>: up to 15 s for the forward to accept connections
  n=0
  while [ $n -lt 15 ]; do
    local_curl -s -m 1 -o /dev/null "http://localhost:$1/" && return 0
    n=$((n + 1)); sleep 1
  done
  return 1
}
wait_for_port $FINERACT_PORT; fineract_forward=$?
wait_for_port $WEBAPP_PORT; webapp_forward=$?

auth=""; web=""
[ $fineract_forward -eq 0 ] && auth=$(local_curl -s -m 20 -X POST \
  "http://localhost:$FINERACT_PORT/fineract-provider/api/v1/authentication" \
  -H 'Content-Type: application/json' -H 'Fineract-Platform-TenantId: default' \
  -d '{"username":"mifos","password":"password"}')
[ $webapp_forward -eq 0 ] && web=$(local_curl -s -m 20 -o /dev/null -w '%{http_code}' "http://localhost:$WEBAPP_PORT/")

failed=0
report() { # report <check> <ok:0|1> <detail>
  if [ "$2" -eq 0 ]; then echo "PASS  $1: $3"; else echo "FAIL  $1: $3"; failed=1; fi
}
case "$health" in
  *'"status":"UP"'*) report "Fineract health" 0 "UP" ;;
  *) report "Fineract health" 1 "not UP after 7 minutes ($(printf '%s' "${health:-no response}" | head -c 200))" ;;
esac
if [ $fineract_forward -ne 0 ]; then report "Login mifos/default tenant" 1 "port-forward to svc/fineract-server failed"
else case "$auth" in
  *'"authenticated":true'*) report "Login mifos/default tenant" 0 '"authenticated":true' ;;
  *) report "Login mifos/default tenant" 1 "$(printf '%s' "${auth:-no response}" | head -c 200)" ;;
esac; fi
if [ $webapp_forward -ne 0 ]; then report "Web app" 1 "port-forward to svc/mifos-webapp failed"
elif [ "$web" = 200 ]; then report "Web app" 0 "HTTP 200"
else report "Web app" 1 "HTTP ${web:-none}"; fi

echo
$KUBECTL get pods -l 'tier in (fineractdb,fineractmysql,backend,frontend)'
exit $failed
