#!/bin/sh
# Create the Mifos X database secret with a random 16-character password.
# The password is never printed, passed as a command-line argument or written to disk.
# Usage: create-db-secret.sh postgresql|mariadb   (KUBECTL="microk8s kubectl" on MicroK8s)
set +x
# zsh doesn't split $KUBECTL ("microk8s kubectl") into words unless it emulates sh.
[ -z "${ZSH_VERSION:-}" ] || emulate sh
set -eu

case "${1:-}" in
  postgresql) db_user=postgres ;;
  mariadb) db_user=root ;;
  *) echo "usage: $0 postgresql|mariadb" >&2; exit 2 ;;
esac

KUBECTL="${KUBECTL:-kubectl}"
name=fineract-tenants-db-secret

# Fails (set -e) if the cluster is unreachable, instead of treating that as "no secret".
existing=$($KUBECTL get secret "$name" --ignore-not-found -o name)
if [ -n "$existing" ]; then
  # Reads only the username key, which is not secret.
  existing_user=$($KUBECTL get secret "$name" -o 'go-template={{index .data "username" | base64decode}}')
  if [ "$existing_user" != "$db_user" ]; then
    echo "error: $existing is for user '$existing_user', but $1 needs '$db_user'." >&2
    echo "It belongs to another install. Uninstall that one first; don't overwrite the secret." >&2
    exit 1
  fi
  echo "$existing already exists, keeping it. A new password would lock Fineract out of the existing database."
  exit 0
fi

password=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
if [ "${#password}" -ne 16 ]; then
  echo "error: could not read 16 random characters from /dev/urandom" >&2
  exit 1
fi

# printf is a shell builtin, so the password never appears in a process list.
printf '%s' "$password" | $KUBECTL create secret generic "$name" \
  --from-literal=username="$db_user" --from-file=password=/dev/stdin
