#!/bin/bash

if [ -z "$1" ]; then
    DOMAIN=$(curl -s https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/domains.txt | shuf -n 1)
else
    DOMAIN=$1
fi

# Define directories
OUTPUT_DIR="output"
RAW_DIR="$OUTPUT_DIR/raw"
PII_DIR="$OUTPUT_DIR/pii"
LOG_FILE="$OUTPUT_DIR/script.log"

mkdir -p "$RAW_DIR" "$PII_DIR"
echo "[+] Script started at $(date)" > "$LOG_FILE"

echo "[+] Target domain: $DOMAIN" | tee -a "$LOG_FILE"
echo "[+] Fetching URLs from Wayback Machine..." | tee -a "$LOG_FILE"

# Fetch URLs
curl -s -G "https://web.archive.org/cdx/search/cdx" \
    --data-urlencode "url=*.$DOMAIN/*" \
    --data-urlencode "collapse=urlkey" \
    --data-urlencode "output=text" \
    --data-urlencode "fl=original" | \
    uro | \
    grep -E '\.(xls|git|xlsx|pdf|sql|doc|docx|pptx|zip|tar\.gz|tgz|bak|7z|rar|log|cache|secret|db|backup|yml|gz|config|csv|yaml|md|md5|exe|dll|bin|ini|bat|sh|tar|deb|rpm|iso|img|apk|msi|dmg|tmp|crt|pem|key|pub|asc)$' > "$RAW_DIR/urls.txt"

URL_COUNT=$(wc -l < "$RAW_DIR/urls.txt")
echo "[+] Found $URL_COUNT potentially interesting URLs." | tee -a "$LOG_FILE"

if [ "$URL_COUNT" -eq 0 ]; then
    echo "[-] No URLs found. Exiting." | tee -a "$LOG_FILE"
    exit 1
fi

# Download and inspect files
echo "[+] Downloading files and scanning for PII..." | tee -a "$LOG_FILE"

cat "$RAW_DIR/urls.txt" | xargs -P10 -I{} sh -c '
    URL="{}"
    FILENAME=$(basename "$URL")
    FILEPATH="'$RAW_DIR'/$FILENAME"

    # Download file
    curl -s -o "$FILEPATH" "$URL"
    if [ $? -ne 0 ]; then
        echo "[-] Failed to download $URL" | tee -a "'$LOG_FILE'"
        exit 0
    fi

    # Validate file type
    FILETYPE=$(file --mime-type -b "$FILEPATH")
    echo "[.] Processing $FILENAME ($FILETYPE)" | tee -a "'$LOG_FILE'"

    # Scan for PII
    if grep -E -i "(ssn|password|email|user|token|key|secret|private|credit|card|phone|address|social|dob|dob:|birth)" "$FILEPATH" > /dev/null 2>&1; then
        echo "[!] PII found in $FILENAME" | tee -a "'$LOG_FILE'"
        mv "$FILEPATH" "'$PII_DIR'/$FILENAME"
    else
        echo "[.] No PII in $FILENAME" | tee -a "'$LOG_FILE'"
    fi
'

echo "[+] Script completed at $(date). Results stored in '$OUTPUT_DIR'." | tee -a "$LOG_FILE"
