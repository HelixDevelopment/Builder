#!/usr/bin/env python3
"""
Auto-Fix Manager
Manages multiple AI providers for intelligent issue fixing.
Supports Claude, Qwen, and other AI models for analyzing and fixing test issues.
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

class AutoFixManager:
    def __init__(self, fixer_type: str = "deepseek"):
        """Initialize auto-fix manager with specified fixer type."""
        self.fixer_type = fixer_type.lower()
        self.supported_fixers = ["claude", "qwen", "deepseek"]
        
        if self.fixer_type not in self.supported_fixers:
            raise ValueError(f"Unsupported fixer type: {fixer_type}. Supported: {', '.join(self.supported_fixers)}")
        
        # Initialize the appropriate fixer
        self.fixer = self._initialize_fixer()
        
        # Initialize memory system
        self.memory = AIMemory()

    def _initialize_fixer(self):
        """Initialize the appropriate fixer based on type."""
        if self.fixer_type == "claude":
            from claude_autofix import ClaudeAutoFixer
            return ClaudeAutoFixer()
        elif self.fixer_type == "qwen":
            from qwen_autofix import QwenAutoFixer
            return QwenAutoFixer()
        elif self.fixer_type == "deepseek":
            from deepseek_autofix import DeepSeekAutoFixer
            return DeepSeekAutoFixer()
        else:
            raise ValueError(f"Fixer type '{self.fixer_type}' not implemented")

    def analyze_issue(self, issue_data: Dict) -> Dict:
        """Analyze issue using the selected fixer."""
        return self.fixer.analyze_issue(issue_data)

    def apply_fix(self, fix_data: Dict) -> bool:
        """Apply fix using the selected fixer."""
        return self.fixer.apply_fix(fix_data)

    def verify_fix(self, issue_data: Dict, fix_data: Dict) -> bool:
        """Verify fix using the selected fixer."""
        return self.fixer.verify_fix(issue_data, fix_data)

    def get_fixer_info(self) -> Dict:
        """Get information about the current fixer."""
        if self.fixer_type == "claude":
            return {
                "name": "Claude 3.5 Sonnet",
                "type": "cloud",
                "provider": "Anthropic",
                "description": "Advanced AI assistant with strong reasoning capabilities"
            }
        elif self.fixer_type == "qwen":
            return {
                "name": "Qwen 2.5 Coder",
                "type": "local",
                "provider": "Alibaba",
                "description": "Local coding-specialized model via Ollama"
            }
        elif self.fixer_type == "deepseek":
            return {
                "name": "DeepSeek Coder",
                "type": "local",
                "provider": "DeepSeek",
                "description": "Local code-specialized model with strong debugging capabilities"
            }
        else:
            return {"name": "Unknown", "type": "unknown", "provider": "Unknown", "description": "Unknown fixer"}

    @classmethod
    def list_available_fixers(cls) -> List[Dict]:
        """List all available fixer types with their status."""
        fixers = []
        
        # Check Claude availability
        has_api_key = bool(os.getenv('ANTHROPIC_API_KEY'))
        has_requests = cls._check_python_package('requests')
        claude_available = has_api_key and has_requests
        
        claude_setup_help = []
        if not has_api_key:
            claude_setup_help.append("Get API key: https://console.anthropic.com/")
        if not has_requests:
            claude_setup_help.append("Install requests: pip3 install requests")
        
        fixers.append({
            "name": "claude",
            "display_name": "Claude 3.5 Sonnet",
            "type": "cloud",
            "available": claude_available,
            "requirements": "ANTHROPIC_API_KEY environment variable and requests package",
            "setup_help": claude_setup_help
        })
        
        # Check DeepSeek availability
        has_deepseek_33b = cls._check_ollama_model("deepseek-coder:33b")
        has_deepseek_6b = cls._check_ollama_model("deepseek-coder:6.7b")
        has_deepseek_1b = cls._check_ollama_model("deepseek-coder:1.3b")
        has_ollama = cls._check_ollama_available()
        deepseek_available = has_deepseek_33b or has_deepseek_6b or has_deepseek_1b
        
        deepseek_setup_help = []
        if not has_ollama:
            deepseek_setup_help.append("Install Ollama: curl -fsSL https://ollama.ai/install.sh | sh")
        elif not deepseek_available:
            deepseek_setup_help.append("Install model: ollama pull deepseek-coder:6.7b")
        
        fixers.append({
            "name": "deepseek",
            "display_name": "DeepSeek Coder",
            "type": "local",
            "available": deepseek_available,
            "requirements": "DeepSeek model installed in Ollama (deepseek-coder:33b, 6.7b, or 1.3b)",
            "setup_help": deepseek_setup_help
        })
        
        # Check Qwen availability
        has_qwen_32b = cls._check_ollama_model("qwen2.5-coder:32b")
        has_qwen_7b = cls._check_ollama_model("qwen2.5-coder:7b")
        qwen_available = has_qwen_32b or has_qwen_7b
        
        qwen_setup_help = []
        if not has_ollama:
            qwen_setup_help.append("Install Ollama: curl -fsSL https://ollama.ai/install.sh | sh")
        elif not qwen_available:
            qwen_setup_help.append("Install model: ollama pull qwen2.5-coder:7b")
        
        fixers.append({
            "name": "qwen",
            "display_name": "Qwen 2.5 Coder",
            "type": "local",
            "available": qwen_available,
            "requirements": "Qwen model installed in Ollama (qwen2.5-coder:32b or qwen2.5-coder:7b)",
            "setup_help": qwen_setup_help
        })
        
        return fixers

    @staticmethod
    def _check_python_package(package_name: str) -> bool:
        """Check if a Python package is available."""
        try:
            __import__(package_name)
            return True
        except ImportError:
            return False

    @staticmethod
    def _check_ollama_available() -> bool:
        """Check if Ollama is installed and available."""
        try:
            result = subprocess.run(['ollama', '--version'], capture_output=True, text=True)
            return result.returncode == 0
        except Exception:
            return False

    @staticmethod
    def _check_ollama_model(model_name: str) -> bool:
        """Check if an Ollama model is available."""
        try:
            result = subprocess.run(['ollama', 'list'], capture_output=True, text=True)
            return model_name in result.stdout
        except Exception:
            return False


def main():
    """Main function for CLI usage."""
    if len(sys.argv) < 2:
        print("Usage: autofix_manager.py <command> [args]")
        print()
        print("Commands:")
        print("  fix <issue_json_file> [fixer_type] - Fix an issue using specified fixer")
        print("  list - List available fixers and their status")
        print("  info <fixer_type> - Get information about a specific fixer")
        print()
        print("Available fixer types: claude, qwen (default: qwen)")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "list":
        print("🔧 Available Auto-Fixers:")
        print()
        fixers = AutoFixManager.list_available_fixers()
        for fixer in fixers:
            status = "✅ Available" if fixer["available"] else "❌ Not Available"
            print(f"  {fixer['name']:10} | {fixer['display_name']:20} | {fixer['type']:6} | {status}")
            if not fixer["available"]:
                print(f"             Requirements: {fixer['requirements']}")
                if fixer.get("setup_help"):
                    print(f"             Setup steps:")
                    for step in fixer["setup_help"]:
                        print(f"               - {step}")
        print()
        
        # Show documentation link
        print("📖 For detailed setup instructions, see: AI_FIXERS.md")
        print()
    
    elif command == "info":
        if len(sys.argv) < 3:
            print("Usage: autofix_manager.py info <fixer_type>")
            sys.exit(1)
        
        fixer_type = sys.argv[2]
        try:
            manager = AutoFixManager(fixer_type)
            info = manager.get_fixer_info()
            print(f"🤖 Fixer Information: {fixer_type}")
            print(f"  Name: {info['name']}")
            print(f"  Type: {info['type']}")
            print(f"  Provider: {info['provider']}")
            print(f"  Description: {info['description']}")
        except ValueError as e:
            print(f"❌ {e}")
            sys.exit(1)
    
    elif command == "fix":
        if len(sys.argv) < 3:
            print("Usage: autofix_manager.py fix <issue_json_file> [fixer_type]")
            sys.exit(1)
        
        issue_file = sys.argv[2]
        fixer_type = sys.argv[3] if len(sys.argv) > 3 else "qwen"
        
        try:
            with open(issue_file, 'r') as f:
                issue_data = json.load(f)
        except Exception as e:
            print(f"❌ Error reading issue file: {e}")
            sys.exit(1)
        
        # Initialize auto-fix manager
        try:
            manager = AutoFixManager(fixer_type)
        except ValueError as e:
            print(f"❌ {e}")
            sys.exit(1)
        
        start_time = time.time()
        
        # Show fixer info and memory stats
        fixer_info = manager.get_fixer_info()
        memory_stats = manager.memory.get_memory_stats()
        
        print(f"🤖 Using {fixer_info['name']} ({fixer_info['type']}) for auto-fix")
        print(f"🧠 Memory: {memory_stats['total_fixes_attempted']} fixes tried, {memory_stats['success_rate']:.1%} success rate")
        
        # Analyze issue
        print(f"🔍 Analyzing issue with {fixer_info['name']}...")
        fix_data = manager.analyze_issue(issue_data)
        
        if "error" in fix_data:
            print(f"❌ Analysis failed: {fix_data['error']}")
            manager.memory.record_fix_attempt(
                issue_data, fix_data, False, False, 
                time.time() - start_time, f"Analysis failed with {fixer_type}", fixer_type
            )
            sys.exit(1)
        
        print(f"📋 Analysis: {fix_data['analysis']}")
        print(f"🎯 Confidence: {fix_data.get('confidence', 'Unknown')}")
        
        # Apply the fix
        fix_success = manager.apply_fix(fix_data)
        
        if fix_success:
            print("✅ Fix applied successfully")
            
            # Verify the fix
            verification_success = manager.verify_fix(issue_data, fix_data)
            
            if verification_success:
                print("🎉 Fix verified successfully!")
                # Record successful fix
                fix_id = manager.memory.record_fix_attempt(
                    issue_data, fix_data, True, True,
                    time.time() - start_time, f"Fix applied and verified successfully with {fixer_type}", fixer_type
                )
                print(f"💾 Success recorded in memory (ID: {fix_id})")
                sys.exit(0)
            else:
                print("❌ Fix verification failed")
                manager.memory.record_fix_attempt(
                    issue_data, fix_data, True, False,
                    time.time() - start_time, f"Fix applied but verification failed with {fixer_type}", fixer_type
                )
                sys.exit(1)
        else:
            print("❌ Fix application failed")
            manager.memory.record_fix_attempt(
                issue_data, fix_data, False, False,
                time.time() - start_time, f"Fix application failed with {fixer_type}", fixer_type
            )
            sys.exit(1)
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()