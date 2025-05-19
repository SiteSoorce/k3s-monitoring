#!/bin/bash
set -eo pipefail

echo "=== K3S LOGGING STACK DEBUGGER ==="
echo "Datum: $(date)"
echo "Cluster: $(sudo kubectl config current-context)"
echo ""

# 1. Cluster status
echo "### 1. CLUSTER STATUS ###"
sudo kubectl get nodes -o wide || echo "Fout bij ophalen nodes"
sudo kubectl top nodes || echo "Metrics niet beschikbaar"
echo ""

# 2. Namespace overzicht
echo "### 2. LOGGING NAMESPACE ###"
sudo kubectl get all -n logging || echo "Fout bij ophalen logging resources"
sudo kubectl get pvc -n logging || echo "Geen PVCs gevonden"
echo ""

# 3. Gedetailleerde pod status
echo "### 3. POD DETAILS ###"
pods=$(sudo kubectl get pods -n logging -o name || true)
for pod in $pods; do
  echo "---- ${pod} STATUS ----"
  sudo kubectl get -n logging "$pod" -o wide || echo "Pod ophalen mislukt"
  echo ""
  
  echo "---- ${pod} EVENTS ----"
  sudo kubectl describe -n logging "$pod" | grep -A 20 "Events:" || echo "Geen events gevonden"
  echo ""
  
  echo "---- ${pod} LOGS (laatste 15 regels) ----"
  sudo kubectl logs -n logging "$pod" --tail=15 || echo "Logs ophalen mislukt"
  echo ""
done

# 4. Netwerkconfiguratie
echo "### 4. NETWORK CONFIGURATION ###"
echo "---- Services ----"
sudo kubectl get svc -n logging -o wide
echo ""

echo "---- Endpoints ----"
for svc in $(sudo kubectl get svc -n logging -o name); do
  echo "${svc}:"
  sudo kubectl get -n logging "$svc" -o jsonpath='{.spec.selector}' 2>/dev/null || echo "Geen selectors"
  sudo kubectl get -n logging "$svc" -o jsonpath='{.spec.ports[*].targetPort}' 2>/dev/null || echo "Geen ports"
  echo ""
done

# 5. Storage analyse
echo "### 5. STORAGE ANALYSIS ###"
loki_pod=$(sudo kubectl get pod -n logging -l app=loki -o name | head -1 || true)
if [ -n "$loki_pod" ]; then
  echo "---- Loki Storage ----"
  sudo kubectl exec -n logging "$loki_pod" -- sh -c 'df -h; echo ""; ls -la /var/loki/ 2>/dev/null || echo "GEEN STORAGE"'
  echo ""
  
  echo "---- Loki Data Health ----"
  sudo kubectl exec -n logging "$loki_pod" -- wget -qO- "http://localhost:3100/ready" 2>/dev/null || echo "Loki health check mislukt"
  echo ""
fi

# 6. Promtail config validatie
echo "### 6. PROMTAIL VALIDATION ###"
prom_pod=$(sudo kubectl get pod -n logging -l app=promtail -o name | head -1 || true)
if [ -n "$prom_pod" ]; then
  echo "---- Config Check ----"
  sudo kubectl exec -n logging "$prom_pod" -- cat /etc/promtail/promtail.yaml || echo "Config niet gevonden"
  echo ""
  
  echo "---- Discovered Targets ----"
  sudo kubectl exec -n logging "$prom_pod" -- wget -qO- http://localhost:9080/targets 2>/dev/null || echo "Targets check mislukt"
  echo ""
  
  echo "---- Scraped Files ----"
  sudo kubectl exec -n logging "$prom_pod" -- sh -c 'find /var/log/pods -type f -name "*.log" | head -10' 2>/dev/null || echo "Geen logbestanden gevonden"
  echo ""
fi

# 7. Loki data query
echo "### 7. LOKI DATA CHECK ###"
if [ -n "$loki_pod" ]; then
  echo "---- Recente Logs ----"
  sudo kubectl exec -n logging "$loki_pod" -- wget -qO- "http://localhost:3100/loki/api/v1/query?query={namespace=\"logging\"}&limit=5" 2>/dev/null || echo "Query mislukt"
  echo ""
  
  echo "---- Label Values ----"
  sudo kubectl exec -n logging "$loki_pod" -- wget -qO- "http://localhost:3100/loki/api/v1/label" 2>/dev/null || echo "Label query mislukt"
  echo ""
fi

# 8. Grafana status
echo "### 8. GRAFANA STATUS ###"
grafana_pod=$(sudo kubectl get pod -n logging -l app=grafana -o name | head -1 || true)
if [ -n "$grafana_pod" ]; then
  echo "---- Datasources ----"
  sudo kubectl exec -n logging "$grafana_pod" -- sh -c 'ls -la /etc/grafana/provisioning/datasources/; cat /etc/grafana/provisioning/datasources/*' 2>/dev/null || echo "Geen datasources gevonden"
  echo ""
  
  echo "---- Health Check ----"
  sudo kubectl exec -n logging "$grafana_pod" -- wget -qO- http://localhost:3000/api/health 2>/dev/null || echo "Grafana health check mislukt"
  echo ""
fi

# 9. Diepe systeem checks
echo "### 9. SYSTEM CHECKS ###"
echo "---- Kubelet Logs ----"
sudo journalctl -u k3s --no-pager -n 20 2>/dev/null || echo "Kubelet logs niet beschikbaar"
echo ""

echo "---- Docker/Containerd Status ----"
sudo systemctl status containerd --no-pager 2>/dev/null || sudo systemctl status docker --no-pager 2>/dev/null || echo "Container runtime status niet beschikbaar"
echo ""

echo "---- Disk Usage ----"
sudo df -h
echo ""

echo "---- Memory Usage ----"
sudo free -h
echo ""

echo "=== DEBUGGING COMPLETE ==="