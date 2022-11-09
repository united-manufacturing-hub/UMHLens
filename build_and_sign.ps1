param (
    [string]$version = $(Read-Host "Lens version")
)
$ErrorActionPreference = "Stop"

Function Test-CommandExists

{
    Param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = ‘stop’
    try {if(Get-Command $command){“$command exists”}}
    Catch {“$command does not exist”}
    Finally {$ErrorActionPreference=$oldPreference}
} #end function test-CommandExists

# Check for admin rights
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
if (-not $principal.IsInRole($adminRole)) {
    Write-Error "❌ This script must be run as Administrator"
    exit 1
}

# Install dependencies
Write-Output "📦 Installing optional dependencies"
if (Test-CommandExists "npm")
{
    if (-Not (Test-CommandExists "rimraf"))
    {
        npm install rimraf
    }else{
        Write-Output "✅ rimraf already installed"
    }
}else{
    Write-Output "⚠️ npm not found, skipping optional dependencies"
}

# Remove old build
Write-Output "🗑️ Removing old build"
try
{
    rimraf "lens"
    Write-Output "    ✅ Removed old build"
}
catch
{
    Write-Output "    ℹ️ No old build found"
}


# Clone Lens repo
Write-Output "ℹ️ Cloning Lens repo"
git clone --depth 1 --branch $version https://github.com/lensapp/lens.git

# Restore cache if it exists
Write-Output "ℹ️ Restoring cache"
if (Test-Path "cache")
{
    Write-Output "    ℹ️ Cache found"
    Move-Item -Path node_modules -Destination lens/node_modules -Recurse -Force
    Write-Output "    ✅ Cache restored"
}else{
    Write-Output "    ⚠️ Cache not found"
}

# Build Lens
Write-Output "🔨 Building Lens"
docker run -it `
    -v $PWD/lens:/lens `
    -v ~/.cache/electron:/root/.cache/electron `
    -v ~/.cache/electron-builder:/root/.cache/electron-builder `
    $(docker build -q .)

# Cache node_modules
Write-Output "📦 Caching node_modules"
Move-Item -Path lens/node_modules -Destination node_modules -Recurse -Force

Write-Output "🔐 Signing Lens"
# TODO: Sign Lens
