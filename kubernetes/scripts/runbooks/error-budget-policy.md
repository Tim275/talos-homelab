# Error-Budget-Policy

Gilt für die Dienste unten. Budget = 100 % − SLO über die letzten 4 Wochen (28 Tage).

## Dienste

| Dienst | SLO | Budget / 4 Wochen | Alarme |
|---|---|---|---|
| Edge (Envoy Gateway, öffentlich) | 99,5 % Verfügbarkeit | ~3 h 22 min | EnvoyEdgeSLOFastBurn / SlowBurn |
| Keycloak (SSO) | 99,5 % Verfügbarkeit | ~3 h 22 min | KeycloakBurnRateFast / Slow |
| drova (5 Dienste) | 99,5 % Verfügbarkeit, 99 % Latenz | ~3 h 22 min / ~6 h 43 min | Drova*BurnRate* |
| n8n (öffentlich) | 99,5 % Verfügbarkeit, gemessen per Probe Gateway → n8n | ~3 h 22 min | N8NBurnRate* |

## Ziele

- Nutzer vor wiederholten SLO-Verfehlungen schützen.
- Einen Anreiz schaffen, Zuverlässigkeit und Features abzuwägen, statt nach Gefühl zu entscheiden.

## Nicht-Ziele

- Keine Strafe für verfehlte SLOs. Das Budget ist dafür da, ausgegeben zu werden.
- Kein Einfrieren wegen eines Messfehlers: stimmt das SLI nicht, wird zuerst das SLI repariert.

## Wenn das Budget aufgebraucht ist

- Innerhalb des SLO: Releases und Änderungen laufen normal weiter.
- Budget der letzten 4 Wochen aufgebraucht: keine Releases und Änderungen am betroffenen Dienst außer Fixes für akute Ausfälle und Sicherheitsupdates, bis der Dienst wieder im SLO liegt. Automatische Updates für den Dienst pausieren.
- Die freie Zeit geht in die Zuverlässigkeit: Maßnahmen aus den Postmortems zuerst.

## Einzelne Ausfälle

- Ein Vorfall verbraucht mehr als 20 % des 4-Wochen-Budgets: [Postmortem](postmortem-template.md) ist Pflicht.
- Dieselbe Art von Ausfall verbraucht im Quartal mehr als 20 % des Budgets: die Behebung ist die wichtigste Aufgabe im nächsten Quartal.

## Streitfall

Bei Uneinigkeit über die Berechnung oder die Folgen entscheidet der Plattform-Owner.

## Hintergrund

Nach dem [Google SRE Workbook, Anhang B](https://sre.google/workbook/error-budget-policy/). Burn-Rate-Alarme nach Workbook Kap. 5, Tabelle 5-8: Faktor 14,4 und 6 pagen, Faktor 1 wird ein Ticket.
