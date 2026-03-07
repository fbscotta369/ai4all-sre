#!/usr/bin/env python3
import sys
import re
import os
from datetime import datetime

# Design Tokens (Premium SRE Aesthetic)
COLORS = {
    "bg": "#0f172a",
    "card": "rgba(30, 41, 59, 0.7)",
    "primary": "#38bdf8",
    "success": "#22c55e",
    "failure": "#ef4444",
    "warning": "#f59e0b",
    "text": "#f1f5f9",
    "text_muted": "#94a3b8"
}

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SRE Laboratory | E2E Visual Report</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <style>
        :root {{
            --bg: {bg};
            --card: {card};
            --primary: {primary};
            --success: {success};
            --failure: {failure};
            --warning: {warning};
            --text: {text};
            --text-muted: {text_muted};
        }}
        
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        
        body {{
            background-color: var(--bg);
            color: var(--text);
            font-family: 'Inter', sans-serif;
            background-image: 
                radial-gradient(circle at 10% 20%, rgba(56, 189, 248, 0.05) 0%, transparent 20%),
                radial-gradient(circle at 80% 80%, rgba(34, 197, 94, 0.05) 0%, transparent 20%);
            min-height: 100vh;
            padding: 2rem;
        }}

        header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 3rem;
            border-bottom: 1px solid rgba(255,255,255,0.1);
            padding-bottom: 1rem;
        }}

        .logo {{
            font-size: 1.5rem;
            font-weight: 700;
            letter-spacing: -0.05em;
            background: linear-gradient(to right, var(--primary), #a855f7);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }}

        .meta {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.8rem;
            color: var(--text-muted);
        }}

        .grid {{
            display: grid;
            grid-template-columns: 1fr 2fr;
            gap: 2rem;
        }}

        .summary-card {{
            background: var(--card);
            backdrop-filter: blur(12px);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 1rem;
            padding: 1.5rem;
            display: flex;
            flex-direction: column;
            gap: 1rem;
        }}

        .stat-row {{
            display: flex;
            justify-content: space-between;
            padding: 0.5rem 0;
            border-bottom: 1px solid rgba(255,255,255,0.05);
        }}

        .stat-value {{ font-weight: 700; }}
        .stat-value.success {{ color: var(--success); }}
        .stat-value.failure {{ color: var(--failure); }}

        .test-list {{
            display: flex;
            flex-direction: column;
            gap: 0.75rem;
        }}

        .test-item {{
            background: rgba(255,255,255,0.03);
            border-radius: 0.5rem;
            padding: 1rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-left: 4px solid transparent;
            transition: transform 0.2s;
        }}

        .test-item:hover {{ transform: translateX(4px); }}
        .test-item.pass {{ border-left-color: var(--success); }}
        .test-item.fail {{ border-left-color: var(--failure); }}

        .test-name {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.9rem;
        }}

        .badge {{
            padding: 0.25rem 0.5rem;
            border-radius: 9999px;
            font-size: 0.7rem;
            font-weight: 700;
            text-transform: uppercase;
        }}

        .badge.pass {{ background: rgba(34, 197, 94, 0.2); color: var(--success); }}
        .badge.fail {{ background: rgba(239, 68, 68, 0.2); color: var(--failure); }}

        .battle-map {{
            margin-top: 3rem;
            background: var(--card);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 1rem;
            padding: 2rem;
        }}

        .map-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
            gap: 1rem;
        }}

        .node {{
            aspect-ratio: 1;
            background: rgba(255,255,255,0.05);
            border-radius: 0.5rem;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 0.5rem;
            font-size: 0.7rem;
            text-align: center;
            padding: 0.5rem;
        }}

        .node.active {{ border: 1px solid var(--success); box-shadow: 0 0 10px rgba(34, 197, 94, 0.3); }}
        .node.inactive {{ border: 1px solid var(--failure); }}
        
        .pulse {{
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--success);
            animation: pulse-animation 2s infinite;
        }}

        @keyframes pulse-animation {{
            0% {{ transform: scale(0.95); box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.7); }}
            70% {{ transform: scale(1); box-shadow: 0 0 0 10px rgba(34, 197, 94, 0); }}
            100% {{ transform: scale(0.95); box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }}
        }}
    </style>
</head>
<body>
    <header>
        <div class="logo">AI4ALL-SRE LABORATORY</div>
        <div class="meta">RUN_ID: {run_id} | TIMESTAMP: {timestamp}</div>
    </header>

    <div class="grid">
        <div class="summary-card">
            <h3>Test Summary</h3>
            <div class="stat-row">
                <span>Total Assertions</span>
                <span class="stat-value">{total}</span>
            </div>
            <div class="stat-row">
                <span>Passed</span>
                <span class="stat-value success">{passed}</span>
            </div>
            <div class="stat-row">
                <span>Failed</span>
                <span class="stat-value failure">{failed}</span>
            </div>
            <div class="stat-row">
                <span>Reliability Score</span>
                <span class="stat-value">{score}%</span>
            </div>
        </div>

        <div class="test-list">
            {test_items}
        </div>
    </div>

    <div class="battle-map">
        <h3 style="margin-bottom: 1.5rem;">Infrastructure Battle Map</h3>
        <div class="map-grid">
            {nodes}
        </div>
    </div>
</body>
</html>
"""

def parse_logs(input_text):
    tests = []
    # Strip ANSI escape codes
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_text = ansi_escape.sub('', input_text)
    
    # Pattern to match: "  Testing Name... [ PASS ]" or "  Endpoint: Name... [ FAIL ]"
    matches = re.finditer(r'(Testing|Endpoint:)\s+(.*?)\.\.\.\s+\[\s*(PASS|FAIL)\s*\]', clean_text)
    for match in matches:
        tests.append({
            "status": match.group(3),
            "name": match.group(2).strip()
        })
    return tests

def generate_report(tests):
    total = len(tests)
    passed = len([t for t in tests if t["status"] == "PASS"])
    failed = total - passed
    score = int((passed / total) * 100) if total > 0 else 0
    
    test_items_html = ""
    nodes_html = ""
    
    for t in tests:
        status_class = t["status"].lower()
        test_items_html += f"""
        <div class="test-item {status_class}">
            <span class="test-name">{t["name"]}</span>
            <span class="badge {status_class}">{t["status"]}</span>
        </div>
        """
        
        node_active = "active" if t["status"] == "PASS" else "inactive"
        pulse_html = '<div class="pulse"></div>' if t["status"] == "PASS" else ""
        nodes_html += f"""
        <div class="node {node_active}">
            {pulse_html}
            <span>{t["name"].split(':')[0]}</span>
        </div>
        """

    report = HTML_TEMPLATE.format(
        bg=COLORS["bg"],
        card=COLORS["card"],
        primary=COLORS["primary"],
        success=COLORS["success"],
        failure=COLORS["failure"],
        warning=COLORS["warning"],
        text=COLORS["text"],
        text_muted=COLORS["text_muted"],
        run_id=str(os.popen("uuidgen").read().strip())[:8],
        timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        total=total,
        passed=passed,
        failed=failed,
        score=score,
        test_items=test_items_html,
        nodes=nodes_html
    )
    
    with open("test_report.html", "w") as f:
        f.write(report)
    
    print(f"Report generated: {os.path.abspath('test_report.html')}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--mock":
        mock_data = """
        [PASS] API Gateway Connectivity
        [PASS] Auth Service Latency < 100ms
        [PASS] Database Persistence Layer
        [FAIL] Chaos Experiment: Network Delay Remediation
        [PASS] Linkerd mTLS Handshake
        [PASS] Vector DB Indexing Speed
        [PASS] Karpenter Node Scaling
        """
        generate_report(parse_logs(mock_data))
    else:
        input_data = sys.stdin.read()
        generate_report(parse_logs(input_data))
