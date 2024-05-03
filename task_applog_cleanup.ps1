# Delete files in Task AppLogs folder older than 14 days

Get-ChildItem –Path "C:\AppLogs\TaskService" -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-14))} | Remove-Item -Force