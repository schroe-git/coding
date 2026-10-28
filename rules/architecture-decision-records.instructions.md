---
description: "Bei wesentlichen Architekturentscheidungen nachvollziehbare ADRs dokumentieren"
applyTo: "**/*"
---

# Architekturentscheidungen festhalten

- Dokumentiere wesentliche, längerfristig wirksame Architektur- oder Designentscheidungen als nummerierte Markdown-ADRs in `docs/decisions/`.
- Nutze `docs/decisions/0000-template.md` als Ausgangspunkt und halte mindestens Kontext, Entscheidung, Begründung, betrachtete Alternativen und Konsequenzen fest.
- Vergib die nächste freie fortlaufende Nummer und einen kurzen, aussagekräftigen Dateinamen. Ändere oder lösche angenommene ADRs nicht stillschweigend; dokumentiere eine spätere Ablösung in einem neuen ADR und verweise zwischen den Einträgen.
- Erstelle oder ändere keinen ADR für eine mit `Idee:` beginnende Anfrage; diese wird ausschließlich nach `BACKLOG.md` aufgenommen.