# 🤖 AI-Powered Auto-Fix System with Multiple Providers

## Overview

The AI Model Testing Framework now supports **multiple AI providers** for intelligent auto-fixing. You can choose between different AI models to analyze test failures and generate fixes, each with their own strengths and capabilities.

## 🔧 Available AI Fixers

### 1. **Qwen 2.5 Coder** (Default)
- **Type**: Local AI model via Ollama
- **Strengths**: Code-specialized, fast, privacy-focused, no API costs
- **Requirements**: Qwen model installed in Ollama
- **Best for**: Code issues, quick fixes, offline environments

### 2. **Claude 3.5 Sonnet** 
- **Type**: Cloud AI service
- **Strengths**: Advanced reasoning, complex analysis, comprehensive solutions
- **Requirements**: Anthropic API key
- **Best for**: Complex issues, detailed analysis, when internet is available

## 🚀 Quick Start

### Basic Usage with Default Fixer (Qwen)
```bash
./test.sh --auto-fix
```

### Choose Specific Fixer
```bash
# Use Claude for advanced analysis
./test.sh --auto-fix --fixer=claude

# Use Qwen for fast local fixing (default)
./test.sh --auto-fix --fixer=qwen
```

### Check Available Fixers
```bash
./test.sh --help
```

## 📋 Setup Guide

### Setting Up Qwen (Local, Default)

1. **Install Ollama** (if not already installed):
   ```bash
   curl -fsSL https://ollama.ai/install.sh | sh
   ```

2. **Install Qwen 2.5 Coder model**:
   ```bash
   # For systems with 16GB+ RAM
   ollama pull qwen2.5-coder:32b
   
   # For systems with 8GB+ RAM
   ollama pull qwen2.5-coder:7b
   ```

3. **Verify installation**:
   ```bash
   ollama list
   ```
   You should see `qwen2.5-coder` in the list.

4. **Test the fixer**:
   ```bash
   ./Scripts/AutoFixers/autofix_manager.py list
   ```

### Setting Up Claude (Cloud)

1. **Get API Key from Anthropic**:
   - Go to: https://console.anthropic.com/
   - Create an account or sign in
   - Navigate to "API Keys" section
   - Click "Create Key"
   - Copy your API key

2. **Set Environment Variable**:
   ```bash
   # Temporary (this session only)
   export ANTHROPIC_API_KEY="your-api-key-here"
   
   # Permanent (add to your ~/.bashrc or ~/.zshrc)
   echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **Install Required Python Package**:
   ```bash
   pip3 install requests
   ```

4. **Verify setup**:
   ```bash
   ./Scripts/AutoFixers/autofix_manager.py list
   ```
   Claude should show as "✅ Available"

## 🎯 When to Use Which Fixer

### Use **Qwen** (Default) When:
- ✅ You want fast, local processing
- ✅ Privacy is important (no data leaves your machine)
- ✅ You have limited internet or API costs are a concern
- ✅ Dealing with straightforward code issues
- ✅ Working in offline environments

### Use **Claude** When:
- 🧠 You need advanced reasoning for complex issues
- 🧠 Problem requires deep analysis and context understanding
- 🧠 Previous simpler fixes haven't worked
- 🧠 You want detailed explanations and comprehensive solutions
- 🧠 Working with unusual or edge-case problems

## 📊 Memory & Learning System

Both fixers share the **same memory system**, which means:
- All fixes and attempts are stored together
- Knowledge learned from Claude can help Qwen and vice versa
- Historical context includes fixes from all providers
- Success rates and patterns are tracked across all fixers

### View Memory Statistics
```bash
./claude_memory.sh stats
```

### See Provider-Specific Performance
```bash
./Scripts/claude_memory_cli.sh patterns
```

## 🔍 Troubleshooting

### Qwen Issues

**Problem**: "Qwen model 'qwen2.5-coder:32b' is not available"
```bash
# Solution: Install the model
ollama pull qwen2.5-coder:32b

# Or use smaller version if you have limited RAM
ollama pull qwen2.5-coder:7b
```

**Problem**: "ollama: command not found"
```bash
# Solution: Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh
```

### Claude Issues

**Problem**: "❌ Analysis failed: API call failed"
```bash
# Check if API key is set
echo $ANTHROPIC_API_KEY

# If empty, set it:
export ANTHROPIC_API_KEY="your-api-key-here"
```

**Problem**: "ModuleNotFoundError: No module named 'requests'"
```bash
# Solution: Install requests
pip3 install requests
```

**Problem**: "API key invalid" or "403 Forbidden"
- Your API key may be incorrect
- Visit https://console.anthropic.com/ to verify/regenerate
- Ensure you have credits in your Anthropic account

### General Issues

**Problem**: "❌ Unsupported fixer type: xyz"
```bash
# Solution: Use supported fixer types
./test.sh --auto-fix --fixer=qwen    # or
./test.sh --auto-fix --fixer=claude
```

**Problem**: No fixers available
```bash
# Check status of all fixers
./Scripts/AutoFixers/autofix_manager.py list

# Set up at least one fixer following the setup guides above
```

## 🏗️ Advanced Usage

### Manual Fixer Testing
```bash
# Test a specific fixer on an issue file
./Scripts/AutoFixers/autofix_manager.py fix issue.json qwen
./Scripts/AutoFixers/autofix_manager.py fix issue.json claude
```

### View Fixer Information
```bash
./Scripts/AutoFixers/autofix_manager.py info qwen
./Scripts/AutoFixers/autofix_manager.py info claude
```

### Direct Fixer Usage
```bash
# Use Claude directly
./Scripts/AutoFixers/claude_autofix.py issue.json

# Use Qwen directly
./Scripts/AutoFixers/qwen_autofix.py issue.json
```

## 📈 Performance Tips

1. **Start with Qwen**: It's faster and free, good for most issues
2. **Escalate to Claude**: Use for complex problems that Qwen can't solve
3. **Check Memory**: Review `./claude_memory.sh stats` to see which fixer works best for your use cases
4. **Monitor Costs**: Claude usage incurs API costs, Qwen is free after initial setup

## 🔐 Security & Privacy

### Qwen (Local)
- ✅ All processing happens locally
- ✅ No data sent to external services
- ✅ Complete privacy and control

### Claude (Cloud)
- ⚠️ Issue data is sent to Anthropic's servers for analysis
- ⚠️ Follow your organization's data policies
- ✅ Anthropic has strong privacy policies and data handling practices
- ✅ API communications are encrypted

## 🤝 Contributing New Fixers

To add support for additional AI providers:

1. Create a new fixer file in `Scripts/AutoFixers/`
2. Implement the same interface as existing fixers:
   - `analyze_issue(issue_data)`
   - `apply_fix(fix_data)`
   - `verify_fix(issue_data, fix_data)`
3. Update `autofix_manager.py` to include your new fixer
4. Add setup instructions to this documentation

## 📞 Support

- **Issues**: Report problems at your project's issue tracker
- **Questions**: Check the troubleshooting section above
- **API Keys**: 
  - Anthropic Claude: https://console.anthropic.com/
  - Ollama setup: https://ollama.ai/

---

**🚀 Ready to experience intelligent multi-provider AI fixing!**