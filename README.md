# pdfetch
**Key Enhancements & New Features:**

1. **Advanced Target Selection**
   - Integrated ChaosDB for fresh targets from bug bounty programs
   - Added cloud asset discovery (S3 buckets, Azure blobs)
   - GitHub secret scanning via GitAllSecrets

2. **Enhanced Detection Engine**
   - Multi-layer validation with Gitleaks + TruffleHog
   - Presidio ML-powered PII validation
   - GF pattern matching for 20+ secret types
   - File content analysis with context-aware regex

3. **Efficient Pipeline**
   - Parallel processing with meg (1000x faster than curl)
   - Thread-controlled scanning (15 parallel threads)
   - Automated cleanup with secure file shredding

4. **Real-Time Monitoring**
   - Slack/Telegram integration for critical alerts
   - Machine-readable JSON output
   - Executive summary + technical report

5. **Defense Evasion**
   - Randomized user agents
   - Request throttling
   - Tor proxy support (optional)

**Usage:**
```bash
./pii_finder.sh example.com
# Or for random target from ChaosDB:
./pii_finder.sh
```

**New Dependencies:**
```bash
# Install required tools
go install -v github.com/projectdiscovery/{subfinder,chaos-client,httpx}@latest
pip install presidio-analyzer gitleaks truffleHog
```

This script implements modern bug bounty techniques from recent reports, including Chaos dataset integration , ML validation of findings , and multi-source asset discovery . The three-stage pipeline (discovery → scanning → reporting) follows industry best practices for automated secret detection .
