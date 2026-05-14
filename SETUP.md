# DDNS Updater – Setup-Anleitung

## 1. Dateien auf den Server übertragen

```bash
scp ddns_update.sh config.env user@dein-server:/opt/ddns/
```

## 2. Konfiguration anpassen

`config.env` auf dem Server öffnen und ausfüllen:

- **Update_Key** – Deinen Token von ipv64.net (Kontoeinstellungen → API-Token)
- **SUBDOMAINS** – Die 14 Subdomain-Präfixe eintragen (nur den Teil vor `.deineDomain.ipv64.net`)

## 3. Berechtigungen setzen

```bash
chmod 700 /opt/ddns/ddns_update.sh
chmod 600 /opt/ddns/config.env   # Nur root darf den Token lesen
```

## 4. Manueller Test

```bash
sudo /opt/ddns/ddns_update.sh
cat /var/log/ddns_update.log
```

## 5. Cron-Job einrichten (alle 5 Minuten)

```bash
sudo crontab -e
```

Folgende Zeile hinzufügen:

```
0 6,18 * * * /opt/ddns/ddns_update.sh >> /var/log/ddns_update.log 2>&1
```

Läuft täglich um 06:00 und 18:00 Uhr.

---

## Log-Ausgabe verstehen

| Level  | Bedeutung                                      |
|--------|------------------------------------------------|
| INFO   | IP unverändert oder Update erfolgreich         |
| OK     | Einzelne Subdomain erfolgreich aktualisiert    |
| WARN   | Teilweise fehlgeschlagen, Cache nicht gesetzt  |
| ERROR  | Netzwerkfehler oder ungültige API-Antwort      |

## Logs live verfolgen

```bash
tail -f /var/log/ddns_update.log
```
