#!/bin/bash
set -euo pipefail

echo "=== KUBERNETES LOGGING DEBUGGER ==="
echo "Datum: $(date)"

# 1. Cluster status
echo "### 1. CLUSTER STATUS ###"
kubectl get nodes -o wide || echo "Fout bij ophalen van cluster nodes"
echo ""

# 2. Logging namespace
echo "### 2. LOGGING NAMESPACE ###"
kubectl get all -n logging || echo "Fout: namespace 'logging' niet gevonden"
echo ""

# 3. Pod details
echo "### 3. POD DETAILS ###"
pods=$(kubectl get pods -n logging -o name || true)
for pod in $pods; do
  echo "---- ${pod} ----"
  kubectl get -n logging "$pod" -o wide || echo "Pod ophalen mislukt"
  kubectl describe -n logging "$pod" | grep -A 10 "Status:" || echo "Status niet gevonden"
  echo ""
done

# 4. Log generator check
echo "### 4. LOG GENERATOR OUTPUT ###"
gen_pod=$(kubectl get pod -n logging -l app=log-generator -o name | head -1 || true)
if [ -n "$gen_pod" ]; then
  kubectl exec -n logging "$gen_pod" -- sh -c 'tail -n 5 /var/log/app/app.log 2>/dev/null || echo "GEEN LOGS GEVONDEN"'
else
  echo "Log-generator pod niet gevonden"
fi
echo ""

# 5. Promtail status
echo "### 5. PROMTAIL STATUS ###"
prom_pod=$(kubectl get pod -n logging -l app=promtail -o name | head -1 || true)
if [ -n "$prom_pod" ]; then
  echo "--- Logbestanden in /var/log/pods/ ---"
  kubectl exec -n logging "$prom_pod" -- sh -c 'ls -la /var/log/pods/*/*/*.log 2>/dev/null || echo "GEEN LOGBESTANDEN"'

  echo "--- Promtail Targets ---"
  kubectl exec -n logging "$prom_pod" -- sh -c 'wget -qO- http://localhost:9080/targets 2>/dev/null || echo "TARGETS CHECK MISLUKT"'

  echo "--- Promtail Logs ---"
  kubectl logs -n logging "$prom_pod" --tail=10 || echo "Logs ophalen mislukt"
else
  echo "Promtail pod niet gevonden"
fi
echo ""

# 6. Loki status
echo "### 6. LOKI STATUS ###"
loki_pod=$(kubectl get pod -n logging -l app=loki -o name | head -1 || true)
if [ -n "$loki_pod" ]; then
  echo "--- Storage ---"
  kubectl exec -n logging "$loki_pod" -- sh -c 'ls -la /tmp/loki/ 2>/dev/null || echo "GEEN STORAGE"'

  echo "--- Ontvangen Logs ---"
  kubectl exec -n logging "$loki_pod" -- sh -c 'wget -qO- "http://localhost:3100/loki/api/v1/query?query={namespace=\"logging\"}&limit=5" 2>/dev/null || echo "QUERY MISLUKT"'
else
  echo "Loki pod niet gevonden"
fi
echo ""

echo "=== DEBUG VOLTOOID ==="
