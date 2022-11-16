param (
    [string]$version = $(Read-Host "Lens version")
)
$ErrorActionPreference = "Stop"

# https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
# By Ed Wilson (Doctor Scripto)
Function Test-CommandExists
{
    Param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = ‘stop’
    try {if(Get-Command $command){“$command exists”}}
    Catch {“$command does not exist”}
    Finally {$ErrorActionPreference=$oldPreference}
} #end function test-CommandExists

# https://stackoverflow.com/a/21422517
# By SoftwareCarpenter under CC BY-SA 4.0
function DownloadFile($url, $targetFile)
{
    $uri = New-Object "System.Uri" "$url"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.set_Timeout(15000) #15 second timeout
    $response = $request.GetResponse()
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
    $responseStream = $response.GetResponseStream()
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
    $buffer = new-object byte[] 10KB
    $count = $responseStream.Read($buffer,0,$buffer.length)
    $downloadedBytes = $count
    while ($count -gt 0)

    {
        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer,0,$buffer.length)
        $downloadedBytes = $downloadedBytes + $count
        Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)

    }
    Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"
    $targetStream.Flush()
    $targetStream.Close()
    $targetStream.Dispose()
    $responseStream.Dispose()

}

# Current directory
$pwd = Get-Location

# Check for admin permissions
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
if (-not $principal.IsInRole($adminRole)) {
    Write-Error "❌ This script must be run as Administrator"
    exit 1
}

# Check if git-bash is installed to C:\Program Files\Git\git-bash.exe
if (Test-CommandExists "C:\Program Files\Git\git-bash.exe") {
    Write-Host "✅ git-bash is installed"
} else {
    Write-Error "❌ git-bash is not installed"
    exit 1
}


# Install rimraf using npm if not already installed
Write-Output "🔎 Checking for rimraf..."
if (Test-CommandExists rimraf) {
    Write-Output "    ✅ rimraf is installed"
} else {
    Write-Output "❌ rimraf is not installed"
    Write-Output "Installing rimraf..."
    npm install rimraf
}

# Check if already cloned
Write-Output "🔎 Checking if Lens repo is cloned..."
if (Test-Path "$pwd\lens") {
    Write-Output "    ✅ Lens repo is cloned"
    Write-Output "    Resetting package.json to HEAD"
    git -C "$pwd\lens" checkout HEAD -- package.json
    git -C "$pwd\lens" checkout HEAD -- sh.exe.stackdump
    # Check if already on correct branch
    Write-Output "🔎 Checking if on correct branch..."
    $tag = git -C "$pwd\lens" describe --tags
    if ($tag -eq $version) {
        Write-Output "    ✅ Already on correct branch"
    } else {
        Write-Output "    ❌ Not on correct branch"
        Write-Output "    Updating repo..."
        git -C "$pwd\lens" fetch --all
        Write-Output "    Checking out correct branch..."
        git -C "$pwd\lens" checkout $version
        if ($?) {
            Write-Output "    ✅ Checked out correct branch"
        } else {
            Write-Output "    ❌ Failed to checkout correct branch"
            exit 1
        }
    }
} else
{
    Write-Output "❌ Lens repo is not cloned"
    # Clone repo
    Write-Output "🔍 Cloning Lens repo"
    git clone https://github.com/lensapp/lens.git
    if ($?)
    {
        Write-Output "✅ Lens repo cloned"
    }
    else
    {
        Write-Error "❌ Lens repo failed to clone"
        exit 1
    }
}

# Remove dist folder from lens
rimraf "$pwd\lens\dist"

# Copy update.js into lens repo
Write-Output "🔍 Copying update.js into Lens repo"
Copy-Item -Path "$pwd\update.js" -Destination "$pwd\lens\update.js" -Force

# Replace OpenLens with UMHLens in package.json
Write-Output "🔎 Checking if package.json is correct..."
$package = Get-Content "$pwd\lens\package.json" | ConvertFrom-Json -Depth 512
if ($package.productName -eq "UMHLens") {
    Write-Output "    ✅ package.json is correct"
} else {
    Write-Output "    ❌ package.json is not correct"
    Write-Output "    Replacing OpenLens with UMHLens in package.json"
    $package.productName = "UMHLens"
    $package | ConvertTo-Json -Depth 100 | Set-Content "$pwd\lens\package.json"
    Write-Output "    ✅ package.json is correct"
}

# Build Lens
Write-Output "🔨 Building Lens (this may take a while)"

# Building docker image
C:\PROGRA~1\Git\git-bash.exe -c "pwd; cd lens; node update.js; make build -j16 > ../build.log 2>&1"
if ($?) {
    Write-Output "    ✅ Lens built started"
} else {
    Write-Error "    ❌ Failed to build Lens"
    exit 1
}

Start-Sleep -Seconds 10

# Await Lens build
Write-Output "    ⌛ Waiting for Lens build to finish..."
Wait-Process -Name mintty

Write-Output "✅ Lens build finished"
Write-Output "    🔎 Check the build.log file for any errors"

# Copy built Lens
Write-Output "📦 Copying built Lens"

# Create output directory if not exists
if (-not (Test-Path -Path "$pwd\dist")) {
    New-Item -ItemType Directory -Path "$($pwd)\dist"
    if ($?) {
        Write-Output "✅ dist folder created"
    } else {
        Write-Error "❌ Failed to create dist folder"
        exit 1
    }
}

# Parse package.json for version
$package = Get-Content -Path "$pwd\lens\package.json" | ConvertFrom-Json
$pVersion = $package.version

# Copy built Lens
Copy-Item -Path "$pwd\lens\dist\UMHLens.Setup.$pVersion.exe" -Destination "$pwd\dist\UMHLens-$version.exe"

Write-Output "✅ Built Lens copied to dist folder"
Write-Output "🔐 Use the sign.ps1 script to sign the built Lens"