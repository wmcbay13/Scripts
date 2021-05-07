$BeatVersion = $ELKBeatVersion
$installRootPath   = $ELKInstallPath
$BeatPackage = "filebeat"

    Write-Host "Deploying filebeat"
    $ServiceName= "ELK filebeat"
    if (Get-Service filebeat -ErrorAction SilentlyContinue) {
        Write-Host "Found Service: <filebeat>"
      $service = Get-WmiObject -Class Win32_Service -Filter "name='filebeat'"
      $service.StopService()
      Start-Sleep -s 5
      Start-Process -FilePath sc.exe -ArgumentList "delete filebeat"
      Start-Sleep -s 5
    }
    try{
        Write-Host "Removing filebeat directory"
        (Get-ChildItem $installRootPath -directory | Where-Object{$_ -match "filebeat"}).FullName | Remove-Item -Force -Recurse
    }catch{
        Write-Host "No installation folders found"   
    }
    
    $OSS = ""
    if($ELKBeatOSS){
        $OSS = "-oss"
    } 
    $url = "https://artifacts.elastic.co/downloads/beats/$($BeatPackage)/$($BeatPackage)$($OSS)-$($BeatVersion)-windows-x86_64.zip"
    $url
    # $url = "https://elastic.co/downloads/beats/filebeat/$($OSS)-$($BeatVersion)-windows-x86_64.zip"
    $ArchiveName = [io.path]::GetFileName($url)
    $ArchiveName
    $filename = [io.path]::GetFileNameWithoutExtension($url) 
    $filename
    $downloadfile = Join-path $env:temp ($ArchiveName)
    $downloadfile
    Start-BitsTransfer -Source $url -Destination $downloadfile
    If(-Not (Test-Path $InstallRootPath)){New-Item -ItemType Directory -Path $InstallRootPath -Force}
    Add-Type -assembly "system.io.compression.filesystem"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadfile, $installRootPath)

    $InstallPath = (Get-ChildItem $installRootPath -directory | Where-Object{$_ -match "filebeat"}).FullName
    

    # Create the new service.
    Write-Host "Creating New Service"
    New-Service -name filebeat -displayName $ServiceName -binaryPathName "`"$InstallPath\filebeat.exe`" -c `"$InstallPath\filebeat.yml`" -path.home `"$InstallPath`" -path.data `"$InstallPath\data`" -path.logs `"$InstallPath\logs`" -E logging.files.redirect_stderr=true"

    # Attempt to set the service to delayed start using sc config.
    Try {
      Start-Process -FilePath sc.exe -ArgumentList "config filebeat start= delayed-auto"
    }
    Catch { Write-Host -f red "An error occured setting the service to delayed start." }
