# Agent-Coding-Regeln

Kleine, wiederverwendbare Sammlung von Regeln für Coding-Agents und GitHub Copilot.

## Aufbau

- `.github/copilot-instructions.md` – Regeln für dieses Repository
- `rules/` – thematische, wiederverwendbare Agent-Instructions
- `BACKLOG.md` – Ideen für eine spätere Bearbeitung
- `docs/decisions/` – nummerierte Architecture Decision Records (ADRs)

## Regeln hinzufügen

Lege eine Datei nach `rules/` an. Nutze das Format aus `rules/template.instructions.md`, halte jede Regel fokussiert und gib mit `applyTo` an, für welche Dateien sie gilt. Prüfe vor dem Commit, ob die Regel eindeutig, knapp und ohne projektspezifische Annahmen formuliert ist.

## Ideen und Entscheidungen

Nachrichten mit `Idee:` werden kurz analysiert, nicht direkt umgesetzt und mit UTC-Zeitstempel als offene Aufgabe in `BACKLOG.md` aufgenommen. Wesentliche Architekturentscheidungen werden als nummerierte ADRs dokumentiert; nutze dafür die Vorlage in `docs/decisions/`.
