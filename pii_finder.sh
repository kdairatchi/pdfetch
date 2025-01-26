#!/bin/bash
# Ultimate PII/Secret Finder v2.0
# Combines: ChaosDB integration, advanced pattern matching, ML validation, and real-time alerts
# Dependencies: gf, nuclei, jq, notify, gitleaks, meg, uro, unfurl

set -eo pipefail

# Configuration [citation:3][citation:7]
TARGET="${1:-}"
CHAOS_API_KEY="your_chaos_key"  # From projectdiscovery.io
GITHUB_TOKEN="your_github_token"
SLACK_WEBHOOK="your_slack_webhook"
MAX_THREADS=15
SEVERITY_LEVEL="high,critical"

# Enhanced directories structure
OUTPUT_DIR="pii_scan_$(date +%Y%m%d)"
RAW_DIR="$OUTPUT_DIR/raw_data"
RESULTS_DIR="$OUTPUT_DIR/findings"
LOGS_DIR="$OUTPUT_DIR/logs"
mkdir -p {$RAW_DIR,$RESULTS_DIR,$LOGS_DIR}/{wayback,github,subdomains,cloud}

# Initialize logging
exec > >(tee -a "$LOGS_DIR/main.log") 2>&1

target_selection() {
    if [ -z "$TARGET" ]; then
        echo "[+] Selecting target from ChaosDB..."
        curl -s "https://chaos.projectdiscovery.io/v1/datasets/download?type=rewards" \
            -H "Authorization: $CHAOS_API_KEY" -o chaos_targets.zip
        unzip -q chaos_targets.zip -d chaos_data
        TARGET=$(shuf -n 1 chaos_data/*.txt)
        echo "[+] Random target selected: $TARGET" | tee -a "$LOGS_DIR/target.log"
    else
        echo "[+] Using provided target: $TARGET" | tee -a "$LOGS_DIR/target.log"
    fi
}

asset_discovery() {
    echo "[+] Starting asset discovery pipeline..." | tee -a "$LOGS_DIR/asset.log"
    
    # Subdomain enumeration [citation:4]
    subfinder -d "$TARGET" -silent | anew "$RAW_DIR/subdomains.txt"
    chaos -d "$TARGET" -silent | anew "$RAW_DIR/subdomains.txt"
    
    # Cloud assets discovery [citation:6]
    cloud_enum -k "$TARGET" -l "$RAW_DIR/cloud/assets.txt"
    
    # GitHub secret scanning [citation:9]
    gitallsecrets -t "$GITHUB_TOKEN" -q "$TARGET" -o "$RAW_DIR/github_secrets.json"
    
    # Wayback Machine with enhanced filters [citation:3]
    waybackurls "$TARGET" | \
        grep -E '\.(json|conf|env|cfg|ini|log|bak|sql|dump|tar|gz|zip|xls|xlsx|doc|docx|pdf)$' | \
        uro | anew "$RAW_DIR/wayback_urls.txt"
    
    # Live URL probing
    cat "$RAW_DIR/subdomains.txt" | httpx -silent -status-code -title -json -o "$RAW_DIR/live_hosts.json"
}

pii_scanning() {
    echo "[+] Starting PII detection engine..." | tee -a "$LOGS_DIR/scan.log"
    
    # Multi-source input processing
    cat {$RAW_DIR/wayback_urls.txt,$RAW_DIR/cloud/assets.txt} | sort -u | \
        meg -d 1000 -v -c $MAX_THREADS /dev/null | \
        tee "$RAW_DIR/meg_output.txt"
    
    # Advanced pattern matching [citation:4]
    gf -list | grep -E 'aws-keys|base64|secrets|tokens' | xargs -I{} sh -c \
        "cat $RAW_DIR/meg_output.txt | gf {} | anew $RESULTS_DIR/potential_pii.txt"
    
    # File content analysis
    grep -E '\.(json|env|cfg|ini|log|sql)$' "$RAW_DIR/meg_output.txt" | \
        xargs -P$MAX_THREADS -I{} sh -c '
            curl -s "{}" | \
            grep -E -i "(aws_(access_key_id|secret_access_key)|password|api[_-]?key|secret|token|auth|credentials|jdbc:|postgresql:|mysql:|mongodb:|ssh-rsa)" | \
            anew "$RESULTS_DIR/raw_secrets.txt"
        '
    
    # Structured data validation [citation:8]
    gitleaks detect --source "$RAW_DIR" --report-path "$RESULTS_DIR/gitleaks.json" --exit-code 0
    trufflehog filesystem --directory="$RAW_DIR" --json | jq -c . > "$RESULTS_DIR/trufflehog.json"
    
    # Machine Learning validation [citation:8]
    python3 - <<'EOF'
from presidio_analyzer import AnalyzerEngine
analyzer = AnalyzerEngine()
with open("$RESULTS_DIR/raw_secrets.txt") as f:
    for line in f:
        results = analyzer.analyze(text=line.strip(), language="en")
        if results:
            print(f"ML Validation Alert: {line.strip()}")
EOF' | tee -a "$RESULTS_DIR/ml_validated.txt"
}

notification() {
    echo "[+] Sending real-time alerts..." | tee -a "$LOGS_DIR/notification.log"
    critical_findings=$(jq length "$RESULTS_DIR/gitleaks.json")
    
    curl -X POST -H 'Content-type: application/json' "$SLACK_WEBHOOK" -d \
        "{
            \"text\": \"*PII Scan Complete* :rotating_light:\n
            • Target: \`$TARGET\`\n
            • Critical Findings: $critical_findings\n
            • Report: \`$(pwd)/$RESULTS_DIR\`\"
        }"
    
    [ $critical_findings -gt 0 ] && \
        notify -provider telegram -data "$RESULTS_DIR/ml_validated.txt" -silent
}

reporting() {
    echo "[+] Generating consolidated report..." | tee -a "$LOGS_DIR/report.log"
    
    # Generate executive summary
    echo "# PII Scan Report: $TARGET" > "$OUTPUT_DIR/final_report.md"
    echo "## Critical Findings" >> "$OUTPUT_DIR/final_report.md"
    jq -r '.[] | "### \(.Description)\n- File: \(.File)\n- Secret: ||\(.Secret)||\n"' \
        "$RESULTS_DIR/gitleaks.json" >> "$OUTPUT_DIR/final_report.md"
    
    echo "## Full Findings" >> "$OUTPUT_DIR/final_report.md"
    cat "$RESULTS_DIR"/{potential_pii.txt,raw_secrets.txt} | \
        sort -u | awk '!seen[$0]++' >> "$OUTPUT_DIR/final_report.md"
    
    # Create machine-readable output
    jq -s '[.[]]' "$RESULTS_DIR"/*.json > "$OUTPUT_DIR/findings.json"
}

cleanup() {
    echo "[+] Securely cleaning up temporary files..."
    find "$RAW_DIR" -type f -exec shred -u {} \;
    rm -rf chaos_data chaos_targets.zip
}

main() {
    target_selection
    asset_discovery
    pii_scanning
    notification
    reporting
    cleanup
    echo "[+] Scan completed! Results stored in: $OUTPUT_DIR"
}

main
