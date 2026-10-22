#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Thumbprint,
    [string]$TimestampServer,
    [switch]$AllowUntrustedForTesting
)
$ErrorActionPreference='Stop'
$thumb=$Thumbprint.Replace(' ','')
if ($thumb -notmatch '^[A-Fa-f0-9]{40}$') { throw 'Supply the SHA-1 thumbprint of your existing code-signing certificate.' }
$certificate=Get-Item -LiteralPath "Cert:\CurrentUser\My\$thumb"
if (-not $certificate.HasPrivateKey -or $certificate.NotAfter -le (Get-Date) -or $certificate.NotBefore -gt (Get-Date)) { throw 'A current certificate with its private key is required.' }
$usages=@($certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | ForEach-Object { $_.EnhancedKeyUsages } | ForEach-Object { $_.Value })
if ('1.3.6.1.5.5.7.3.3' -notin $usages) { throw 'Certificate must have the Code Signing usage.' }
if (-not $certificate.Verify() -and -not $AllowUntrustedForTesting) { throw 'Certificate chain is not trusted. Use -AllowUntrustedForTesting only for a private development build; public users will not trust this signature automatically.' }
foreach ($name in @('LMS-Unpacker.exe','LMS-Unpacker-CLI.exe')) {
    $path=Join-Path $PSScriptRoot ('dist/'+$name)
    $options=@{FilePath=$path; Certificate=$certificate; HashAlgorithm='SHA256'}
    if ($TimestampServer) { $options.TimestampServer=$TimestampServer }
    $signature=Set-AuthenticodeSignature @options
    if (-not $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ne $thumb -or
        ($signature.Status -ne 'Valid' -and -not ($AllowUntrustedForTesting -and $signature.Status -eq 'NotTrusted'))) { throw "Signing failed for $name : $($signature.Status)" }
    $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText(($path+'.sha256'),($hash+'  '+$name+[Environment]::NewLine))
    Write-Host "$name : $($signature.Status)"
}
Write-Host 'Checksums refreshed. Signing changes the bytes: previous GitHub attestations do not apply to these local signed files.'
