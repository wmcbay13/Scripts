Start-Transcript C:\Choco\InstallLog.txt

#Install Chocolately
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

#Install Filebeat 7.8.0
choco install filebeat -y

#Install Metricbeat 7.8.0
choco install metricbeat -y 

Stop-Transcript