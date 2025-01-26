#!/bin/bash

if [ -z "$1" ]; then
    DOMAIN=$(curl -s https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/domains.txt | shuf -n 1)
else
    DOMAIN=$1
fi

mkdir -p output

curl -s -G "https://web.archive.org/cdx/search/cdx" \
    --data-urlencode "url=*.$DOMAIN/*" \
    --data-urlencode "collapse=urlkey" \
    --data-urlencode "output=text" \
    --data-urlencode "fl=original" | \
    uro | \
    grep -E '\.(xls|git|xlsx|pdf|sql|doc|docx|pptx|zip|tar\.gz|tgz|bak|7z|rar|log|cache|secret|db|backup|yml|gz|config|csv|yaml|md|md5|exe|dll|bin|ini|bat|sh|tar|deb|rpm|iso|img|apk|msi|dmg|tmp|crt|pem|key|pub|asc)$'
