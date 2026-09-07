param(
    [string] $Version = '',
    [string] $OutputDirectory = (Join-Path (Get-Location) 'dist'),
    [string] $Ace3Ref = 'd295b12f8b889a30e86e0e901c5494df4b149c49'
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tocPath = Join-Path $repoRoot 'Identity-2.toc'

if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionLine = Get-Content -LiteralPath $tocPath | Where-Object { $_ -match '^## Version:' } | Select-Object -First 1
    if (-not $versionLine) {
        throw 'Could not read addon version from Identity-2.toc.'
    }

    $Version = ($versionLine -replace '^## Version:\s*', '').Trim()
}

$buildRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('Identity2-package-' + [guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $buildRoot 'package/Identity-2'
$libsRoot = Join-Path $packageRoot 'Libs'
$archivePath = Join-Path $OutputDirectory "Identity-2-$Version-full.zip"

$rootFiles = @(
    'Identity-2.toc',
    'Identity-2.lua',
    'embeds.xml',
    'Readme.md',
    'changelog.txt'
)

$libraryNames = @(
    'LibStub',
    'CallbackHandler-1.0',
    'AceAddon-3.0',
    'AceGUI-3.0',
    'AceConfig-3.0',
    'AceConsole-3.0',
    'AceDB-3.0',
    'AceEvent-3.0',
    'AceDBOptions-3.0',
    'AceHook-3.0',
    'AceLocale-3.0'
)

try {
    New-Item -ItemType Directory -Path $libsRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

    foreach ($file in $rootFiles) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination $packageRoot
    }

    Copy-Item -LiteralPath (Join-Path $repoRoot 'locales') -Destination $packageRoot -Recurse

    $aceArchive = Join-Path $buildRoot 'Ace3.zip'
    Invoke-WebRequest `
        -Uri "https://api.github.com/repos/WoWUIDev/Ace3/zipball/$Ace3Ref" `
        -Headers @{ 'User-Agent' = 'Identity2-packaging' } `
        -OutFile $aceArchive

    Expand-Archive -LiteralPath $aceArchive -DestinationPath (Join-Path $buildRoot 'ace3')
    $aceSource = (Get-ChildItem -LiteralPath (Join-Path $buildRoot 'ace3') -Directory | Select-Object -First 1).FullName

    foreach ($library in $libraryNames) {
        $sourcePath = Join-Path $aceSource $library
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
            throw "Ace3 source does not contain required library: $library"
        }

        Copy-Item -LiteralPath $sourcePath -Destination $libsRoot -Recurse
    }

    Copy-Item -LiteralPath (Join-Path $aceSource 'LICENSE.txt') -Destination (Join-Path $libsRoot 'Ace3-LICENSE.txt')

    $aceConfigDialog = Join-Path $libsRoot 'AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua'
    $aceConfigDialogContent = Get-Content -LiteralPath $aceConfigDialog -Raw
    if (-not $aceConfigDialogContent.Contains('C_SettingsUtil')) {
        throw 'Bundled AceConfigDialog does not contain Midnight Settings support.'
    }
    if (-not $aceConfigDialogContent.Contains('return group.frame, group.frame.name')) {
        throw 'Bundled AceConfigDialog does not return the Settings category ID.'
    }

    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    function Test-AddonReference([string] $FilePath) {
        $fullPath = [System.IO.Path]::GetFullPath($FilePath)
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw "Missing addon dependency: $fullPath"
        }

        if (-not $visited.Add($fullPath)) {
            return
        }

        if ([System.IO.Path]::GetExtension($fullPath) -eq '.xml') {
            $reader = [System.Xml.XmlTextReader]::new($fullPath)
            $reader.Namespaces = $false
            $document = [System.Xml.XmlDocument]::new()
            try {
                $document.Load($reader)
            }
            finally {
                $reader.Dispose()
            }

            foreach ($node in $document.SelectNodes('//Script[@file] | //Include[@file]')) {
                Test-AddonReference (Join-Path ([System.IO.Path]::GetDirectoryName($fullPath)) $node.GetAttribute('file'))
            }
        }
    }

    foreach ($line in Get-Content -LiteralPath (Join-Path $packageRoot 'Identity-2.toc')) {
        $entry = $line.Trim()
        if ($entry -and -not $entry.StartsWith('#')) {
            Test-AddonReference (Join-Path $packageRoot $entry)
        }
    }

    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath
    }

    Compress-Archive -LiteralPath $packageRoot -DestinationPath $archivePath -CompressionLevel Optimal

    [pscustomobject]@{
        Archive = $archivePath
        Version = $Version
        Ace3Ref = $Ace3Ref
        Libraries = $libraryNames.Count
        ReferencedFiles = $visited.Count
        Sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    }
}
finally {
    if (Test-Path -LiteralPath $buildRoot) {
        Remove-Item -LiteralPath $buildRoot -Recurse -Force
    }
}