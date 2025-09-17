#!/usr/bin/env python3
"""
AI Memory & Learning System
Maintains persistent history of all fixes and builds institutional knowledge.
Supports all AI providers (Claude, Qwen, etc.) with shared memory.
"""

import json
import os
import sqlite3
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import hashlib

class AIMemory:
    def __init__(self, memory_dir: str = None):
        """Initialize AI memory system."""
        self.memory_dir = memory_dir or os.path.join(os.path.dirname(__file__), "..", "AIMemory")
        os.makedirs(self.memory_dir, exist_ok=True)
        
        self.db_path = os.path.join(self.memory_dir, "ai_memory.db")
        self.knowledge_base_path = os.path.join(self.memory_dir, "knowledge_base.json")
        
        self._init_database()
        self._load_knowledge_base()

    def _init_database(self):
        """Initialize SQLite database for fix history."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Create tables
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS fix_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                model_name TEXT NOT NULL,
                issue_type TEXT NOT NULL,
                issue_signature TEXT NOT NULL,  -- Hash of issue characteristics
                description TEXT NOT NULL,
                fixer_type TEXT NOT NULL,       -- Type of AI fixer used (claude, qwen, etc.)
                ai_analysis TEXT NOT NULL,      -- AI analysis from any provider
                fix_commands TEXT NOT NULL,     -- JSON array
                fix_success BOOLEAN NOT NULL,
                verification_success BOOLEAN NOT NULL,
                execution_time_seconds REAL,
                system_info TEXT NOT NULL,     -- JSON
                notes TEXT
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS issue_patterns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                pattern_name TEXT UNIQUE NOT NULL,
                issue_signature TEXT NOT NULL,
                success_count INTEGER DEFAULT 0,
                failure_count INTEGER DEFAULT 0,
                best_fix TEXT,              -- JSON of most successful fix
                last_seen TEXT,
                confidence_score REAL DEFAULT 0.0
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS model_characteristics (
                model_name TEXT PRIMARY KEY,
                total_tests INTEGER DEFAULT 0,
                success_rate REAL DEFAULT 0.0,
                common_issues TEXT,         -- JSON array
                effective_fixes TEXT,       -- JSON array  
                last_updated TEXT,
                performance_notes TEXT
            )
        ''')
        
        # Add migration for existing databases to add fixer_type column
        try:
            cursor.execute('ALTER TABLE fix_history ADD COLUMN fixer_type TEXT NOT NULL DEFAULT "claude"')
        except sqlite3.OperationalError:
            # Column already exists
            pass
        
        # Migrate claude_analysis column to ai_analysis
        try:
            cursor.execute('ALTER TABLE fix_history ADD COLUMN ai_analysis TEXT')
            cursor.execute('UPDATE fix_history SET ai_analysis = claude_analysis WHERE ai_analysis IS NULL')
            # Note: We keep claude_analysis for backward compatibility
        except sqlite3.OperationalError:
            # Column already exists or migration already done
            pass
        
        conn.commit()
        conn.close()

    def _load_knowledge_base(self):
        """Load accumulated knowledge base."""
        if os.path.exists(self.knowledge_base_path):
            with open(self.knowledge_base_path, 'r') as f:
                self.knowledge_base = json.load(f)
        else:
            self.knowledge_base = {
                "general_patterns": {},
                "model_specific_tips": {},
                "successful_strategies": {},
                "failure_patterns": {},
                "version": "1.0",
                "last_updated": datetime.now().isoformat()
            }

    def _save_knowledge_base(self):
        """Save knowledge base to disk."""
        self.knowledge_base["last_updated"] = datetime.now().isoformat()
        with open(self.knowledge_base_path, 'w') as f:
            json.dump(self.knowledge_base, f, indent=2)

    def generate_issue_signature(self, issue_data: Dict) -> str:
        """Generate a unique signature for an issue type."""
        # Create signature based on issue characteristics
        signature_parts = [
            issue_data.get('issue_type', ''),
            issue_data.get('model', '').split(':')[0],  # Model family
            issue_data.get('test_prompt', '')[:50],     # First 50 chars of prompt
            str(len(issue_data.get('actual_response', ''))),  # Response length category
        ]
        
        signature_text = "|".join(signature_parts)
        return hashlib.md5(signature_text.encode()).hexdigest()[:16]

    def query_similar_issues(self, issue_data: Dict, limit: int = 5) -> List[Dict]:
        """Find similar issues from history."""
        issue_signature = self.generate_issue_signature(issue_data)
        model_name = issue_data.get('model', '')
        issue_type = issue_data.get('issue_type', '')
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Query for exact matches first
        cursor.execute('''
            SELECT * FROM fix_history 
            WHERE issue_signature = ? 
            ORDER BY timestamp DESC LIMIT ?
        ''', (issue_signature, limit))
        exact_matches = cursor.fetchall()
        
        # Query for same model + issue type
        cursor.execute('''
            SELECT * FROM fix_history 
            WHERE model_name = ? AND issue_type = ? 
            ORDER BY fix_success DESC, timestamp DESC LIMIT ?
        ''', (model_name, issue_type, limit))
        model_matches = cursor.fetchall()
        
        # Query for same issue type (any model)
        cursor.execute('''
            SELECT * FROM fix_history 
            WHERE issue_type = ? 
            ORDER BY fix_success DESC, timestamp DESC LIMIT ?
        ''', (issue_type, limit))
        type_matches = cursor.fetchall()
        
        conn.close()
        
        # Convert to dict format
        columns = ['id', 'timestamp', 'model_name', 'issue_type', 'issue_signature', 
                  'description', 'ai_analysis', 'fix_commands', 'fix_success', 
                  'verification_success', 'execution_time_seconds', 'system_info', 'notes']
        
        def row_to_dict(row):
            return dict(zip(columns, row))
        
        return {
            'exact_matches': [row_to_dict(row) for row in exact_matches],
            'model_matches': [row_to_dict(row) for row in model_matches],
            'type_matches': [row_to_dict(row) for row in type_matches]
        }

    def get_model_insights(self, model_name: str) -> Dict:
        """Get accumulated insights about a specific model."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get model characteristics
        cursor.execute('SELECT * FROM model_characteristics WHERE model_name = ?', (model_name,))
        result = cursor.fetchone()
        
        if result:
            columns = ['model_name', 'total_tests', 'success_rate', 'common_issues', 
                      'effective_fixes', 'last_updated', 'performance_notes']
            model_data = dict(zip(columns, result))
            
            # Parse JSON fields
            model_data['common_issues'] = json.loads(model_data['common_issues'] or '[]')
            model_data['effective_fixes'] = json.loads(model_data['effective_fixes'] or '[]')
        else:
            model_data = {
                'model_name': model_name,
                'total_tests': 0,
                'success_rate': 0.0,
                'common_issues': [],
                'effective_fixes': [],
                'last_updated': None,
                'performance_notes': None
            }
        
        # Get recent fix history for this model
        cursor.execute('''
            SELECT issue_type, fix_success, ai_analysis, timestamp 
            FROM fix_history 
            WHERE model_name = ? 
            ORDER BY timestamp DESC LIMIT 10
        ''', (model_name,))
        recent_history = cursor.fetchall()
        
        conn.close()
        
        model_data['recent_history'] = [
            {
                'issue_type': row[0],
                'success': bool(row[1]),
                'analysis': row[2],
                'timestamp': row[3]
            }
            for row in recent_history
        ]
        
        return model_data

    def build_context_for_ai(self, issue_data: Dict) -> str:
        """Build rich historical context for AI analysis."""
        model_name = issue_data.get('model', '')
        issue_type = issue_data.get('issue_type', '')
        
        # Get similar issues
        similar_issues = self.query_similar_issues(issue_data, limit=3)
        
        # Get model insights
        model_insights = self.get_model_insights(model_name)
        
        # Build context string
        context_parts = []
        
        # Add historical context header
        context_parts.append("=== HISTORICAL CONTEXT FROM AI MEMORY ===")
        
        # Add model-specific insights
        if model_insights['total_tests'] > 0:
            context_parts.append(f"\n📊 Model History for {model_name}:")
            context_parts.append(f"- Total previous tests: {model_insights['total_tests']}")
            context_parts.append(f"- Success rate: {model_insights['success_rate']:.1%}")
            
            if model_insights['common_issues']:
                context_parts.append(f"- Common issues: {', '.join(model_insights['common_issues'])}")
            
            if model_insights['effective_fixes']:
                context_parts.append(f"- Effective fixes: {', '.join(model_insights['effective_fixes'])}")
            
            if model_insights['performance_notes']:
                context_parts.append(f"- Notes: {model_insights['performance_notes']}")
        
        # Add similar issue patterns
        if similar_issues['exact_matches']:
            context_parts.append(f"\n🎯 Exact matches found ({len(similar_issues['exact_matches'])}):")
            for match in similar_issues['exact_matches'][:2]:
                success_str = "✅ SUCCESS" if match['fix_success'] else "❌ FAILED"
                # Try ai_analysis first, fallback to claude_analysis for backward compatibility
                analysis = match.get('ai_analysis') or match.get('claude_analysis', '')
                context_parts.append(f"- {success_str}: {analysis[:100]}...")
                if match['fix_success']:
                    try:
                        fix_commands_str = match['fix_commands']
                        if fix_commands_str and fix_commands_str.strip():
                            commands = json.loads(fix_commands_str)
                            context_parts.append(f"  Successful fix: {commands[0] if commands else 'N/A'}")
                        else:
                            context_parts.append(f"  Successful fix: No commands recorded")
                    except (json.JSONDecodeError, KeyError) as e:
                        context_parts.append(f"  Successful fix: [Command parse error]")
        
        if similar_issues['model_matches']:
            context_parts.append(f"\n🔧 Same model, same issue type ({len(similar_issues['model_matches'])}):")
            for match in similar_issues['model_matches'][:2]:
                success_str = "✅ SUCCESS" if match['fix_success'] else "❌ FAILED"
                context_parts.append(f"- {success_str}: {match['description'][:80]}...")
        
        # Add knowledge base insights
        if issue_type in self.knowledge_base.get('successful_strategies', {}):
            strategies = self.knowledge_base['successful_strategies'][issue_type]
            context_parts.append(f"\n💡 Known successful strategies for {issue_type}:")
            for strategy in strategies[:3]:
                context_parts.append(f"- {strategy}")
        
        context_parts.append("\n=== END HISTORICAL CONTEXT ===\n")
        
        return "\n".join(context_parts)

    def record_fix_attempt(self, issue_data: Dict, ai_response: Dict, 
                          fix_success: bool, verification_success: bool, 
                          execution_time: float, notes: str = None, fixer_type: str = "claude") -> int:
        """Record a fix attempt in the history."""
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Insert fix record
        analysis = ai_response.get('analysis', '')
        cursor.execute('''
            INSERT INTO fix_history 
            (timestamp, model_name, issue_type, issue_signature, description, 
             fixer_type, ai_analysis, fix_commands, fix_success, verification_success, 
             execution_time_seconds, system_info, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            datetime.now().isoformat(),
            issue_data.get('model', ''),
            issue_data.get('issue_type', ''),
            self.generate_issue_signature(issue_data),
            issue_data.get('description', ''),
            fixer_type,
            analysis,
            json.dumps(ai_response.get('fix_commands', [])),
            fix_success,
            verification_success,
            execution_time,
            json.dumps(issue_data.get('test_environment', {})),
            notes
        ))
        
        fix_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        # Update knowledge base
        self._update_knowledge_base(issue_data, ai_response, fix_success)
        
        return fix_id

    def _update_knowledge_base(self, issue_data: Dict, ai_response: Dict, success: bool):
        """Update the knowledge base with new learnings."""
        issue_type = issue_data.get('issue_type', '')
        model_name = issue_data.get('model', '')
        
        # Update successful strategies
        if success:
            if issue_type not in self.knowledge_base['successful_strategies']:
                self.knowledge_base['successful_strategies'][issue_type] = []
            
            strategy = ai_response.get('analysis', '')[:100]
            if strategy not in self.knowledge_base['successful_strategies'][issue_type]:
                self.knowledge_base['successful_strategies'][issue_type].append(strategy)
        
        # Update model-specific tips
        if model_name not in self.knowledge_base['model_specific_tips']:
            self.knowledge_base['model_specific_tips'][model_name] = []
        
        tip = f"{issue_type}: {'Success' if success else 'Failed'} - {ai_response.get('analysis', '')[:80]}"
        if tip not in self.knowledge_base['model_specific_tips'][model_name]:
            self.knowledge_base['model_specific_tips'][model_name].append(tip)
        
        # Keep only recent tips (last 10)
        self.knowledge_base['model_specific_tips'][model_name] = \
            self.knowledge_base['model_specific_tips'][model_name][-10:]
        
        self._save_knowledge_base()

    def get_memory_stats(self) -> Dict:
        """Get statistics about the memory system."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('SELECT COUNT(*) FROM fix_history')
        total_fixes = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(*) FROM fix_history WHERE fix_success = 1')
        successful_fixes = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(DISTINCT model_name) FROM fix_history')
        models_seen = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(DISTINCT issue_type) FROM fix_history')
        issue_types_seen = cursor.fetchone()[0]
        
        # Get recent activity (last 7 days)
        week_ago = (datetime.now() - timedelta(days=7)).isoformat()
        cursor.execute('SELECT COUNT(*) FROM fix_history WHERE timestamp > ?', (week_ago,))
        recent_activity = cursor.fetchone()[0]
        
        conn.close()
        
        return {
            'total_fixes_attempted': total_fixes,
            'successful_fixes': successful_fixes,
            'success_rate': successful_fixes / total_fixes if total_fixes > 0 else 0.0,
            'models_encountered': models_seen,
            'issue_types_seen': issue_types_seen,
            'recent_activity_7days': recent_activity,
            'knowledge_base_size': len(str(self.knowledge_base)),
            'memory_directory': self.memory_dir
        }

    def export_insights(self, output_file: str):
        """Export all accumulated insights to a readable report."""
        stats = self.get_memory_stats()
        
        report = {
            'generated_at': datetime.now().isoformat(),
            'statistics': stats,
            'knowledge_base': self.knowledge_base,
            'model_insights': {}
        }
        
        # Get insights for all models
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('SELECT DISTINCT model_name FROM fix_history')
        models = [row[0] for row in cursor.fetchall()]
        conn.close()
        
        for model in models:
            report['model_insights'][model] = self.get_model_insights(model)
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"📊 Insights exported to: {output_file}")


if __name__ == "__main__":
    """CLI interface for memory management."""
    import sys
    
    memory = AIMemory()
    
    if len(sys.argv) < 2:
        print("Usage: ai_memory.py <command> [args]")
        print("Commands:")
        print("  stats - Show memory statistics")
        print("  export <file> - Export insights report")
        print("  model <name> - Show model insights")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "stats":
        stats = memory.get_memory_stats()
        print("🧠 AI Memory Statistics:")
        for key, value in stats.items():
            print(f"  {key}: {value}")
    
    elif command == "export":
        if len(sys.argv) < 3:
            print("Usage: ai_memory.py export <output_file>")
            sys.exit(1)
        memory.export_insights(sys.argv[2])
    
    elif command == "model":
        if len(sys.argv) < 3:
            print("Usage: ai_memory.py model <model_name>")
            sys.exit(1)
        insights = memory.get_model_insights(sys.argv[2])
        print(f"🤖 Insights for {sys.argv[2]}:")
        print(json.dumps(insights, indent=2))
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)