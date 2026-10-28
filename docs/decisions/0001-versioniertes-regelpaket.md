# ADR-0001: Versioniertes Copilot-Regelpaket mit kontrollierten Updates

- Status: Angenommen
- Datum: 2026-10-28

## Kontext

Die Regelsammlung soll einfach in neue und bestehende Projekte integrierbar sein.
Ein GitHub-Template allein verteilt keine Updates an bestehende Projekte.
Projekte brauchen eine nachvollziehbare Version, dürfen aber keine lokalen Regeln
oder Arbeitsdateien durch ein Update verlieren.

## Entscheidung

- Die Quelle bleibt `rules/`; Installation erfolgt in den Copilot-Standardordner
  `.github/instructions/` des Zielprojekts.
- Ein PowerShell-Werkzeug kopiert explizit ausgewählte Profile. `core` ist immer
  enthalten; `ideas` und `adr` sind optional.
- Releases verwenden `VERSION`, Changelog und unveränderliche `vMAJOR.MINOR.PATCH`-Tags.
- Ein Manifest im Zielprojekt hält Herkunft, Version, Profile und Inhaltsprüfsummen fest.
- Vor Änderungen werden lokale Konflikte geprüft. Es gibt keinen erzwungenen Überschreibmodus.
- Workflow-Startdateien werden nur bei Bedarf angelegt, danach nie verwaltet oder gelöscht.
- Die Sammlung steht unter Apache-2.0; die Lizenz wird mit den Regeln installiert.

## Begründung und betrachtete Alternativen

Kopierte, im Zielprojekt eingecheckte Regeln benötigen dort keine Laufzeitabhängigkeit
und sind im Review sichtbar. PowerShell ist unter Windows vorhanden und mit
PowerShell 7 auch auf Linux und macOS verfügbar.

Git-Submodule und Symlinks erhöhen die Anforderungen an Klonen, Editor-Erkennung und
Plattformunterstützung. Eine Paketmanager-Lösung würde ein zusätzliches Ökosystem
voraussetzen. Ein reines Template eignet sich zum Start eines neuen Repositorys,
nicht für kontrollierte Aktualisierungen vorhandener Projekte.

## Konsequenzen

Updates werden bewusst ausgelöst, nicht automatisch verteilt. Verwaltete Regeln
sollen nicht direkt angepasst werden; projektspezifische Ergänzungen bleiben separat.
Die Prüfsummen ignorieren reine LF/CRLF-Unterschiede.

Das Werkzeug prüft keine semantischen Widersprüche und garantiert keine Regelbefolgung
durch den Agenten. Bei Betriebssystemfehlern während des Schreibens ist keine
transaktionale Rücknahme vorgesehen. Ein sauberer Git-Arbeitsstand ist daher empfohlen.

Weitere Agent-Formate werden erst bei konkretem Bedarf ergänzt. Bei Änderungen des
Manifestformats oder der Paketstruktur muss auch das lokale Werkzeug aktualisiert werden.

## Ersetzt / ersetzt durch

Keine.
