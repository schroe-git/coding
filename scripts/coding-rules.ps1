[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Check', 'Update')]
    [string]$Action,
    [Parameter(Mandatory = $true)]
    [string]$Target,
    [ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$Version,
    [ValidateSet('core', 'ideas', 'adr')]
    [string[]]$Profiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = 'https://github.com/schroe-git/coding'
$manifestRelative = '.github/coding-rules.json'
$source = Split-Path $PSScriptRoot -Parent
$temporary = $null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$catalog = @(
    @{ profile = 'core'; source = 'rules/general-changes.instructions.md'; target = '.github/instructions/coding-general.instructions.md' },
    @{ profile = 'ideas'; source = 'rules/idea-backlog.instructions.md'; target = '.github/instructions/coding-ideas.instructions.md' },
    @{ profile = 'adr'; source = 'rules/architecture-decision-records.instructions.md'; target = '.github/instructions/coding-adr.instructions.md' },
    @{ profile = 'core'; source = 'LICENSE'; target = '.github/instructions/coding-rules/LICENSE.txt' }
)
$scaffolds = @(
    @{ profile = 'ideas'; source = 'templates/BACKLOG.md'; target = 'BACKLOG.md' },
    @{ profile = 'adr'; source = 'docs/decisions/0000-template.md'; target = 'docs/decisions/0000-template.md' }
)

function Get-TargetPath([string]$Relative) {
    $path = $targetRoot
    foreach ($segment in $Relative.Split('/')) {
        $path = Join-Path $path $segment
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Links werden im Installationspfad nicht unterstuetzt: $path"
            }
        }
    }
    return $path
}

function Get-Hash([string]$Path) {
    # Git may check out the same text with LF or CRLF in the consuming project.
    $bytes = $utf8.GetBytes([IO.File]::ReadAllText($Path).Replace("`r`n", "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Write-Text([string]$Path, [string]$Text) {
    [void][IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Assert-ManagedPath([string]$Path) {
    if ($Path -notmatch '^\.github/instructions/coding-[a-z0-9-]+\.instructions\.md$' -and
        $Path -ne '.github/instructions/coding-rules/LICENSE.txt') {
        throw "Ungueltiger verwalteter Pfad im Manifest: $Path"
    }
}

try {
    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        throw "Zielverzeichnis existiert nicht: $Target"
    }
    $targetRoot = (Get-Item -LiteralPath $Target -Force).FullName
    if ((Get-Item -LiteralPath $targetRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Das Zielverzeichnis darf kein Link sein: $targetRoot"
    }
    $manifestPath = Get-TargetPath $manifestRelative
    $installed = $null
    $previous = @{}
    if (Test-Path -LiteralPath $manifestPath) {
        $installed = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($installed.schemaVersion -ne 1 -or $installed.source -ne $repository -or
            $installed.version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
            throw 'Unbekanntes oder ungueltiges Installationsmanifest.'
        }
        foreach ($profile in $installed.profiles) {
            if ($profile -notin @('core', 'ideas', 'adr')) {
                throw "Unbekanntes Profil im Manifest: $profile"
            }
        }
        if ('core' -notin $installed.profiles) {
            throw 'Das Manifest muss das Profil core enthalten.'
        }
        foreach ($file in $installed.files) {
            Assert-ManagedPath $file.path
            if ($previous.ContainsKey($file.path) -or $file.sha256 -notmatch '^[a-f0-9]{64}$') {
                throw "Ungueltiger oder doppelter Dateieintrag: $($file.path)"
            }
            $previous[$file.path] = $file.sha256
        }
        if ($previous.Count -eq 0) {
            throw 'Das Manifest enthaelt keine verwalteten Dateien.'
        }
        $expected = @($catalog | Where-Object { $_.profile -in $installed.profiles } | ForEach-Object { $_.target })
        if (@(Compare-Object @($previous.Keys) $expected).Count -ne 0) {
            throw 'Dateiliste und Profile im Manifest stimmen nicht ueberein.'
        }
    }
    if ($Action -ne 'Install' -and $null -eq $installed) {
        throw 'Keine Installation gefunden. Zuerst Install ausfuehren.'
    }
    if ($Action -eq 'Check' -and ($Version -or $PSBoundParameters.ContainsKey('Profiles'))) {
        throw 'Check prueft ausschliesslich die installierte Version; keine Version oder Profile angeben.'
    }

    $conflicts = @()
    foreach ($relative in $previous.Keys) {
        $path = Get-TargetPath $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $conflicts += "Verwaltete Datei fehlt: $relative"
        } elseif ((Get-Hash $path) -ne $previous[$relative]) {
            $conflicts += "Verwaltete Datei lokal geaendert: $relative"
        }
    }
    if ($conflicts.Count -gt 0) {
        throw ($conflicts -join [Environment]::NewLine)
    }
    if ($Action -eq 'Check') {
        foreach ($entry in $scaffolds) {
            if ($entry.profile -in $installed.profiles -and
                -not (Test-Path -LiteralPath (Get-TargetPath $entry.target) -PathType Leaf)) {
                throw "Workflow-Datei fehlt: $($entry.target)"
            }
        }
        Write-Output "OK: coding-rules $($installed.version); Profile: $($installed.profiles -join ', ')."
        return
    }

    if ($Version) {
        $temporary = Join-Path ([IO.Path]::GetTempPath()) ('coding-rules-' + [guid]::NewGuid().ToString('N'))
        & git -c advice.detachedHead=false clone --quiet --depth 1 --branch $Version "$repository.git" $temporary
        if ($LASTEXITCODE -ne 0) {
            throw "Release $Version konnte nicht geladen werden."
        }
        $source = $temporary
    }
    $packageVersion = (Get-Content -LiteralPath (Join-Path $source 'VERSION') -Raw -Encoding UTF8).Trim()
    if ($packageVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$' -or
        ($Version -and $Version -ne "v$packageVersion")) {
        throw 'VERSION und angeforderter Release-Tag stimmen nicht ueberein.'
    }
    if (-not $PSBoundParameters.ContainsKey('Profiles')) {
        if ($null -ne $installed) {
            $Profiles = @($installed.profiles)
        } else {
            $Profiles = @('core')
        }
    }
    $Profiles = @(@('core') + $Profiles | Sort-Object -Unique)
    $desired = @{}
    $entries = @()
    foreach ($entry in $catalog) {
        if ($entry.profile -notin $Profiles) { continue }
        $sourcePath = Join-Path $source $entry.source.Replace('/', [IO.Path]::DirectorySeparatorChar)
        if ($entry.source.EndsWith('.instructions.md')) {
            $text = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
            if ($text -notmatch '(?s)\A---\r?\ndescription: "[^"\r\n]+"\r?\napplyTo: "[^"\r\n]+"\r?\n---\r?\n') {
                throw "Ungueltiges Frontmatter: $($entry.source)"
            }
        }
        $destination = Get-TargetPath $entry.target
        if (-not $previous.ContainsKey($entry.target) -and (Test-Path -LiteralPath $destination)) {
            throw "Vorhandene, nicht verwaltete Datei wird nicht ueberschrieben: $($entry.target)"
        }
        $desired[$entry.target] = $sourcePath
        $entries += [ordered]@{ path = $entry.target; sha256 = Get-Hash $sourcePath }
    }

    $newScaffolds = @()
    foreach ($entry in $scaffolds) {
        if ($entry.profile -notin $Profiles) { continue }
        $destination = Get-TargetPath $entry.target
        if (Test-Path -LiteralPath $destination) {
            if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
                throw "Erwartete Datei ist ein Verzeichnis: $($entry.target)"
            }
            Write-Output "Beibehalten: $($entry.target)"
        } else {
            $entry.sourcePath = Join-Path $source $entry.source.Replace('/', [IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path -LiteralPath $entry.sourcePath -PathType Leaf)) {
                throw "Vorlage fehlt: $($entry.source)"
            }
            $newScaffolds += $entry
        }
    }

    # Validate all destinations before changing any project files.
    foreach ($relative in @($desired.Keys) + @($newScaffolds | ForEach-Object { $_.target })) {
        $path = Get-TargetPath $relative
        $parent = Split-Path $path -Parent
        while ($parent -ne $targetRoot -and -not (Test-Path -LiteralPath $parent)) {
            $parent = Split-Path $parent -Parent
        }
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            throw "Ein Elternpfad ist kein Verzeichnis: $parent"
        }
    }
    foreach ($relative in $desired.Keys) {
        $path = Get-TargetPath $relative
        if (-not $previous.ContainsKey($relative) -or $previous[$relative] -ne (Get-Hash $desired[$relative])) {
            [void][IO.Directory]::CreateDirectory((Split-Path $path -Parent))
            Copy-Item -LiteralPath $desired[$relative] -Destination $path
        }
    }
    foreach ($relative in $previous.Keys) {
        if (-not $desired.ContainsKey($relative)) {
            Remove-Item -LiteralPath (Get-TargetPath $relative)
        }
    }
    foreach ($entry in $newScaffolds) {
        $path = Get-TargetPath $entry.target
        [void][IO.Directory]::CreateDirectory((Split-Path $path -Parent))
        Copy-Item -LiteralPath $entry.sourcePath -Destination $path
    }
    $manifest = [ordered]@{
        schemaVersion = 1
        source = $repository
        version = $packageVersion
        profiles = @($Profiles)
        files = @($entries)
    }
    $json = ($manifest | ConvertTo-Json -Depth 5).Replace("`r`n", "`n") + "`n"
    if (-not (Test-Path -LiteralPath $manifestPath) -or
        [IO.File]::ReadAllText($manifestPath).Replace("`r`n", "`n") -cne $json) {
        Write-Text $manifestPath $json
    }
    Write-Output "OK: coding-rules $packageVersion installiert; Profile: $($Profiles -join ', ')."
} finally {
    if ($temporary -and (Test-Path -LiteralPath $temporary)) {
        Remove-Item -LiteralPath $temporary -Recurse -Force
    }
}
