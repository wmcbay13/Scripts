##Cloudwatch Agent Installation
Invoke-WebRequest -Uri "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi" -OutFile "C:\Temp\amazon-cloudwatch-agent.msi"

msiexec /i C:\Temp\amazon-cloudwatch-agent.msi

