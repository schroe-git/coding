# Regeln für dieses Repository

- Schreibe kurze, konkrete und überprüfbare Agent-Regeln.
- Trenne thematisch unterschiedliche Regeln in eigene `*.instructions.md`-Dateien unter `rules/`.
- Verwende YAML-Frontmatter mit `description` und einem möglichst engen `applyTo`-Glob.
- Vermeide Dopplungen, Widersprüche und unbelegte projektspezifische Vorgaben.
- Befolge für `Idee:`-Nachrichten die [Ideen-Regel](../rules/idea-backlog.instructions.md) und für Architekturentscheidungen die [ADR-Regel](../rules/architecture-decision-records.instructions.md).
- Halte auslieferbare Regeln, Vorlagen und Regeln zur Pflege dieses Repositorys getrennt. Ergänze bei Paketänderungen die Installationstests und bei Releases Version und Changelog.
- Aktualisiere die README, wenn sich Aufbau oder Beitragsablauf ändern.
