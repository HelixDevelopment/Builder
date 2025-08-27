#!/bin/bash

total_ram_mib=$(grep MemTotal /proc/meminfo | awk '{print $2 / 1024}')
total_ram_gb=$(echo "$total_ram_mib / 1024" | bc -l | awk '{printf "%.1f\n", $1}')
vram_info_mib=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
vram_info_gb=$(echo "$vram_info_mib / 1024" | bc -l | awk '{printf "%.1f\n", $1}')

echo "System Diagnostics:"
echo "-------------------"
echo "Total System RAM: $total_ram_gb GB ($total_ram_mib MiB)"
echo "GPU VRAM: $vram_info_gb GB ($vram_info_mib MiB)"
echo ""
echo "Ollama Model Recommendations:"
echo "-----------------------------"

if (( $(echo "$vram_info_gb >= 24" | bc -l) )); then
    
    echo "-> Your GPU is a beast! You can likely run 70B+ models."

    echo "ERROR: Not yet implemented!"
    exit 1


elif (( $(echo "$vram_info_gb >= 12" | bc -l) )); then
    
    echo "-> Great GPU. Target 13B-34B models comfortably."

    echo "ERROR: Not yet implemented!"
    exit 1

elif (( $(echo "$vram_info_gb >= 8" | bc -l) )); then
    
    echo "-> Good GPU. Target 7B-13B models."

    echo "ERROR: Not yet implemented!"
    exit 1

else
    
    echo "-> Your GPU VRAM is limited. Focus on 7B models or smaller."

    echo "ERROR: Not yet implemented!"
    exit 1
fi

echo "Note: Use 'ollama run <model_name>' to test. The system will use RAM if VRAM is full, but it will be slower."

