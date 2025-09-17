#!/bin/bash

#╔════════════════════════════════════════╗
#║      AI Memory Management CLI         ║
#║    Query & Manage Fix History         ║
#╚════════════════════════════════════════╝

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

show_help() {
    echo "AI Memory Management CLI"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  stats                    - Show memory statistics"
    echo "  model <name>             - Show insights for specific model"
    echo "  export [file]            - Export complete insights report"
    echo "  recent [days]            - Show recent fix activity"
    echo "  successful               - Show most successful fix strategies"
    echo "  patterns                 - Show identified issue patterns"
    echo "  cleanup [days]           - Clean up old records (default: 30 days)"
    echo "  help                     - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 stats"
    echo "  $0 model deepseek-r1:7b"
    echo "  $0 export claude_insights.json"
    echo "  $0 recent 7"
}

show_stats() {
    log_info "📊 AI Memory Statistics"
    python3 "$HERE/ai_memory.py" stats
}

show_model_insights() {
    local model_name="$1"
    if [ -z "$model_name" ]; then
        log_error "Model name required"
        echo "Usage: $0 model <model_name>"
        exit 1
    fi
    
    log_info "🤖 Model Insights: $model_name"
    python3 "$HERE/ai_memory.py" model "$model_name"
}

export_insights() {
    local output_file="${1:-ai_insights_$(date +%Y%m%d_%H%M%S).json}"
    log_info "📋 Exporting insights to: $output_file"
    python3 "$HERE/ai_memory.py" export "$output_file"
}

show_recent_activity() {
    local days="${1:-7}"
    log_info "📈 Recent activity (last $days days)"
    
    # Use Python to query recent activity
    python3 << EOF
import sys
sys.path.append('$HERE')
from ai_memory import AIMemory
from datetime import datetime, timedelta
import sqlite3

memory = AIMemory()
conn = sqlite3.connect(memory.db_path)
cursor = conn.cursor()

# Get recent fixes
cutoff_date = (datetime.now() - timedelta(days=$days)).isoformat()
cursor.execute('''
    SELECT timestamp, model_name, issue_type, fix_success, verification_success, claude_analysis
    FROM fix_history 
    WHERE timestamp > ? 
    ORDER BY timestamp DESC
''', (cutoff_date,))

results = cursor.fetchall()
if results:
    print(f"Found {len(results)} recent fix attempts:")
    for row in results:
        timestamp, model, issue_type, fix_success, verify_success, analysis = row
        status = "✅" if fix_success and verify_success else "❌"
        print(f"{status} {timestamp[:16]} | {model:20} | {issue_type:20} | {analysis[:50]}...")
else:
    print("No recent activity found")

conn.close()
EOF
}

show_successful_strategies() {
    log_info "🎯 Most Successful Fix Strategies"
    
    python3 << EOF
import sys
sys.path.append('$HERE')
from ai_memory import AIMemory
import sqlite3

memory = AIMemory()
conn = sqlite3.connect(memory.db_path)
cursor = conn.cursor()

# Get most successful strategies by issue type
cursor.execute('''
    SELECT issue_type, COUNT(*) as total, 
           SUM(CASE WHEN fix_success = 1 AND verification_success = 1 THEN 1 ELSE 0 END) as successful,
           claude_analysis
    FROM fix_history 
    WHERE fix_success = 1 AND verification_success = 1
    GROUP BY issue_type, claude_analysis
    ORDER BY successful DESC, total DESC
    LIMIT 10
''')

results = cursor.fetchall()
if results:
    print("Top successful strategies:")
    for i, (issue_type, total, successful, analysis) in enumerate(results, 1):
        success_rate = (successful / total) * 100 if total > 0 else 0
        print(f"{i:2}. {issue_type:20} | {successful:2}/{total:2} ({success_rate:4.1f}%) | {analysis[:60]}...")
else:
    print("No successful strategies recorded yet")

conn.close()
EOF
}

show_patterns() {
    log_info "🔍 Identified Issue Patterns"
    
    python3 << EOF
import sys
sys.path.append('$HERE')
from ai_memory import AIMemory
import sqlite3

memory = AIMemory()
conn = sqlite3.connect(memory.db_path)
cursor = conn.cursor()

# Get issue patterns
cursor.execute('''
    SELECT issue_type, model_name, COUNT(*) as occurrences,
           AVG(CASE WHEN fix_success = 1 AND verification_success = 1 THEN 1.0 ELSE 0.0 END) as success_rate
    FROM fix_history 
    GROUP BY issue_type, model_name
    HAVING occurrences > 1
    ORDER BY occurrences DESC, success_rate ASC
''')

results = cursor.fetchall()
if results:
    print("Issue patterns (recurring issues):")
    for issue_type, model, count, success_rate in results:
        rate_str = f"{success_rate*100:4.1f}%" if success_rate is not None else "N/A"
        status = "⚠️" if success_rate < 0.5 else "✅"
        print(f"{status} {model:20} | {issue_type:20} | {count:2}x | {rate_str} success")
else:
    print("No recurring patterns identified yet")

conn.close()
EOF
}

cleanup_old_records() {
    local days="${1:-30}"
    log_warning "🧹 Cleaning up records older than $days days"
    
    python3 << EOF
import sys
sys.path.append('$HERE')
from ai_memory import AIMemory
from datetime import datetime, timedelta
import sqlite3

memory = AIMemory()
conn = sqlite3.connect(memory.db_path)
cursor = conn.cursor()

# Count records to be deleted
cutoff_date = (datetime.now() - timedelta(days=$days)).isoformat()
cursor.execute('SELECT COUNT(*) FROM fix_history WHERE timestamp < ?', (cutoff_date,))
old_count = cursor.fetchone()[0]

if old_count > 0:
    print(f"Found {old_count} records older than $days days")
    
    # Delete old records
    cursor.execute('DELETE FROM fix_history WHERE timestamp < ?', (cutoff_date,))
    deleted = cursor.rowcount
    
    conn.commit()
    print(f"Deleted {deleted} old records")
else:
    print("No old records to clean up")

conn.close()
EOF
    
    log_success "Cleanup completed"
}

# Main command handling
case "${1:-help}" in
    "stats")
        show_stats
        ;;
    "model")
        show_model_insights "$2"
        ;;
    "export")
        export_insights "$2"
        ;;
    "recent")
        show_recent_activity "$2"
        ;;
    "successful")
        show_successful_strategies
        ;;
    "patterns")
        show_patterns
        ;;
    "cleanup")
        cleanup_old_records "$2"
        ;;
    "help"|*)
        show_help
        ;;
esac