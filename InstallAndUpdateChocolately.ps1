Write-Output "Verifying Chocolatey installation"

$chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "Machine") + "\bin"
if(-not (Test-Path $chocolateyBin)) {
    Write-Output "Environment variable 'ChocolateyInstall' was not found in the system variables. Attempting to find it in the user variables..."
    $chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "User") + "\bin"
}
$chocInstalled = Test-Path "$chocolateyBin\cinst.exe"
try {
    choco
} catch {
    if($chocInstalled){
        if(-not $env:path -match "choco"){
            $Env:path += ";C:\ProgramData\chocolatey\bin"
        }
    }
    $chocInstalled = $false
}

if (-not $chocInstalled) {
    Write-Output "Chocolatey not found, installing..."
    $LocalChocoInstall = Join-Path $ChocolateyUNC "files\ChocolateyLocalInstall.ps1"
    Write-Output "Chocolatey path $LocalChocoInstall"
    if(Test-Path $LocalChocoInstall) {
        Unblock-File -Path $LocalChocoInstall
        $installPs1 = "& $LocalChocoInstall"
    } else {
        Write-Output "Installer not found, Downloading from chocolatey.org"
        $installPs1 = "iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))"
    }
    Write-Output "Installation running"
    try {
        Start-Process powershell -argument $installPs1 -wait -NoNewWindow -ErrorAction SilentlyContinue
    }catch {
        Write-Output "$Error"
        $LastExitCode = 0
    }
    Write-Output "Installation Complete"
    $Env:Path += ";C:\ProgramData\chocolatey\bin"
    refreshenv
}
$powa = get-process -name powershell -IncludeUserName
Write-Output "$($powa.Username) : $($powa.ProcessName)"

$ChocoDetails = (choco upgrade chocolatey --noop -r).Split("|")
[System.Version]$ChocoVersion = $ChocoDetails[1]
[System.Version]$ChocoLatest  = $ChocoDetails[2]
$ChocoUpgrade = [System.Convert]::ToBoolean($ChocoDetails[3])
Write-Output "Chocolatey $ChocoVersion installed."

#Disable Chocolatey download progress as it overloads log files
& choco feature disable -n=showDownloadProgress
$LocalChocoPackages = Join-Path $ChocolateyUNC "packages"
& choco source add -n=FileServer -s="$LocalChocoPackages" --priority=1

if ($ChocoUpgrade){
    if ($ChocolateyVersion -eq "Latest" -or [string]::IsNullOrEmpty($ChocolateyVersion)){
            Write-Output "Upgrading Chocolatey to the latest version"
            & choco upgrade chocolatey -y
    } elseif ([System.Version]$ChocolateyVersion -gt [System.Version]$ChocoVersion) {
        Write-Output "Upgrading Chocolatey to version $ChocolateyVersion"
        & choco upgrade -version $ChocolateyVersion -y
    } elseif ([System.Version]$ChocolateyVersion -eq [System.Version]$ChocoVersion) {
        Write-Output "Chocolatey is currently installed with approved version"
    } else {
        Write-Warning "Installed Chocolatey version $($ChocoVersion) is newer than approved version $ChocolateyVersion" -ErrorAction SilentlyContinue
    }
    refreshenv
} elseif($ChocolateyVersion -ne "Latest"){
    if ([System.Version]$ChocolateyVersion -lt [System.Version]$ChocoVersion) {
        Write-Warning "Installed Chocolatey version $($ChocoVersion) is newer than approved version $ChocolateyVersion" -ErrorAction SilentlyContinue
    } else {
        Write-Output "Chocolatey is currently installed with approved version"
    }
}

$chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "Machine") + "\bin"
$chocolateyTools = [System.Environment]::GetEnvironmentVariable("ChocolateyInstall", "Machine") + "\tools"
if(-not (Test-Path $chocolateyBin)) {
    Write-Output "Environment variable 'ChocolateyInstall' was not found in the system variables. Attempting to find it in the user variables..."
    $chocolateyBin = [Environment]::GetEnvironmentVariable("ChocolateyInstall", "User") + "\bin"
    $chocolateyTools = [System.Environment]::GetEnvironmentVariable("ChocolateyInstall", "User") + "\tools"
}
[System.Environment]::SetEnvironmentVariable("ChocolateyToolsLocation", $chocolateyTools, "Machine")
$Env:ChocolateyToolsLocation = $chocolateyTools
Set-Location $chocolateyTools


Write-Host "Finished"

