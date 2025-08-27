#!/bin/bash

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

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

install_models() {

    if [ -z "$1" ]; then
    
        echo "ERROR: Models parameter is mandatory"
        exit 1
    fi

    MODELS="$1"

    if ! test -e "$MODELS"; then

        echo "ERROR: Models file not foun '$MODELS'"
        exit 1
    fi

    total_models=0
    success_count=0
    fail_count=0

    while IFS= read -r model_name; do

        if [[ -z "$model_name" || "$model_name" =~ ^# ]]; then
            
            continue
        fi
        
        ((total_models++))
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Pulling: $model_name"
        
        if ollama pull "$model_name"; then
            
            echo "✓ Success: $model_name"
            ((success_count++))

        else
            
            echo "✗ FAILED: $model_name"
            ((fail_count++))
        fi
        
        echo "------------------------------------"
        
    done < "$MODELS"

    echo "=============================================="
    echo "INSTALLATION SUMMARY:" 
    echo "Total models processed: $total_models" 
    echo "Successfully installed: $success_count" 
    echo "Failed: $fail_count" 

    if [ $fail_count -eq 0 ]; then
        
        echo "🎉 All models were installed successfully!" 
        return 0
        
    else
        
        echo "⚠️  Some models failed to install. Check the log for details." 
        return 1
    fi
}

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

    MODELS="$HERE/Recipes/Models/7B"
fi

echo "Note: Use 'ollama run <model_name>' to test. The system will use RAM if VRAM is full, but it will be slower."

install_models "$MODELS"

