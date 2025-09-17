# 🤖 Claude-Powered Auto-Fix System with Memory

## Overview

The AI Model Testing Framework now includes **Claude-powered intelligent auto-fixing with persistent memory** that can analyze test failures, learn from previous fixes, and generate increasingly effective solutions over time using AI reasoning and institutional knowledge.

## How It Works

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Test Fails    │ -> │  Query Memory    │ -> │ Claude Analysis │
│                 │    │  Database        │    │ + History       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Learn & Store │ <- │  Verify Fix      │ <- │   Apply Fix     │
│   Knowledge     │    │  (Re-test)       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                       ┌──────────────────┐
                       │ Full Confirmation│
                       │ Test All Models  │
                       └──────────────────┘
```

## 🧠 Memory & Learning System

### **Persistent Knowledge Base**
- **SQLite Database**: Stores all fix attempts, successes, and failures
- **Issue Signatures**: Identifies similar problems across time
- **Model Characteristics**: Learns specific quirks of each model
- **Success Patterns**: Tracks what fixes work best for each issue type

### **Historical Context**
- **Similar Issues**: Finds exact matches and related problems
- **Model History**: Shows past performance and common issues
- **Successful Strategies**: Highlights proven solutions
- **Failure Patterns**: Avoids repeating unsuccessful approaches

## Setup

### 1. Get Claude API Key
```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

### 2. Verify Dependencies
```bash
python3 --version  # Should be 3.6+
pip3 install requests
```

## Usage

### Basic Auto-Fix
```bash
./test.sh --auto-fix
```

### What Claude Can Fix

1. **Model Configuration Issues**
   - Incorrect model parameters
   - Performance optimizations
   - Memory/VRAM adjustments

2. **Prompt Engineering**
   - Improve test prompts for better responses
   - Adjust expected patterns
   - Handle model-specific quirks

3. **System Configuration**
   - Ollama service issues
   - Environment problems
   - Dependency conflicts

4. **Response Analysis**
   - Understand why models give unexpected responses
   - Suggest alternative testing approaches
   - Fix response parsing logic

## Example Flow

```bash
./test.sh --auto-fix
```

**Output:**
```
🤖 Claude-powered intelligent auto-fix enabled
🧠 Memory: 15 fixes tried, 87.2% success rate
🔍 Claude analyzing: deepseek-r1:7b (with historical context)
📋 Claude found 2 similar issues in history
✅ Claude successfully fixed: deepseek-r1:7b
💾 Success recorded in memory (ID: 16)
🎯 Running final confirmation test of ALL models...
🔍 Confirming: qwen3:8b
✅ CONFIRMED: qwen3:8b
🔍 Confirming: deepseek-r1:7b  
✅ CONFIRMED: deepseek-r1:7b
🎉 ALL MODELS CONFIRMED WORKING!
```

## Claude Analysis Example

When Claude analyzes an issue, it provides:

```json
{
    "analysis": "The model is giving a verbose response instead of brief answer",
    "fix_type": "prompt_adjustment", 
    "fix_commands": [
        "# Update test prompt to be more specific",
        "echo 'What is 2+2? Give only the number.' > new_prompt.txt"
    ],
    "verification_steps": [
        "Test model with new prompt",
        "Verify response matches expected pattern"
    ],
    "confidence": 0.9,
    "expected_outcome": "Model will give brief numerical answer"
}
```

## Benefits

### 🧠 **Intelligent Analysis**
- Claude understands context and nuance
- Provides detailed root cause analysis
- Suggests optimal solutions

### 🔧 **Dynamic Fixes**
- Custom solutions for each specific issue
- Not limited to pre-programmed responses
- Learns from error patterns

### ✅ **Verification Built-in**
- Claude's fixes are automatically verified
- Re-tests the specific failing scenario
- Ensures fix actually works

### 🎯 **Complete Validation**
- After fixes, runs full confirmation test
- Tests ALL models to ensure no regressions
- Guarantees system-wide stability

## Fallback Behavior

If Claude auto-fix is unavailable:
- Falls back to basic rule-based fixes
- Still performs model installation
- Continues with standard test-fix-retest loop

## 🧠 Memory Management

### View Memory Statistics
```bash
./Scripts/claude_memory_cli.sh stats
```

### Query Model Insights
```bash
./Scripts/claude_memory_cli.sh model deepseek-r1:7b
```

### Export Complete Knowledge Base
```bash
./Scripts/claude_memory_cli.sh export my_insights.json
```

### View Recent Activity
```bash
./Scripts/claude_memory_cli.sh recent 7  # Last 7 days
```

### Show Successful Strategies
```bash
./Scripts/claude_memory_cli.sh successful
```

### Identify Issue Patterns
```bash
./Scripts/claude_memory_cli.sh patterns
```

### Clean Up Old Records
```bash
./Scripts/claude_memory_cli.sh cleanup 30  # Older than 30 days
```

## 📊 Memory Benefits

### **Improving Over Time**
- **First Run**: Basic rule-based fixes only
- **After 5 fixes**: Claude has initial patterns to reference
- **After 20 fixes**: Claude can identify recurring issues and optimal solutions
- **After 50+ fixes**: Claude becomes highly effective with deep institutional knowledge

### **Learning Capabilities**
- **Model-Specific Quirks**: Learns that Model X often needs specific timeouts
- **Issue Patterns**: Recognizes that "timeout" + "large model" = increase VRAM settings
- **Fix Evolution**: Improves fix strategies based on success/failure history
- **Context Awareness**: Understands system-specific patterns and environment factors

### **Cross-Session Memory**
- Fixes persist across test runs
- Knowledge accumulates over weeks/months
- Team knowledge sharing through exported insights
- Historical trend analysis

## Debugging

Enable debug mode:
```bash
CLAUDE_DEBUG=1 ./test.sh --auto-fix
```

View Claude's issue analysis:
```bash
cat Tests/$(date +%Y-%m-%d)/*/claude_issue.json
```

View memory database:
```bash
sqlite3 ClaudeMemory/claude_memory.db ".tables"
```

## Security

- API key is only used for Claude analysis
- Memory stored locally in SQLite database
- No sensitive data sent to external services
- Issue data is anonymized
- All operations logged for transparency

---

**🚀 Ready to experience AI-powered intelligent testing with persistent memory!**