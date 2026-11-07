---
name: mifosx-kubernetes
description: Install, verify and remove Mifos X (Apache Fineract backend + Mifos web app + MariaDB or PostgreSQL) on a Kubernetes cluster using the manifests in this repository's kubernetes/ directory. Use when the user asks to install, deploy, start, stop, uninstall or troubleshoot Mifos X or Fineract on Kubernetes, MicroK8s, kind, minikube, k3s or Docker Desktop Kubernetes.
license: MPL-2.0
compatibility: Needs kubectl (or microk8s kubectl) with access to a running cluster, curl, and a clone of https://github.com/openMF/mifosx-platform. Not for production; the database has no persistent storage.
---

# Install Mifos X on Kubernetes

The manifests live in `kubernetes/mariadb/` and `kubernetes/postgresql/`. This skill applies them with
plain `kubectl`, waits on real readiness signals, and proves the install with API calls. Do not report
success until every check in step 5 passes.

Run every command from the repository root, one command per call, exactly as written. The commands
are for PostgreSQL. For MariaDB, or for MicroK8s, substitute:

| In the commands | MariaDB | MicroK8s |
|---|---|---|
| `kubernetes/postgresql/` | `kubernetes/mariadb/` | |
| `fineractdb-configmap.yml` | `fineractmysql-configmap.yml` | |
| `fineractdb-deployment.yml` | `fineractmysql-deployment.yml` | |
| `deploy/fineractdb` | `deploy/fineractmysql` | |
| `create-db-secret.sh postgresql` | `create-db-secret.sh mariadb` | |
| `kubectl` | | `microk8s kubectl` |
| `sh .agents/...` | | `KUBECTL="microk8s kubectl" sh .agents/...` |

If your agent loaded this skill from another directory, run the scripts in its `scripts/` directory.

## 1. Preflight

Run these and stop with the error if any fails:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get ingressclass
```

Then check for an existing install. Any output means Mifos X is already installed:

```bash
kubectl get deploy fineract-server --ignore-not-found
```

- The cluster must be reachable, with at least one node `Ready`.
- If the user did not name a database, ask. If they have no preference, use PostgreSQL.
- Without an `nginx` ingress class the Ingress objects are created but do nothing. The install still
  works; step 5 doesn't need the ingress. Tell the user the browser hostnames won't resolve.
- The pods request about 1.4 CPU and 2 GiB memory in total, and Fineract can grow to its 2 GiB limit.
  A node smaller than 2 CPU / 4 GiB will leave pods `Pending`.
- If Mifos X is already installed, don't reinstall without asking; reinstalling means running step 7
  first.

## 2. Database secret and config

Create the database secret with the script. It generates a random password, keeps an existing secret
(a new password on an existing database locks Fineract out), and never prints the password. If the
script fails, show its error and stop. Don't create the secret any other way.

```bash
sh .agents/skills/mifosx-kubernetes/scripts/create-db-secret.sh postgresql
kubectl apply -f kubernetes/postgresql/fineractdb-configmap.yml
kubectl apply -f kubernetes/postgresql/mifos-webapp-ingress.yml -f kubernetes/postgresql/fineract-ingress.yml
```

## 3. Start in order: database, Fineract, web app

Fineract fails if the database is not accepting connections, so wait between steps. Do not rely on
`startup.sh` for this. It only works on MicroK8s and only waits for pods to be `Running`.

```bash
kubectl apply -f kubernetes/postgresql/fineractdb-deployment.yml
kubectl rollout status deploy/fineractdb --timeout=300s
kubectl apply -f kubernetes/postgresql/fineract-server-deployment.yml
kubectl rollout status deploy/fineract-server --timeout=300s
kubectl apply -f kubernetes/postgresql/mifos-webapp-deployment.yml
kubectl rollout status deploy/mifos-webapp --timeout=300s
```

`rollout status` only means the containers started. The deployments have no readiness probes, so
Fineract still needs 2-5 minutes to run its database migrations after this returns. Step 5 is the real check.

## 4. Watch for early failures

```bash
kubectl get pods -o wide
```

| Symptom | Cause and fix |
|---|---|
| `Pending` | Not enough CPU or memory on the node. Show `kubectl describe pod <pod>` events to the user |
| `ImagePullBackOff` | No internet access, a registry rate limit, or an image that differs from the manifest. Show `kubectl describe pod <pod>`. If the deployment's image differs from the manifest, `kubectl apply -f` the manifest again |
| `CrashLoopBackOff` on fineract-server | Check `kubectl logs deploy/fineract-server --tail=100`. A connection refused error means the DB was not ready; `kubectl rollout restart deploy/fineract-server` |
| `password authentication failed` or `Access denied for user` in the Fineract log | The secret changed after the database started. Don't edit, delete or recreate the secret. Tell the user; with their approval, uninstall (step 7) and install again, which deletes all data |
| `ClassNotFoundException: org.mariadb.jdbc.Driver` | The `mariadb-jdbc-driver` init container didn't put the driver in `/app/plugins`. Check `kubectl logs deploy/fineract-server -c mariadb-jdbc-driver`; the node needs access to repo1.maven.org |
| `OOMKilled` on fineract-server | The container hit its memory limit. With `-Xmx1G` it needs the 2Gi limit in `fineract-server-deployment.yml`; check that the file wasn't changed |
| Ingress apply fails: `Snippet directives are disabled` | The cluster's ingress-nginx rejects `configuration-snippet` annotations. Check that the ingress files are current from this repository |

## 5. Verify (all must pass)

Run the check script. It can take up to 8 minutes, so give the command a 10-minute timeout. It exits
2 if Mifos X isn't installed or local port 18080 or 19090 is already in use:

```bash
sh .agents/skills/mifosx-kubernetes/scripts/verify-install.sh
```

It exits 0 only if all three checks pass:

1. **Fineract health** reports `"status":"UP"`. Fineract runs its database migrations after
   `rollout status` returns, so the script polls inside the pod every 10 seconds for up to 7
   minutes (about 2 minutes on a laptop). It doesn't poll through a port-forward, because
   `kubectl port-forward` exits on the first refused connection.
2. **Login** as `mifos` / `password` on the `default` tenant returns `"authenticated":true`, through
   a temporary port-forward to `svc/fineract-server`.
3. **The web app** returns HTTP `200`, through a temporary port-forward to `svc/mifos-webapp`.

The script stops its port-forwards when it exits. Report a table with each pod's status and the
three results. If a check fails, give the last 50 lines of the failing pod's log instead of a success
message.

## 6. Tell the user how to open it

The web app is built to call `https://fineract.mifos.local`, so a browser login needs the ingress:

1. Add to `/etc/hosts`: `<node or ingress IP>   webapp.mifos.local fineract.mifos.local`
   (`127.0.0.1` on kind or Docker Desktop when ports 80/443 are mapped to the host).
2. Open `https://fineract.mifos.local` once and accept the self-signed certificate. Otherwise the web
   app's API calls fail silently.
3. Open `https://webapp.mifos.local` and log in as `mifos` / `password`.

## 7. Uninstall

```bash
kubectl delete -f kubernetes/postgresql/mifos-webapp-deployment.yml -f kubernetes/postgresql/fineract-server-deployment.yml -f kubernetes/postgresql/fineractdb-deployment.yml -f kubernetes/postgresql/fineractdb-configmap.yml -f kubernetes/postgresql/mifos-webapp-ingress.yml -f kubernetes/postgresql/fineract-ingress.yml --ignore-not-found
kubectl delete secret fineract-tenants-db-secret --ignore-not-found
kubectl get pods
```

The last command should show no `fineract` or `mifos` pods. All data is lost on uninstall.

## Rules

- Change the cluster only through the commands above. Don't edit the manifests unless the user asks.
- Don't use `startup.sh` or `shutdown.sh` in `kubernetes/`; the steps here replace them.
- Secrets: never choose, type or hard-code a password, and never write credentials to a file. Don't
  print or decode the secret: `kubectl get secret` is fine; `-o yaml`, `-o json`, `jsonpath` on `.data`
  and `base64 -d` are not. Don't delete or recreate the secret while Mifos X is installed.
- The default credentials `mifos` / `password` are for a local demo. Tell the user to change them
  before the install is reachable by anyone else.
