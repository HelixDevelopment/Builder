#!/usr/bin/env python3
"""
DeepSeek-Powered Auto-Fix System
Integrates with local DeepSeek Coder model to intelligently analyze and fix test issues.
"""

import json
import os
import sys
import subprocess
import time
from typing import Dict, List, Optional

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ai_memory import AIMemory

class DeepSeekAutoFixer:
    def __init__(self, model_name: str = None):
        """Initialize DeepSeek auto-fixer with local model."""
        # Try to find available DeepSeek model if none specified
        if model_name is None:
            available_models = ["deepseek-coder:33b", "deepseek-coder:6.7b", "deepseek-coder:1.3b", "deepseek-coder:latest"]
            for model in available_models:
                if self._check_model_availability(model):
                    model_name = model
                    break
            
            if model_name is None:
                raise ValueError("No DeepSeek coder model available. Please install one: ollama pull deepseek-coder:6.7b")
        
        self.model_name = model_name
        
        # Check if specified model is available
        if not self._check_model_availability(self.model_name):
            raise ValueError(f"DeepSeek model '{model_name}' is not available. Please install it first.")
        
        # Initialize memory system (shared with other AI providers)
        self.memory = AIMemory()

    def _check_model_availability(self, model_name: str = None) -> bool:
        """Check if a DeepSeek model is available in Ollama."""
        check_model = model_name or self.model_name
        try:
            result = subprocess.run(['ollama', 'list'], capture_output=True, text=True)
            return check_model in result.stdout
        except Exception:
            return False

    def analyze_issue(self, issue_data: Dict) -> Dict:
        """Send issue to DeepSeek for analysis and fix recommendation with historical context."""
        
        # Get historical context from memory
        historical_context = self.memory.build_context_for_ai(issue_data)
        
        prompt = f"""You are an AI model testing expert with access to comprehensive historical data about previous fixes.

{historical_context}

Current Issue Details:
- Model: {issue_data['model']}
- Issue Type: {issue_data['issue_type']}
- Description: {issue_data['description']}
- Error Output: {issue_data.get('error_output', 'N/A')}
- Test Prompt: {issue_data.get('test_prompt', 'N/A')}
- Expected Pattern: {issue_data.get('expected_pattern', 'N/A')}
- Actual Response: {issue_data.get('actual_response', 'N/A')}

Context:
- This is part of an automated testing framework for AI models
- Models are run via Ollama
- Tests check if models respond correctly to prompts
- You have access to historical data about similar issues and their solutions
- Learn from past successes and failures shown in the historical context above

Based on the historical context and current issue, please analyze and provide:
1. Root cause analysis
2. Specific fix recommendations
3. Bash commands to implement the fix (if applicable)
4. How to verify the fix worked

Respond in JSON format:
{{
    "analysis": "detailed analysis of the root cause",
    "fix_type": "model_config|prompt_adjustment|system_fix|model_reinstall|other",
    "fix_commands": ["array", "of", "bash", "commands"],
    "verification_steps": ["array", "of", "verification", "steps"],
    "confidence": 0.95,
    "expected_outcome": "what should happen after applying the fix"
}}

Respond only with the JSON, no other text."""

        try:
            # Create a temporary file for the prompt
            temp_prompt_file = f"/tmp/deepseek_prompt_{int(time.time())}.txt"
            with open(temp_prompt_file, 'w') as f:
                f.write(prompt)
            
            # Call DeepSeek model via Ollama
            cmd = f'ollama run {self.model_name} < "{temp_prompt_file}"'
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120)
            
            # Clean up temp file
            os.unlink(temp_prompt_file)
            
            if result.returncode != 0:
                return {"error": f"DeepSeek model call failed: {result.stderr}"}
            
            response_text = result.stdout.strip()
            
            # Extract JSON from DeepSeek's response
            import re
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
            else:
                return {"error": "Could not parse DeepSeek's response", "raw_response": response_text}
                
        except subprocess.TimeoutExpired:
            return {"error": "DeepSeek model call timed out"}
        except Exception as e:
            return {"error": f"DeepSeek analysis failed: {str(e)}"}

    def apply_fix(self, fix_data: Dict) -> bool:
        """Apply the fix recommended by DeepSeek."""
        if "fix_commands" not in fix_data:
            print("❌ No fix commands provided")
            return False

        print(f"🔧 Applying fix: {fix_data.get('analysis', 'Unknown fix')}")
        
        for command in fix_data["fix_commands"]:
            print(f"🔨 Executing: {command}")
            try:
                result = subprocess.run(command, shell=True, capture_output=True, text=True)
                if result.returncode != 0:
                    print(f"❌ Command failed: {result.stderr}")
                    return False
                else:
                    print(f"✅ Command succeeded: {result.stdout}")
            except Exception as e:
                print(f"❌ Error executing command: {e}")
                return False
        
        return True

    def verify_fix(self, issue_data: Dict, fix_data: Dict) -> bool:
        """Verify that the fix actually resolved the issue."""
        print("🔍 Verifying fix...")
        
        # Re-run the specific test that failed
        model_name = issue_data['model']
        test_prompt = issue_data.get('test_prompt', 'What is 2+2? Answer briefly.')
        expected_pattern = issue_data.get('expected_pattern', '.*4.*')
        
        try:
            # Test the model with the same prompt
            test_cmd = f'echo "{test_prompt}" | ollama run {model_name}'
            result = subprocess.run(test_cmd, shell=True, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                print(f"❌ Model test failed: {result.stderr}")
                return False
            
            response = result.stdout.strip()
            
            # Check if response matches expected pattern
            import re
            if re.search(expected_pattern, response):
                print(f"✅ Fix verified: Model responded correctly")
                print(f"📝 Response: {response[:100]}...")
                return True
            else:
                print(f"❌ Fix verification failed: Response doesn't match pattern")
                print(f"📝 Response: {response[:100]}...")
                return False
                
        except subprocess.TimeoutExpired:
            print("❌ Fix verification timed out")
            return False
        except Exception as e:
            print(f"❌ Error during verification: {e}")
            return False


def main():
    """Main function for CLI usage with memory tracking."""
    if len(sys.argv) < 2:
        print("Usage: deepseek_autofix.py <issue_json_file> [model_name]")
        sys.exit(1)
    
    issue_file = sys.argv[1]
    model_name = sys.argv[2] if len(sys.argv) > 2 else None
    
    try:
        with open(issue_file, 'r') as f:
            issue_data = json.load(f)
    except Exception as e:
        print(f"❌ Error reading issue file: {e}")
        sys.exit(1)
    
    # Initialize DeepSeek auto-fixer
    try:
        fixer = DeepSeekAutoFixer(model_name)
    except ValueError as e:
        print(f"❌ {e}")
        sys.exit(1)
    
    start_time = time.time()
    
    # Show memory stats
    memory_stats = fixer.memory.get_memory_stats()
    print(f"🧠 Memory: {memory_stats['total_fixes_attempted']} fixes tried, {memory_stats['success_rate']:.1%} success rate")
    
    # Analyze issue with DeepSeek (including historical context)
    print(f"🤖 Analyzing issue with DeepSeek {fixer.model_name} (with historical context)...")
    fix_data = fixer.analyze_issue(issue_data)
    
    if "error" in fix_data:
        print(f"❌ DeepSeek analysis failed: {fix_data['error']}")
        # Record the failed analysis
        fixer.memory.record_fix_attempt(
            issue_data, fix_data, False, False, 
            time.time() - start_time, "Analysis failed", "deepseek"
        )
        sys.exit(1)
    
    print(f"📋 DeepSeek's analysis: {fix_data['analysis']}")
    print(f"🎯 Confidence: {fix_data.get('confidence', 'Unknown')}")
    
    # Apply the fix
    fix_success = fixer.apply_fix(fix_data)
    
    if fix_success:
        print("✅ Fix applied successfully")
        
        # Verify the fix
        verification_success = fixer.verify_fix(issue_data, fix_data)
        
        if verification_success:
            print("🎉 Fix verified successfully!")
            # Record successful fix
            fix_id = fixer.memory.record_fix_attempt(
                issue_data, fix_data, True, True,
                time.time() - start_time, "Fix applied and verified successfully", "deepseek"
            )
            print(f"💾 Success recorded in memory (ID: {fix_id})")
            sys.exit(0)
        else:
            print("❌ Fix verification failed")
            # Record partially successful fix
            fixer.memory.record_fix_attempt(
                issue_data, fix_data, True, False,
                time.time() - start_time, "Fix applied but verification failed", "deepseek"
            )
            sys.exit(1)
    else:
        print("❌ Fix application failed")
        # Record failed fix
        fixer.memory.record_fix_attempt(
            issue_data, fix_data, False, False,
            time.time() - start_time, "Fix application failed", "deepseek"
        )
        sys.exit(1)


if __name__ == "__main__":
    main()