#!/usr/bin/env bash
# DDNS Updater für IPV64.net
# Aktualisiert alle konfigurierten Subdomains per NIC-Update-Protokoll.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

DATUM=$(date '+%Y-%m-%d %H:%M:%S')
PFAD="$SCRIPT_DIR"

log() { echo "$DATUM  $*" | tee -a "$LOG_FILE"; }

trim_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local lines
        lines=$(wc -l < "$LOG_FILE")
        if (( lines > MAX_LOG_LINES )); then
            tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
        fi
    fi
}

# --- IP ermitteln ---
IP=""
for url_ip in \
    "https://ipinfo.io/ip" \
    "https://api.ipify.org" \
    "https://icanhazip.com" \
    "https://checkip.amazonaws.com" \
    "https://ipecho.net/plain" \
    "https://ipv64.net/ipcheck.php?ipv4"
do
    response=$(curl -4sSL --connect-timeout 3 --max-time 5 "$url_ip" 2>/dev/null | tr -d '[:space:]')
    if [[ "$response" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IP="$response"
        break
    fi
done

if [[ -z "$IP" ]]; then
    log "FEHLER !!! - Keine gültige IPv4-Adresse gefunden. Abbruch."
    exit 1
fi

# --- IP-Änderung prüfen ---
mkdir -p "$PFAD"
mkdir -p "$(dirname "$LOG_FILE")"
trim_log

UPDIP=$(cat "$PFAD/updip.txt" 2>/dev/null || echo "")

if [[ "$IP" == "$UPDIP" ]]; then
    log "KEIN UPDATE  - IP unverändert ($IP)"
    exit 0
fi

log "UPDATE !!!  - IP-Änderung: ${UPDIP:-(leer)} -> $IP"

# --- Alle Subdomains aktualisieren ---
FAIL_COUNT=0

for sub in "${SUBDOMAINS[@]}"; do
    FULL_DOMAIN="${sub}.${BASE_DOMAIN}"
    API_URL="https://ipv64.net/nic/update?key=${DOMAIN_KEY}&domain=${FULL_DOMAIN}&ip=${IP}"

    RESPONSE=$(curl -4sSL --connect-timeout 5 --max-time 10 "$API_URL" 2>/dev/null)

    if [[ "$RESPONSE" =~ (nochg|good|ok) ]]; then
        log "UPDATE !!!  - $FULL_DOMAIN erfolgreich aktualisiert ($IP)"
    else
        log "FEHLER !!!  - $FULL_DOMAIN – Server-Antwort: '$RESPONSE'"
        (( FAIL_COUNT++ )) || true
    fi

    sleep 3
done

# --- Ergebnis ---
if (( FAIL_COUNT == 0 )); then
    echo "$IP" > "$PFAD/updip.txt"
    log "UPDATE !!!  - Alle ${#SUBDOMAINS[@]} Subdomains aktualisiert. Neue IP: $IP"
else
    log "WARNUNG !!! - $FAIL_COUNT Subdomain(s) fehlgeschlagen – IP-Cache nicht gesetzt."
    exit 1
fi

echo "=============================================================================================="
