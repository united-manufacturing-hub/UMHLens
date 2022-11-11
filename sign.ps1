param (
    [string]$version = $(Read-Host "Lens version")
)
$ErrorActionPreference = "Stop"

$title    = 'Insert HSM'
$question = 'Please insert your HSM and press OK'
$choices  = '&OK', '&Abort'

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -ne 0) {
    exit 1
}

Write-Output "🔐 Signing Lens"
signtool.exe sign /n "UMH Systems GmbH" /t http://time.certum.pl /fd sha1 /v "$pwd\dist\UMHLens-$version.exe"
signtool.exe sign /n "UMH Systems GmbH" /tr http://time.certum.pl /td sha256 /fd sha256 /as /v "$pwd\dist\UMHLens-$version.exe"

# Calculate SHA256
Write-Output "🔐 Calculating SHA256"
$sha256 = Get-FileHash -Path "$pwd\dist\UMHLens-$version.exe" -Algorithm SHA256

# Create checksum file
Write-Output "🔐 Creating checksum file"
$sha256hash = "$($sha256.Hash.ToLower())  UMHLens-$version.exe"
$sha256hash | Out-File -FilePath "$pwd\dist\UMHLens-$version.exe.sha256" -Encoding ASCII

# Finish
Write-Output "✅ Finished"
Write-Output "    Lens is located at $pwd\dist\UMHLens-$version.exe"