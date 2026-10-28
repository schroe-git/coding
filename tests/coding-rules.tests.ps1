Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('coding-rules-tests-' + [guid]::NewGuid().ToString('N'))
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:passed = 0
$initialVersion = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$parsedVersion = [version]$initialVersion
$updatedVersion = '{0}.{1}.{2}' -f $parsedVersion.Major, $parsedVersion.Minor, ($parsedVersion.Build + 1)

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Test-Case([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:passed++
    Write-Output "PASS: $Name"
}

function Write-Text([string]$Path, [string]$Text) {
    [void][IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Expect-Failure([scriptblock]$Body, [string]$Pattern) {
    $failure = $null
    try { & $Body | Out-Null } catch { $failure = $_ }
    Assert ($null -ne $failure) "Erwarteter Fehler blieb aus: $Pattern"
    Assert ($failure.ToString() -match $Pattern) "Unerwarteter Fehler: $failure"
}

function Snapshot([string]$Directory) {
    return (@(Get-ChildItem -LiteralPath $Directory -Recurse -File -Force |
        Sort-Object FullName | ForEach-Object {
            $_.FullName.Substring($Directory.Length) + ':' +
            (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }) -join "`n")
}

try {
    [void][IO.Directory]::CreateDirectory($sandbox)
    $package = Join-Path $sandbox 'package'
    [void][IO.Directory]::CreateDirectory($package)
    foreach ($name in @('scripts', 'rules', 'docs', 'templates', 'VERSION', 'LICENSE')) {
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination $package -Recurse
    }
    $tool = Join-Path (Join-Path $package 'scripts') 'coding-rules.ps1'
    $target = Join-Path $sandbox 'project with spaces'
    [void][IO.Directory]::CreateDirectory($target)
    $manifestPath = Join-Path $target '.github\coding-rules.json'.Replace('\', [IO.Path]::DirectorySeparatorChar)
    $general = Join-Path $target '.github\instructions\coding-general.instructions.md'.Replace('\', [IO.Path]::DirectorySeparatorChar)
    $ideas = Join-Path $target '.github\instructions\coding-ideas.instructions.md'.Replace('\', [IO.Path]::DirectorySeparatorChar)
    $backlog = Join-Path $target 'BACKLOG.md'
    $adr = Join-Path $target 'docs\decisions\0000-template.md'.Replace('\', [IO.Path]::DirectorySeparatorChar)

    Test-Case 'Frontmatter und Version' {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root 'rules') -Filter '*.instructions.md') {
            Assert ((Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8) -match
                '(?s)\A---\r?\ndescription: "[^"\r\n]+"\r?\napplyTo: "[^"\r\n]+"\r?\n---\r?\n') "Frontmatter: $($file.Name)"
        }
        $version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
        Assert ($version -match '^[0-9]+\.[0-9]+\.[0-9]+$') 'Ungueltige Version'
        Assert ((Get-Content -LiteralPath (Join-Path $root 'CHANGELOG.md') -Raw) -match
            [regex]::Escape("## [$version]")) 'Release fehlt im Changelog'
    }
    Test-Case 'Core installieren ohne Projektregeln zu ersetzen' {
        $localRules = Join-Path $target '.github\copilot-instructions.md'.Replace('\', [IO.Path]::DirectorySeparatorChar)
        Write-Text $localRules '# Project rules'
        & $tool -Action Install -Target $target
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        Assert ($manifest.version -eq $initialVersion) 'Version fehlt'
        Assert ($manifest.files.Count -eq 2) 'Core muss Regel und Lizenz enthalten'
        Assert (Test-Path -LiteralPath $general) 'Core fehlt'
        Assert (-not (Test-Path -LiteralPath $ideas)) 'Ideas wurde ungefragt installiert'
        Assert (-not (Test-Path -LiteralPath $backlog)) 'Backlog wurde ungefragt erstellt'
        Assert ((Get-Content -LiteralPath $localRules -Raw) -eq '# Project rules') 'Projektregeln ersetzt'
        Assert (@(Get-ChildItem -LiteralPath $target -Recurse -Filter '*template.instructions.md').Count -eq 0) 'Regelvorlage installiert'
    }
    Test-Case 'Check und erneute Installation sind schreibfrei' {
        $before = Snapshot $target
        $stamp = (Get-Item -LiteralPath $manifestPath).LastWriteTimeUtc
        & $tool -Action Check -Target $target
        & $tool -Action Install -Target $target
        Assert ((Snapshot $target) -ceq $before) 'Installation ist nicht idempotent'
        Assert ((Get-Item -LiteralPath $manifestPath).LastWriteTimeUtc -eq $stamp) 'Manifest wurde neu geschrieben'
        Expect-Failure { & $tool -Action Check -Target $target -Version v0.1.0 } 'ausschliesslich'
    }
    Test-Case 'Optionale Profile bewahren bestehende Arbeitsdateien' {
        Write-Text $backlog '# Existing backlog'
        Write-Text $adr '# Existing ADR template'
        & $tool -Action Update -Target $target -Profiles ideas, adr
        Assert ((Get-Content -LiteralPath $backlog -Raw) -eq '# Existing backlog') 'Backlog ersetzt'
        Assert ((Get-Content -LiteralPath $adr -Raw) -eq '# Existing ADR template') 'ADR-Vorlage ersetzt'
        Assert (Test-Path -LiteralPath $ideas) 'Ideas fehlt'
        & $tool -Action Check -Target $target
        & $tool -Action Update -Target $target
        Assert (Test-Path -LiteralPath $ideas) 'Profilwahl wurde vergessen'
    }
    Test-Case 'Lokale Aenderungen blockieren vor jedem Schreibzugriff' {
        $original = [IO.File]::ReadAllText($general)
        Write-Text $general ($original + "`nLocal edit")
        $before = Snapshot $target
        Expect-Failure { & $tool -Action Update -Target $target -Profiles core } 'lokal geaendert'
        Expect-Failure { & $tool -Action Check -Target $target } 'lokal geaendert'
        Assert ((Snapshot $target) -ceq $before) 'Konflikt hat Projektdateien geaendert'
        Write-Text $general $original
    }
    Test-Case 'CRLF statt LF ist keine lokale Inhaltsaenderung' {
        $original = [IO.File]::ReadAllText($general)
        Write-Text $general ($original.Replace("`r`n", "`n").Replace("`n", "`r`n"))
        $manifestText = [IO.File]::ReadAllText($manifestPath)
        Write-Text $manifestPath ($manifestText.Replace("`r`n", "`n").Replace("`n", "`r`n"))
        $before = Snapshot $target
        & $tool -Action Check -Target $target
        & $tool -Action Update -Target $target
        Assert ((Snapshot $target) -ceq $before) 'Zeilenenden haben Schreibzugriff ausgeloest'
    }
    Test-Case 'Neue Paketversion aktualisiert Regeln und Manifest' {
        Write-Text (Join-Path $package 'VERSION') "$updatedVersion`n"
        $sourceRule = Join-Path $package 'rules\general-changes.instructions.md'.Replace('\', [IO.Path]::DirectorySeparatorChar)
        Write-Text $sourceRule ([IO.File]::ReadAllText($sourceRule) + "`n- New release rule.`n")
        & $tool -Action Update -Target $target
        Assert ((Get-Content -LiteralPath $general -Raw) -match 'New release rule') 'Regel nicht aktualisiert'
        Assert ((Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).version -eq $updatedVersion) 'Manifest nicht aktualisiert'
        & $tool -Action Check -Target $target
    }
    Test-Case 'Abgewaehlte Profile entfernen nur unveraenderte verwaltete Regeln' {
        & $tool -Action Update -Target $target -Profiles core
        Assert (-not (Test-Path -LiteralPath $ideas)) 'Ideas nicht entfernt'
        Assert (Test-Path -LiteralPath $backlog) 'Backlog geloescht'
        Assert (Test-Path -LiteralPath $adr) 'ADR-Vorlage geloescht'
    }
    Test-Case 'Unverwaltete Zielkollision blockiert das gesamte Update' {
        Write-Text $ideas '# User-owned rule'
        $before = Snapshot $target
        Expect-Failure { & $tool -Action Update -Target $target -Profiles ideas } 'nicht verwaltete Datei'
        Assert ((Snapshot $target) -ceq $before) 'Zielkollision hat Dateien geaendert'
        Remove-Item -LiteralPath $ideas
    }
    Test-Case 'Fehlende verwaltete Datei wird explizit gemeldet' {
        $original = [IO.File]::ReadAllText($general)
        Remove-Item -LiteralPath $general
        Expect-Failure { & $tool -Action Check -Target $target } 'Datei fehlt'
        Expect-Failure { & $tool -Action Update -Target $target } 'Datei fehlt'
        Write-Text $general $original
    }
    Test-Case 'Manipulierte Manifestpfade werden abgelehnt' {
        $original = [IO.File]::ReadAllText($manifestPath)
        $manifest = $original | ConvertFrom-Json
        $manifest.files[0].path = '../outside.txt'
        Write-Text $manifestPath ($manifest | ConvertTo-Json -Depth 5)
        $before = Snapshot $target
        Expect-Failure { & $tool -Action Update -Target $target } 'Ungueltiger verwalteter Pfad'
        Assert ((Snapshot $target) -ceq $before) 'Ungueltiges Manifest hat Dateien geaendert'
        Write-Text $manifestPath $original
    }
    Test-Case 'Unvollstaendige Manifeste werden abgelehnt' {
        $original = [IO.File]::ReadAllText($manifestPath)
        $manifest = $original | ConvertFrom-Json
        $manifest.files = @($manifest.files[0])
        Write-Text $manifestPath ($manifest | ConvertTo-Json -Depth 5)
        Expect-Failure { & $tool -Action Check -Target $target } 'Dateiliste und Profile'
        Write-Text $manifestPath $original
    }
    Test-Case 'Fehlende Workflow-Vorlagen werden erstellt, nicht verwaltet' {
        $fresh = Join-Path $sandbox 'fresh'
        [void][IO.Directory]::CreateDirectory($fresh)
        & $tool -Action Install -Target $fresh -Profiles ideas, adr
        $freshBacklog = Join-Path $fresh 'BACKLOG.md'
        $freshAdr = Join-Path $fresh 'docs\decisions\0000-template.md'.Replace('\', [IO.Path]::DirectorySeparatorChar)
        Assert (Test-Path -LiteralPath $freshBacklog) 'Backlog fehlt'
        Assert (Test-Path -LiteralPath $freshAdr) 'ADR-Vorlage fehlt'
        Write-Text $freshBacklog '# User ideas'
        & $tool -Action Check -Target $fresh
        Remove-Item -LiteralPath $freshAdr
        Expect-Failure { & $tool -Action Check -Target $fresh } 'Workflow-Datei fehlt'
        & $tool -Action Update -Target $fresh
        Assert ((Get-Content -LiteralPath $freshBacklog -Raw) -eq '# User ideas') 'Ideen ersetzt'
    }
    Test-Case 'Verzeichniskollisionen blockieren vor Installation' {
        $collision = Join-Path $sandbox 'collision'
        [void][IO.Directory]::CreateDirectory($collision)
        Write-Text (Join-Path $collision '.github') 'not a directory'
        $before = Snapshot $collision
        Expect-Failure { & $tool -Action Install -Target $collision } 'kein Verzeichnis'
        Assert ((Snapshot $collision) -ceq $before) 'Verzeichniskollision hat Dateien geaendert'
    }
    Test-Case 'Links in Installationspfaden werden abgelehnt' {
        $linked = Join-Path $sandbox 'linked'
        $outside = Join-Path $sandbox 'outside'
        [void][IO.Directory]::CreateDirectory($linked)
        [void][IO.Directory]::CreateDirectory($outside)
        $link = Join-Path $linked '.github'
        if ($env:OS -eq 'Windows_NT') {
            [void](New-Item -ItemType Junction -Path $link -Target $outside)
        } else {
            [void](New-Item -ItemType SymbolicLink -Path $link -Target $outside)
        }
        try {
            Expect-Failure { & $tool -Action Install -Target $linked } 'Links werden'
            Assert (@(Get-ChildItem -LiteralPath $outside -Force).Count -eq 0) 'Linkziel wurde veraendert'
        } finally {
            [IO.Directory]::Delete($link)
        }
    }
    Test-Case 'Update ohne Installation und unbekannte Profile scheitern' {
        $empty = Join-Path $sandbox 'empty'
        [void][IO.Directory]::CreateDirectory($empty)
        Expect-Failure { & $tool -Action Update -Target $empty } 'Keine Installation'
        Expect-Failure { & $tool -Action Install -Target $empty -Profiles unknown } 'ValidateSet|validation|Validierung'
    }
    Test-Case 'Versionierter Bezug klont einen Tag und fuehrt keinen fremden Code aus' {
        $gitExecutable = (Get-Command git -CommandType Application).Source
        $remote = Join-Path $sandbox 'release-source'
        [void][IO.Directory]::CreateDirectory($remote)
        foreach ($name in @('rules', 'docs', 'templates', 'VERSION', 'LICENSE')) {
            Copy-Item -LiteralPath (Join-Path $package $name) -Destination $remote -Recurse
        }
        Copy-Item -LiteralPath (Join-Path $root '.gitattributes') -Destination $remote
        Write-Text (Join-Path $remote 'scripts\coding-rules.ps1'.Replace('\', [IO.Path]::DirectorySeparatorChar)) "throw 'Downloaded code must not run'"
        & $gitExecutable -C $remote init --quiet
        if ($LASTEXITCODE -ne 0) { throw 'Test-Repository konnte nicht erstellt werden' }
        & $gitExecutable -C $remote -c core.safecrlf=false add .
        if ($LASTEXITCODE -ne 0) { throw 'Testdateien konnten nicht hinzugefuegt werden' }
        & $gitExecutable -C $remote -c user.name=Test -c user.email=test@example.invalid -c commit.gpgSign=false commit --quiet -m "Test fixture" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
        if ($LASTEXITCODE -ne 0) { throw 'Test-Commit konnte nicht erstellt werden' }
        & $gitExecutable -C $remote tag "v$updatedVersion"
        if ($LASTEXITCODE -ne 0) { throw 'Test-Tag konnte nicht erstellt werden' }
        & $gitExecutable -C $remote tag v99.99.99
        if ($LASTEXITCODE -ne 0) { throw 'Test-Tag konnte nicht erstellt werden' }
        $releaseTarget = Join-Path $sandbox 'release-target'
        [void][IO.Directory]::CreateDirectory($releaseTarget)
        $downloadState = @{ directory = $null }

        # Only replace the transport URL; exercise the real git clone and tag checkout.
        function git {
            $cloneArgs = @($args)
            $urlIndex = [array]::IndexOf($cloneArgs, 'https://github.com/schroe-git/coding.git')
            Assert ($urlIndex -ge 0) 'Unerwartete Downloadquelle'
            $cloneArgs[$urlIndex] = ([uri]($remote + [IO.Path]::DirectorySeparatorChar)).AbsoluteUri
            $downloadState.directory = $cloneArgs[-1]
            & $gitExecutable @cloneArgs
            $global:LASTEXITCODE = $LASTEXITCODE
        }
        & $tool -Action Install -Target $releaseTarget -Version "v$updatedVersion"
        Assert (-not (Test-Path -LiteralPath $downloadState.directory)) 'Download nicht entfernt'
        & $tool -Action Check -Target $releaseTarget
        $before = Snapshot $releaseTarget
        Expect-Failure { & $tool -Action Update -Target $releaseTarget -Version v99.99.99 } 'VERSION und angeforderter'
        Assert ((Snapshot $releaseTarget) -ceq $before) 'Falscher Tag hat Ziel veraendert'
        Assert (-not (Test-Path -LiteralPath $downloadState.directory)) 'Fehlerhafter Download nicht entfernt'
    }
    Test-Case 'Fehlgeschlagener Release-Bezug veraendert das Ziel nicht' {
        $before = Snapshot $target
        function git { $global:LASTEXITCODE = 1 }
        Expect-Failure { & $tool -Action Update -Target $target -Version v99.99.99 } 'konnte nicht geladen werden'
        Assert ((Snapshot $target) -ceq $before) 'Fehlgeschlagener Download hat Ziel veraendert'
    }
    Write-Output "$script:passed Tests erfolgreich."
} finally {
    if (Test-Path -LiteralPath $sandbox) {
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
