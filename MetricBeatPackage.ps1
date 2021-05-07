$BeatVersion = $ELKBeatVersion
$installRootPath   = $ELKInstallPath
{
    Write-Host "Deploying metricbeat"
    $ServiceName= "ELK metricbeat"
    if (Get-Service metricbeat -ErrorAction SilentlyContinue) {
        Write-Host "Found Service: <metricbeat>"
      $service = Get-WmiObject -Class Win32_Service -Filter "name='metricbeat'"
      $service.StopService()
      Start-Sleep -s 5
      Start-Process -FilePath sc.exe -ArgumentList "delete metricbeat"
      Start-Sleep -s 5
    }
    try{
        Write-Host "Removing metricbeat directory"
        (Get-ChildItem $installRootPath -directory | Where-Object{$_ -match "metricbeat"}).FullName | Remove-Item -Force -Recurse
    }catch{
        Write-Host "No installation folders found"   
    }
    
    $OSS = ""
    if($ELKBeatOSS){
        $OSS = "-oss"
    } 
    $url = "https://artifacts.elastic.co/downloads/beats/$(metricbeat)/$(metricbeat)$($OSS)-$($BeatVersion)-windows-x86_64.zip"
    $ArchiveName = [io.path]::GetFileName($url)
    $filename = [io.path]::GetFileNameWithoutExtension($url) 
    $downloadfile = Join-path $env:temp ($ArchiveName)
    Start-BitsTransfer -Source $url -Destination $downloadfile
    If(-Not (Test-Path $InstallRootPath)){New-Item -ItemType Directory -Path $InstallRootPath -Force}
    Add-Type -assembly "system.io.compression.filesystem"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadfile, $installRootPath)

    $InstallPath = (Get-ChildItem $installRootPath -directory | Where-Object{$_ -match $metricbeat}).FullName
    

    # Create the new service.
    Write-Host "Creating New Service"
    New-Service -name metricbeat -displayName $ServiceName -binaryPathName "`"$InstallPath\metricbeat.exe`" -c `"$InstallPath\metricbeat.yml`" -path.home `"$InstallPath`" -path.data `"$InstallPath\data`" -path.logs `"$InstallPath\logs`" -E logging.files.redirect_stderr=true"

    # Attempt to set the service to delayed start using sc config.
    Try {
      Start-Process -FilePath sc.exe -ArgumentList "config metricbeat start= delayed-auto"
    }
    Catch { Write-Host -f red "An error occured setting the service to delayed start." }
}