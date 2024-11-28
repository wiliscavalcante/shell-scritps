#!/bin/bash

NODE_NAME="<node-name>"

TOTAL_CPU=0
TOTAL_MEM=0
POD_COUNT=0

echo "Calculando a média de uso de CPU e Memória dos pods no node $NODE_NAME..."

# Obter os pods no node específico
PODS=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.nodeName=="'"$NODE_NAME"'") | "\(.metadata.namespace) \(.metadata.name)"')

if [ -z "$PODS" ]; then
    echo "Nenhum pod encontrado no node $NODE_NAME."
    exit 1
fi

echo "$PODS" | while read NAMESPACE POD; do
    # Debug: Mostra quais pods estão sendo processados
    echo "Processando pod: $POD no namespace: $NAMESPACE"

    # Obter o uso de CPU e Memória
    USAGE=$(kubectl top pod $POD -n $NAMESPACE --no-headers 2>/dev/null | awk '{print $2, $3}')
    CPU=$(echo $USAGE | awk '{print $1}' | sed 's/m//') # CPU em millicores
    MEM=$(echo $USAGE | awk '{print $2}' | sed 's/Mi//') # Memória em MiB

    # Debug: Exibir métricas coletadas
    echo "CPU: $CPU, MEM: $MEM"

    if [ -n "$CPU" ] && [ -n "$MEM" ]; then
        TOTAL_CPU=$((TOTAL_CPU + CPU))
        TOTAL_MEM=$((TOTAL_MEM + MEM))
        POD_COUNT=$((POD_COUNT + 1))
    fi
done

# Calcular as médias
if [ $POD_COUNT -gt 0 ]; then
    AVG_CPU=$((TOTAL_CPU / POD_COUNT))
    AVG_MEM=$((TOTAL_MEM / POD_COUNT))
    echo "Média de CPU por pod: ${AVG_CPU}m"
    echo "Média de Memória por pod: ${AVG_MEM}Mi"
else
    echo "Não foi possível calcular as médias. Verifique os pods no node $NODE_NAME."
fi
