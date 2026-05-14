# IPV64.net DDNS Updater

Automatisches Dynamic-DNS-Update-Skript für [IPV64.net](https://ipv64.net).  
Erkennt IP-Änderungen und aktualisiert beliebig viele Subdomains vollautomatisch per Cron-Job.

---

## Funktionsweise

Heimserver mit dynamischer IP verlieren ihre Erreichbarkeit, sobald der Router eine neue IP-Adresse erhält. Dieses Skript löst das Problem:

1. Ermittelt die aktuelle öffentliche IPv4-Adresse über mehrere Fallback-Dienste
2. Vergleicht sie mit der zuletzt gespeicherten IP
3. Bei Änderung: aktualisiert alle konfigurierten Subdomains per IPV64.net NIC-Update-Protokoll
4. Läuft als Cron-Job automatisch im Hintergrund

---

## Voraussetzungen

- Linux-Server (z. B. Debian, Ubuntu, OpenMediaVault)
- `bash` ≥ 4.0
- `curl` (auf den meisten Systemen vorinstalliert)
- Ein kostenloses Konto bei [ipv64.net](https://ipv64.net)
- Eine registrierte Domain und Subdomains auf IPV64.net
- Den **DynDNS Update Key** aus den Domain-Einstellungen auf IPV64.net

---

## Installation

### 1. Dateien auf den Server übertragen

```bash
# Verzeichnis anlegen
sudo mkdir -p /opt/ddns

# Dateien hochladen
scp ddns_update.sh config.env user@dein-server:/opt/ddns/
```

### 2. Konfiguration anpassen

```bash
sudo nano /opt/ddns/config.env
```

Alle Felder ausfüllen (siehe [Konfigurationsreferenz](#konfigurationsreferenz)).

### 3. Berechtigungen setzen !!! WICHTIG !!!

```bash
sudo chmod 700 /opt/ddns/ddns_update.sh
sudo chmod 600 /opt/ddns/config.env   # Nur root darf den Key lesen
```

### 4. Manuellen Test durchführen

```bash
sudo bash /opt/ddns/ddns_update.sh
```

Erwartete Ausgabe beim ersten Lauf:

```
2026-05-14 10:30:00  UPDATE !!!  - IP-Änderung: (leer) -> 88.77.6.100
2026-05-14 10:30:00  UPDATE !!!  - sub1.deinedomain.ipv64.net erfolgreich aktualisiert (88.77.6.100)
2026-05-14 10:30:03  UPDATE !!!  - sub2.deinedomain.ipv64.net erfolgreich aktualisiert (88.77.6.100)
...
2026-05-14 10:31:42  UPDATE !!!  - Alle 14 Subdomains aktualisiert. Neue IP: 88.77.6.100
```

### 5. Cron-Job einrichten

```bash
sudo crontab -e
```

Folgende Zeile hinzufügen (läuft täglich um 06:00 und 18:00 Uhr):

```
0 6,18 * * * /opt/ddns/ddns_update.sh >> /var/log/ddns_update.log 2>&1
```

---

## Konfigurationsreferenz

Alle Einstellungen befinden sich in `config.env`:

| Variable | Beschreibung | Beispiel |
|---|---|---|
| `DOMAIN_KEY` | DynDNS Update Key aus den Domain-Einstellungen auf ipv64.net | `abc123xyz` |
| `BASE_DOMAIN` | Deine Basis-Domain auf IPV64.net | `meinserver.ipv64.net` |
| `SUBDOMAINS` | Bash-Array der Subdomain-Präfixe | `("home" "grafana" "vault")` |
| `LOG_FILE` | Pfad zur Log-Datei | `/var/log/ddns_update.log` |
| `MAX_LOG_LINES` | Maximale Zeilenzahl der Log-Datei | `500` |

### Wo finde ich den DOMAIN_KEY?

1. Auf [ipv64.net](https://ipv64.net) einloggen
2. Mein Konto → DynDNS
3. Den **Update Key** der jeweiligen Domain kopieren  
   _(Nicht zu verwechseln mit dem Account-API-Key)_

### Beispiel `config.env`

```bash
DOMAIN_KEY="DeinDOMAINKEYHier"
BASE_DOMAIN="meinserver.ipv64.net"

SUBDOMAINS=(
    "home"
    "grafana"
    "nextcloud"
    "vault"
)

LOG_FILE="/var/log/ddns_update.log"
MAX_LOG_LINES=500
```

---

## Log-Ausgabe verstehen

```
2026-05-14 06:00:00  KEIN UPDATE  - IP unverändert (88.77.6.100)
2026-05-14 18:00:00  UPDATE !!!  - IP-Änderung: 88.77.6.100 -> 88.77.6.200
2026-05-14 18:00:00  UPDATE !!!  - home.meinserver.ipv64.net erfolgreich aktualisiert (88.77.6.200)
2026-05-14 18:00:03  FEHLER !!!  - vault.meinserver.ipv64.net – Server-Antwort: 'Update-Cooldown 10sec'
2026-05-14 18:00:06  WARNUNG !!! - 1 Subdomain(s) fehlgeschlagen – IP-Cache nicht gesetzt.
```

| Präfix | Bedeutung |
|---|---|
| `KEIN UPDATE` | IP unverändert, nichts zu tun |
| `UPDATE !!!` | IP-Änderung erkannt oder Subdomain erfolgreich aktualisiert |
| `FEHLER !!!` | Einzelne Subdomain konnte nicht aktualisiert werden |
| `WARNUNG !!!` | Mindestens eine Subdomain fehlgeschlagen, IP-Cache nicht gesetzt |

---

## Fehlerbehebung

### „Update-Cooldown 10sec"
IPV64.net erlaubt maximal 5 Requests pro 10 Sekunden. Das Skript wartet bereits 3 Sekunden zwischen den Calls. Tritt der Fehler trotzdem auf, ist das API-Limit für die Subdomain kurzzeitig ausgeschöpft – beim nächsten Cron-Durchlauf wird es nachgeholt.

### Keine IP gefunden
```
FEHLER !!! - Keine gültige IPv4-Adresse gefunden. Abbruch.
```
Mögliche Ursachen:
- Server hat keine Internetverbindung
- Alle IP-Erkennungsdienste sind vorübergehend nicht erreichbar

Manueller Test:
```bash
curl -4 https://api.ipify.org
```

### Alle Subdomains schlagen fehl
Prüfe den `DOMAIN_KEY` in `config.env`. Teste manuell:
```bash
source /opt/ddns/config.env
curl "https://ipv64.net/nic/update?key=${DOMAIN_KEY}&domain=sub1.${BASE_DOMAIN}&ip=1.2.3.4"
```
Erwartete Antwort: `good` oder `nochg`

### Logs live verfolgen
```bash
tail -f /var/log/ddns_update.log
```

---

## Sicherheitshinweise

- `config.env` enthält deinen Update Key – **niemals** mit echtem Key in ein öffentliches Repository committen
- Die Datei ist mit `chmod 600` geschützt, sodass nur root sie lesen kann
- Für dieses Repository wird in `config.env` ausschließlich ein Platzhalter-Key verwendet

---

## Projektstruktur

```
.
├── ddns_update.sh   # Hauptskript
├── config.env       # Konfiguration (Key + Subdomains)
├── SETUP.md         # Kurzanleitung
└── README.md        # Diese Datei
```

---

## Lizenz

MIT License – frei verwendbar, veränderbar und weitergabe erlaubt.
