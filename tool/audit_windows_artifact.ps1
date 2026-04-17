[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactPath,

    [switch]$RunDefender,

    [switch]$AsJson,

    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ArtifactType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.exe' { return 'exe' }
        '.dll' { return 'dll' }
        '.msix' { return 'msix' }
        '.appx' { return 'appx' }
        '.msixbundle' { return 'msixbundle' }
        '.appxbundle' { return 'appxbundle' }
        default { return 'other' }
    }
}

function Get-VersionInfoSummary {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $info = $File.VersionInfo
    if ($null -eq $info) {
        return $null
    }

    return [pscustomobject]@{
        companyName      = $info.CompanyName
        fileDescription  = $info.FileDescription
        fileVersion      = $info.FileVersion
        productName      = $info.ProductName
        productVersion   = $info.ProductVersion
        originalFilename = $info.OriginalFilename
    }
}

function Get-AuthenticodeSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $artifactType = Get-ArtifactType -Path $Path
    if ($artifactType -notin @('exe', 'dll', 'msix', 'appx', 'msixbundle', 'appxbundle')) {
        return [pscustomobject]@{
            status              = 'NotApplicable'
            statusMessage       = 'Authenticode wird nur fuer EXE-, DLL- und App-Pakete ausgewertet.'
            signatureType       = $null
            isOSBinary          = $false
            signerSubject       = $null
            signerThumbprint    = $null
            signerNotBefore     = $null
            signerNotAfter      = $null
            timestampSubject    = $null
            timestampThumbprint = $null
        }
    }

    $signature = Get-AuthenticodeSignature -FilePath $Path
    $status = [string]$signature.Status
    $statusMessage = if ($status -eq 'NotSigned') {
        'Die Datei ist nicht digital signiert.'
    }
    elseif ([string]::IsNullOrWhiteSpace($signature.StatusMessage)) {
        $null
    }
    else {
        $signature.StatusMessage
    }
    $signerCertificate = $signature.SignerCertificate
    $timeStamperCertificate = $signature.TimeStamperCertificate

    return [pscustomobject]@{
        status                = $status
        statusMessage         = $statusMessage
        signatureType         = [string]$signature.SignatureType
        isOSBinary            = [bool]$signature.IsOSBinary
        signerSubject         = if ($null -ne $signerCertificate) { $signerCertificate.Subject } else { $null }
        signerThumbprint      = if ($null -ne $signerCertificate) { $signerCertificate.Thumbprint } else { $null }
        signerNotBefore       = if ($null -ne $signerCertificate) { $signerCertificate.NotBefore.ToUniversalTime().ToString('o') } else { $null }
        signerNotAfter        = if ($null -ne $signerCertificate) { $signerCertificate.NotAfter.ToUniversalTime().ToString('o') } else { $null }
        timestampSubject      = if ($null -ne $timeStamperCertificate) { $timeStamperCertificate.Subject } else { $null }
        timestampThumbprint   = if ($null -ne $timeStamperCertificate) { $timeStamperCertificate.Thumbprint } else { $null }
    }
}

function Get-MsixManifestSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $artifactType = Get-ArtifactType -Path $Path
    if ($artifactType -notin @('msix', 'appx', 'msixbundle', 'appxbundle')) {
        return $null
    }

    function Get-XmlNodeText {
        param(
            [Parameter(Mandatory = $true)]
            [string]$XPath
        )

        $node = $manifest.SelectSingleNode($XPath, $ns)
        if ($null -eq $node) {
            return $null
        }

        return $node.InnerText
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)

    try {
        $manifestEntry = $archive.Entries | Where-Object {
            $_.FullName -ieq 'AppxManifest.xml'
        } | Select-Object -First 1

        if ($null -eq $manifestEntry) {
            return $null
        }

        $stream = $manifestEntry.Open()
        $reader = New-Object System.IO.StreamReader($stream)

        try {
            [xml]$manifest = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
            $stream.Dispose()
        }

        $ns = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
        $ns.AddNamespace('appx', $manifest.DocumentElement.NamespaceURI)

        $identity = $manifest.SelectSingleNode('/appx:Package/appx:Identity', $ns)
        $properties = $manifest.SelectSingleNode('/appx:Package/appx:Properties', $ns)
        $capabilityNodes = $manifest.SelectNodes('/appx:Package/appx:Capabilities/*', $ns)
        $capabilities = @()

        foreach ($node in $capabilityNodes) {
            $capabilityName = $node.Name
            if ($node.Attributes['Name']) {
                $capabilityName = $node.Attributes['Name'].Value
            }
            $capabilities += $capabilityName
        }

        return [pscustomobject]@{
            packageName           = if ($null -ne $identity) { $identity.Attributes['Name'].Value } else { $null }
            publisher             = if ($null -ne $identity) { $identity.Attributes['Publisher'].Value } else { $null }
            version               = if ($null -ne $identity) { $identity.Attributes['Version'].Value } else { $null }
            processorArchitecture = if ($null -ne $identity) { $identity.Attributes['ProcessorArchitecture'].Value } else { $null }
            displayName           = Get-XmlNodeText -XPath '/appx:Package/appx:Properties/appx:DisplayName'
            publisherDisplayName  = Get-XmlNodeText -XPath '/appx:Package/appx:Properties/appx:PublisherDisplayName'
            capabilities         = @($capabilities | Sort-Object -Unique)
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Resolve-MpCmdRunPath {
    $candidates = @()

    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe')
    }

    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Windows Defender\MpCmdRun.exe')
    }

    if ($env:ProgramData) {
        $platformRoot = Join-Path $env:ProgramData 'Microsoft\Windows Defender\Platform'
        if (Test-Path -LiteralPath $platformRoot) {
            $candidates += Get-ChildItem -LiteralPath $platformRoot -Directory |
                Sort-Object Name -Descending |
                ForEach-Object { Join-Path $_.FullName 'MpCmdRun.exe' }
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Invoke-DefenderArtifactScan {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $mpCmdRunPath = Resolve-MpCmdRunPath
    if ($null -eq $mpCmdRunPath) {
        return [pscustomobject]@{
            available = $false
            commandPath = $null
            exitCode = $null
            output = 'MpCmdRun.exe wurde nicht gefunden.'
        }
    }

    $output = & $mpCmdRunPath -Scan -ScanType 3 -File $Path 2>&1 | Out-String

    return [pscustomobject]@{
        available = $true
        commandPath = $mpCmdRunPath
        exitCode = $LASTEXITCODE
        output = $output.Trim()
    }
}

$resolvedPath = Resolve-Path -LiteralPath $ArtifactPath
$artifact = Get-Item -LiteralPath $resolvedPath
$hash = Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256
$artifactType = Get-ArtifactType -Path $artifact.FullName

$result = [pscustomobject]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    artifactPath = $artifact.FullName
    artifactName = $artifact.Name
    artifactType = $artifactType
    sizeBytes = [int64]$artifact.Length
    sha256 = $hash.Hash
    lastWriteTimeUtc = $artifact.LastWriteTimeUtc.ToString('o')
    versionInfo = Get-VersionInfoSummary -File $artifact
    authenticode = Get-AuthenticodeSummary -Path $artifact.FullName
    msixManifest = Get-MsixManifestSummary -Path $artifact.FullName
    defenderScan = if ($RunDefender) { Invoke-DefenderArtifactScan -Path $artifact.FullName } else { $null }
}

if ($OutputPath) {
    $outputDirectory = Split-Path -Parent $OutputPath
    if ($outputDirectory) {
        New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    }

    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
}
else {
    $result
}
