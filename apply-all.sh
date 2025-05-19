#!/bin/bash
set -e

echo "Applying logging namespace..."
kubectl apply -f 00-namespace.yaml

echo "Applying Loki configuration..."
kubectl apply -f 01-loki/

echo "Applying Promtail configuration..."
kubectl apply -f 02-promtail/

echo "Applying log generator..."
kubectl apply -f 03-log-generator/

echo "Applying Grafana..."
kubectl apply -f 04-grafana/

echo "All components deployed successfully!"