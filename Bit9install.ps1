$B9Port = "41002"
$B9ServerID = "{b9}"
$B9Server = "bit9.fortifyops.net"
$B9HostGroup = "11"
$B9NoConfig = "0" # value of 1 for no config
$B9ConfigList = "https://$($B9Server)/hostpkg/pkg.php?pkg=configlist.xml"

$PackagePath = Join-Path ($OctopusParameters["Octopus.Action[Deploy Packages].Output.Package.InstallationDirectoryPath"]) "SystemConfig"
Write-Host "PackagePath: $PackagePath"
$PackageSearch = Join-Path $PackagePath "parity*"
Write-Host "PackageSearch: $PackageSearch"


If ($B9NoConfig){
    Get-ChildItem $PackageSearch | ForEach-Object{ & msiexec.exe /i $_.Fullname /qn B9_SERVER_PORT=$B9Port B9_SERVER_ID=$B9ServerID B9_SERVER_IP=$B9Server B9_HOSTGROUP=$B9HostGroup B9_NOCONFIG=$B9NoConfig} 
}
else {
    Get-ChildItem $PackageSearch | ForEach-Object{ & msiexec.exe /i $_.Fullname /qn B9_SERVER_PORT=$B9Port B9_SERVER_ID=$B9ServerID B9_SERVER_IP=$B9Server B9_HOSTGROUP=$B9HostGroup B9_CONFIG=$B9ConfigList} 
}


Write-Host "Disabling Windows Defender"
Set-MpPreference -DisableRealtimeMonitoring $true