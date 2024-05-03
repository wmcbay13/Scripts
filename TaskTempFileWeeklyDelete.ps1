# Delete files in Task temp folder older than 7 days

Get-ChildItem –Path "C:\Users\svc_ams_task\AppData\Local\Temp\nexus-iq\scan-*" -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-7))} | Remove-Item -Force