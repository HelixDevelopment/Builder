#!/bin/bash

echo "Configuring Ollama to accept network connections..."
sudo mkdir -p /etc/systemd/system/ollama.service.d/
sudo tee /etc/systemd/system/ollama.service.d/environment.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama
sudo systemctl enable ollama

echo "Configuring firewall..."

if command -v ufw >/dev/null 2>&1; then

    if sudo ufw status | grep -q "Status: active"; then

        echo "UFW is active, allowing port 11434..."
        sudo ufw allow 11434/tcp
        sudo ufw reload

    else

        echo "UFW is inactive, no firewall rules added"
    fi

else

    echo "UFW not installed, skipping firewall configuration"
fi

echo "Verifying installation..."

sleep 3

if sudo systemctl is-active --quiet ollama; then
    
    echo "✅ Ollama service is running"
    
    if ss -tulpn | grep -q ":11434"; then
    
        echo "✅ Ollama is listening on port 11434"
        echo "✅ Installation completed! Ollama is ready and accessible from:"
        echo "   - Localhost: http://127.0.0.1:11434"
        echo "   - Network: http://$(hostname -I | awk '{print $1}'):11434"
        echo ""
        echo "You can test with: ollama run llama2"

    else
        
        echo "⚠️  Ollama is running but not listening on port 11434"
        echo "   Check configuration with: sudo systemctl status ollama"
    fi

else
    
    echo "❌ ERROR: Ollama service failed to start"
    echo "   Check logs with: sudo journalctl -u ollama -n 50"
    exit 1
fi