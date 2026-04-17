#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/bootstrap-argocd.sh [kube-context]
# Example:
#   ./scripts/bootstrap-argocd.sh minikube

CONTEXT="${1:-}"
ARGO_NS="argocd"
APPS_DIR="argocd-apps"
ARGO_INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

if [[ -n "$CONTEXT" ]]; then
  echo "Switching kubectl context to: $CONTEXT"
  kubectl config use-context "$CONTEXT"
fi

echo "Using context: $(kubectl config current-context)"

echo "Ensuring namespace '$ARGO_NS' exists..."
kubectl get namespace "$ARGO_NS" >/dev/null 2>&1 || kubectl create namespace "$ARGO_NS"

echo "Installing/updating ArgoCD CRDs and core components..."
kubectl apply --server-side --force-conflicts -n "$ARGO_NS" -f "$ARGO_INSTALL_URL"

echo "Waiting for ArgoCD server deployment (this may take a few minutes on first pull)..."
if ! kubectl -n "$ARGO_NS" rollout status deploy/argocd-server --timeout=900s; then
  echo "ArgoCD server rollout did not complete in time. Recent pod status and events:"
  kubectl -n "$ARGO_NS" get pods -o wide || true
  kubectl -n "$ARGO_NS" describe deploy argocd-server || true
  kubectl -n "$ARGO_NS" get events --sort-by=.metadata.creationTimestamp || true
  exit 1
fi

echo "Waiting for Application CRD to be established..."
kubectl wait --for=condition=Established --timeout=120s crd/applications.argoproj.io

if [[ ! -d "$APPS_DIR" ]]; then
  echo "Directory '$APPS_DIR' not found. Skipping app definitions apply."
  exit 0
fi

echo "Applying ArgoCD Application manifests from '$APPS_DIR'..."
kubectl apply -f "$APPS_DIR/"

echo "ArgoCD bootstrap complete."
echo "To access UI: kubectl -n $ARGO_NS port-forward svc/argocd-server 8081:443"
