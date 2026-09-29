# Postmortem: <Titel>

Datum: · Autor: · Status: Entwurf | fertig, Maßnahmen offen | abgeschlossen

Ohne Schuldfrage: Gesucht werden Ursachen in System und Ablauf, nicht Schuldige. Jeder Beteiligte hat mit dem Wissen von damals richtig gehandelt.

Pflicht bei:
- Ausfall oder Verschlechterung für Nutzer über der SLO-Schwelle
- Datenverlust, egal wie klein
- manuellem Eingriff (Rollback, Umleiten, Neustart von Hand)
- Behebung länger als 1 Stunde
- Ausfall des Monitorings selbst (der Vorfall wurde von Hand entdeckt)
- einem Vorfall, der mehr als 20 % des 4-Wochen-Error-Budgets verbraucht ([Policy](error-budget-policy.md))

## Zusammenfassung

Zwei, drei Sätze: was, wie lange, wer war betroffen.

## Auswirkung

Nutzer, Anfragen, Daten. Verbrauchtes Error Budget in Minuten und Prozent.

## Ursachen

## Auslöser

Die Änderung oder das Ereignis, das die Ursachen wirksam gemacht hat.

## Behebung

## Erkennung

Welcher Alarm, wann, nach wie vielen Minuten. Kein Alarm? Dann ist das die erste Maßnahme.

## Maßnahmen

| Maßnahme | Typ | Owner | Ticket |
|---|---|---|---|
| | vorbeugen · abmildern · erkennen | | |

## Lehren

### Was lief gut

### Was lief schlecht

### Wo wir Glück hatten

## Zeitverlauf

Alle Zeiten in UTC.

| Zeit | Ereignis |
|---|---|
| | |

## Belege

Graphen, Logs, Links zu Alarmen und Tickets.

Aufbau nach dem Beispiel im [Google SRE Book, Anhang D](https://sre.google/sre-book/example-postmortem/).
