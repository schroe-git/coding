# Agent-Coding-Regeln

Versioniertes Regelpaket für GitHub Copilot, verwendbar in neuen und bestehenden
Projekten. Aktuelle Paketversion: **0.1.0**, Lizenz: **Apache-2.0**.

Die Regeln werden ins Zielprojekt kopiert und dort mit Git versioniert.
Teammitglieder benötigen danach keine zusätzliche Installation, kein Submodul und
keine Verbindung zu diesem Repository.

## Schnellstart

Voraussetzungen für die Installation: Git und Windows PowerShell 5.1 oder
PowerShell 7 (`pwsh`). Unter Windows ist PowerShell 5.1 bereits vorhanden.
Für veröffentlichte Versionen ist Zugriff auf GitHub erforderlich.

Dieses Repository einmal außerhalb des Zielprojekts klonen und das Werkzeug starten:

```powershell
git clone https://github.com/schroe-git/coding.git C:\Tools\coding-rules
& C:\Tools\coding-rules\scripts\coding-rules.ps1 -Action Install -Target C:\Projekte\MeineApp -Version v0.1.0
```

**Veröffentlichungsstatus:** `0.1.0` ist vorbereitet. Der Versionsbefehl funktioniert
erst, wenn der Tag `v0.1.0` veröffentlicht wurde (siehe [Release-Ablauf](#release-ablauf)).
Zum sofortigen Testen des lokalen Arbeitsstands `-Version v0.1.0` weglassen.

Das Zielverzeichnis muss bereits existieren. Pfade mit Leerzeichen in Anführungszeichen
setzen. Falls die lokale Windows-Ausführungsrichtlinie das geprüfte Skript blockiert,
kann es einmalig mit `powershell -NoProfile -ExecutionPolicy Bypass -File
C:\Tools\coding-rules\scripts\coding-rules.ps1 -Action Install -Target
C:\Projekte\MeineApp` gestartet werden; die dauerhafte Richtlinie muss nicht geändert werden.

Unter Linux/macOS PowerShell 7 verwenden, beispielsweise:

```sh
git clone https://github.com/schroe-git/coding.git "$HOME/coding-rules"
pwsh -NoProfile -File "$HOME/coding-rules/scripts/coding-rules.ps1" -Action Install -Target "$PWD" -Version v0.1.0
```

Anschließend die installierten Dateien im Zielprojekt prüfen und committen.
Projektdateien wie die bestehende `.github/copilot-instructions.md` werden nicht verändert.
Die Regelsammlung selbst muss nicht in das Zielprojekt kopiert werden.

## Profile

| Profil | Inhalt | Standard |
|---|---|---|
| `core` | Kleine, nachvollziehbare Änderungen und Prüfung betroffener Tests | Immer enthalten |
| `ideas` | Mit `Idee:` beginnende Nachrichten nur analysieren und im Backlog vormerken | Optional |
| `adr` | Wesentliche Architekturentscheidungen als ADR dokumentieren | Optional |

Alle Profile installieren:

```powershell
& C:\Tools\coding-rules\scripts\coding-rules.ps1 -Action Install -Target C:\Projekte\MeineApp -Version v0.1.0 -Profiles core,ideas,adr
```

Die globalen Regeln gelten bewusst projektweit. Aufgabenbezogene Beschreibungen
erklären, wann Ideen- und ADR-Workflows relevant sind. Für künftige
sprach- oder dateispezifische Regeln sollen möglichst enge `applyTo`-Globs verwendet werden.

### Dateien im Zielprojekt

```text
.github/
  coding-rules.json
  instructions/
    coding-general.instructions.md
    coding-ideas.instructions.md       # nur Profil ideas
    coding-adr.instructions.md         # nur Profil adr
    coding-rules/
      LICENSE.txt
BACKLOG.md                            # bei ideas, nur falls noch nicht vorhanden
docs/decisions/0000-template.md        # bei adr, nur falls noch nicht vorhanden
```

Das Manifest speichert Quelle, Version, Profile und SHA-256-Prüfsummen der
verwalteten Regeln und Lizenz. Prüfsummen beziehen sich auf UTF-8-Text mit
normalisierten LF-Zeilenenden; ein Git-Checkout mit CRLF ist kein Konflikt.

Backlog und ADR-Vorlage gehören nach der Erstellung dem Zielprojekt und werden
nie überschrieben oder bei einer Profilabwahl gelöscht. Ein vorhandener Backlog
oder eine vorhandene Vorlage wird unverändert weiterverwendet.

Regelvorlagen, Repository-Verwaltungsregeln, dessen Backlog-Einträge und dessen
ADRs werden nicht als Regeln ins Zielprojekt übernommen.

## Prüfen und aktualisieren

Lokale Installation ohne Netzwerkzugriff und ohne Schreibzugriff prüfen:

```powershell
& C:\Tools\coding-rules\scripts\coding-rules.ps1 -Action Check -Target C:\Projekte\MeineApp
```

`Check` prüft Manifest, verwaltete Dateiinhalte und erforderliche Workflow-Dateien.
Es fragt nicht ab, ob eine neuere Version verfügbar ist, und prüft nicht die tatsächliche
Regelbefolgung durch den Agenten.

Explizit eine veröffentlichte Version übernehmen:

```powershell
& C:\Tools\coding-rules\scripts\coding-rules.ps1 -Action Update -Target C:\Projekte\MeineApp -Version v0.1.0
```

Dabei bleiben die installierten Profile erhalten. Zum Ändern der Auswahl
`-Profiles core,ideas` oder nur `-Profiles core` angeben. Unveränderte verwaltete
Regeln abgewählter Profile werden entfernt. Auch eine explizite Rückkehr zu einer
älteren kompatiblen Paketversion ist möglich.

`-Version` lädt ausschließlich den angegebenen Tag aus `schroe-git/coding` in ein
temporäres Verzeichnis. Das heruntergeladene Skript wird nicht ausgeführt; das lokale
Werkzeug übernimmt nur die festgelegten Paketdateien und prüft die Paketversion.
Ohne `-Version` wird der lokale Arbeitsstand neben dem Werkzeug verwendet. Das ist
für die Entwicklung gedacht; die Versionsangabe allein macht lokale Änderungen nicht
zu einem veröffentlichten Release.

Bei einem neuen Manifestformat oder einer Änderung der Paketstruktur zuerst auch
das Werkzeug aktualisieren (`git -C C:\Tools\coding-rules pull --ff-only`).
Releases müssen solche Anforderungen in ihrer Änderungsübersicht nennen.

### Konflikte und eigene Ergänzungen

- Eigene Regeln in separaten, anders benannten Instruction-Dateien ablegen.
- Verwaltete Dateien möglichst nicht direkt bearbeiten. Es gibt bewusst kein `-Force`.
- Bei geänderten oder fehlenden verwalteten Dateien bricht die Installation beziehungsweise
  das Update vor Änderungen ab. Eigene Inhalte separat sichern und die verwaltete
  Datei bewusst aus dem letzten eigenen Git-Commit wiederherstellen, dann erneut prüfen.
- Unverwaltete Dateien mit demselben Zielnamen werden ebenfalls nicht überschrieben.
- Erst alle Konflikte beheben, dann erneut ausführen und den Git-Diff kontrollieren.

Alle bekannten Inhalts- und Pfadkonflikte werden vor Schreibzugriffen geprüft.
Links in Installationspfaden werden abgelehnt. Schreibfehler, etwa durch fehlenden
Speicherplatz oder Berechtigungen, werden gemeldet; es gibt keine transaktionale
Rücknahme bereits geschriebener Dateien. Deshalb im sauberen Git-Arbeitsstand ausführen.

Wiederholte Installation derselben Inhalte ist schreibfrei. Bestehende Regeln werden
nicht automatisch semantisch auf Widersprüche geprüft: Das bleibt Teil der Projektintegration.

## Unterstützung durch Agenten

Installationsziel ist der Copilot-Standardordner `.github/instructions/`.
Es ist keine zusätzliche VS-Code-Pfadeinstellung nötig. Die tatsächliche Erkennung
hängt vom verwendeten Copilot-Client und Agent-Harness ab. In VS Code über
**Chat: Open Customizations** beziehungsweise den Instruction-Kontext prüfen,
ob die installierten Regeln verfügbar sind.

Andere Agents wie Claude oder Codex werden derzeit nicht gezielt unterstützt.
Sie haben teilweise andere Formate und Erkennungsregeln.
Siehe [VS-Code-Dokumentation zu Instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions).

## GitHub-Template

Dieses Repository ist primär die Quelle des Regelpakets, kein Anwendungsgerüst.
Für neue wie bestehende Anwendungen wird die Installation oben empfohlen.
Die optionale GitHub-Einstellung **Settings → General → Template repository**
kann der Repository-Owner zusätzlich aktivieren. Ein daraus erstelltes Repository
enthält aber auch Entwicklungswerkzeug, Tests und Verwaltungsdokumente; es bekommt
keine automatischen Updates aus dieser Quelle.

## Aufbau und Beiträge

- [.github/copilot-instructions.md](.github/copilot-instructions.md): Pflege dieses Repositorys
- [rules/](rules/): auslieferbare thematische Instructions und Regelvorlage
- [scripts/coding-rules.ps1](scripts/coding-rules.ps1): Installieren, Prüfen und Aktualisieren
- [templates/](templates/): leere Startdateien für Zielprojekte
- [tests/coding-rules.tests.ps1](tests/coding-rules.tests.ps1): isolierte Offline-Tests ohne zusätzliche Module
- [VERSION](VERSION), [CHANGELOG.md](CHANGELOG.md), [LICENSE](LICENSE): Version, Änderungen und Apache-2.0-Lizenz
- [BACKLOG.md](BACKLOG.md), [docs/decisions/](docs/decisions/): Ideen und Entscheidungen dieser Regelsammlung

Für neue Regeln das Format aus [rules/template.instructions.md](rules/template.instructions.md)
verwenden. Jede Regel bleibt fokussiert, eindeutig und frei von unbelegten
projektspezifischen Annahmen. `description` und `applyTo` als zitierte YAML-Strings
angeben. Neue auslieferbare Regeln explizit in den Katalog des Werkzeugs und die
Tests aufnehmen; Vorlagen werden nicht automatisch ausgeliefert.

Tests starten:

```powershell
& .\tests\coding-rules.tests.ps1
```

Die CI führt die Tests unter Windows PowerShell 5.1 und PowerShell 7 auf Windows
sowie PowerShell 7 auf Linux aus. Temporäre Testprojekte werden wieder entfernt.

Nachrichten mit `Idee:` werden in diesem Repository nicht direkt umgesetzt, sondern
mit aktuellem UTC-Zeitstempel im Backlog erfasst. Wesentliche Architekturentscheidungen
werden mit der Vorlage unter `docs/decisions/` dokumentiert.

## Release-Ablauf

1. [VERSION](VERSION) erhöhen und [CHANGELOG.md](CHANGELOG.md) ergänzen.
   Die Versionsangabe am Anfang dieser README und betroffene Beispiele aktualisieren.
2. Tests ausführen, Änderungen prüfen und committen.
3. Einen unveränderlichen Tag passend zu `VERSION` erstellen und pushen:

   ```powershell
   git tag -a v0.1.0 -m "Release 0.1.0"
   git push origin HEAD
   git push origin v0.1.0
   ```

4. Die CI prüft Paket und Tag. Bei Erfolg erstellt sie ein GitHub-Release.
   Veröffentlichte Tags nicht verschieben; Korrekturen bekommen eine neue Version.

Versionsschema: `MAJOR.MINOR.PATCH`. Neue optionale Regeln erhöhen MINOR;
redaktionelle oder kompatible Fehlerkorrekturen PATCH. Inkompatible Änderungen
an Standardverhalten, Profilen, Pfaden oder Manifestformat erhöhen ab `1.0.0` MAJOR.
Während `0.x` werden solche Änderungen mit MINOR und ausdrücklichem Migrationshinweis
veröffentlicht. Auch Änderungen am Regelverhalten gehören ins Changelog.
