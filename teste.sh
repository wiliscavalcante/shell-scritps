NODE_NAME="<nome-do-node>"

kubectl top pod --all-namespaces --no-headers | grep $NODE_NAME | awk '{cpu+=$3; mem+=$4; count++} END {if (count > 0) printf "Node: %s, Total de Pods: %d, Média de CPU: %.2fm, Média de Memória: %.2fMi\n", "'$NODE_NAME'", count, cpu/count, mem/count; else print "Nenhum pod encontrado no node '$NODE_NAME'."}'
