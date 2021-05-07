$CertsFolder = "C:\ELK\certs\"
if(-Not (Test-Path $CertsFolder)){New-Item -ItemType Directory -Path $CertsFolder -Force}
Get-ChildItem \\hpfod.net\netlogon\certificates\elk | %{copy-item $_.fullname $CertsFolder -force}

try {
Get-Service -DisplayName "ELK*" | Restart-Service
}
catch {
    Write-Warning "Service Failed to start"
    Write-Host $Error
    
}    