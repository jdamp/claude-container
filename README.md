# claude-code-cluster

Kubernetes manifests and Docker image for running a persistent [Claude Code](https://claude.ai/code) CLI session in a k3s homelab cluster. The session stays alive between mobile app connections via Anthropic's session sync infrastructure.

## What's in the box

- **Docker image** (`claude-code/`) — Alpine-based image with the Claude Code CLI, Python/uv, Typst, and an SSH server.
- **Kubernetes manifests** (`claude-code/k8s/`) — Deployment, PVCs, NetworkPolicy, and SSH NodePort service.
- **Squid sidecar** — Forward proxy that restricts outbound traffic to an explicit domain allowlist.
- **GitHub Actions** (`.github/workflows/build.yaml`) — Builds and publishes the image to GHCR, tagged with the installed Claude Code version. Runs daily to pick up new releases.

## Prerequisites

- A running k3s (or compatible) cluster
- `kubectl` configured to talk to it
- A container registry (the workflow uses `ghcr.io/<your-github-username>/claude-code`)

## Deploy

**1. Update the image reference** in `claude-code/k8s/deployment.yaml`:
```yaml
image: ghcr.io/<your-github-username>/claude-code:latest
```

**2. Add your SSH public key** to `claude-code/k8s/configmap-ssh.yaml`.

**3. Apply the manifests:**
```bash
kubectl apply -f claude-code/k8s/namespace.yaml
kubectl apply -f claude-code/k8s/
```

**4. Authenticate Claude Code** (one-time interactive OAuth):
```bash
kubectl exec -it -n claude-code deploy/claude-code -c claude-code -- claude
```

## SSH access

SSH is exposed on NodePort `30022`. Connect from any WireGuard-connected client:
```bash
ssh -p 30022 claude@<node-ip>
```

Find the node IP with `kubectl get nodes -o wide`. Host keys are persisted on the config PVC so the fingerprint is stable across pod restarts.

To update authorized keys, edit `claude-code/k8s/configmap-ssh.yaml` and restart:
```bash
kubectl apply -f claude-code/k8s/configmap-ssh.yaml
kubectl rollout restart deployment -n claude-code claude-code
```

## Egress allowlist

Squid restricts outbound traffic to domains listed in `claude-code/k8s/configmap-squid.yaml` under `allowed-domains.txt`. Add a domain and restart the deployment to allow new traffic:
```bash
kubectl rollout restart deployment -n claude-code claude-code
```

## CI/CD

The GitHub Actions workflow builds and pushes to `ghcr.io/<owner>/claude-code` on:
- Pushes to `main` that change the Dockerfile, entrypoint, or workflow
- A daily schedule (06:00 UTC) to pick up new Claude Code releases
- Manual trigger via `workflow_dispatch`

Images are tagged with both `latest` and the exact Claude Code version (e.g. `1.2.3`).
