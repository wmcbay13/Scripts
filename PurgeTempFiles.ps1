#run ccleaner
$ccleanerSettingsFile = Join-path (([Environment])::GetEnvironmentVariable("ProgramFiles"))  "ccleaner\winapp2.ini"

$Settings = @"
[.NET Framework *]
LangSecRef=3025
Detect=HKLM\Software\Microsoft\.NETFramework
Default=False
FileKey1=%WinDir%\assembly\NativeImages_*\Temp|*.*|RECURSE
FileKey2=%WinDir%\assembly\t*mp|*.*|REMOVESELF
FileKey3=%WinDir%\Microsoft.NET\Framework*\*\*\Logs|*.*|RECURSE
FileKey4=%WinDir%\Microsoft.NET\Framework*\*\Temporary ASP.NET Files|*.*|RECURSE
FileKey5=%WinDir%\Microsoft.NET\Framework*\v4.0.30319\SetupCache|*.*|RECURSE
FileKey6=%WinDir%\System32\URTTemp|*.*|RECURSE
RegKey1=HKCU\Software\Microsoft\.NETFramework\SQM\Apps

[.NET Framework Isolated Storage *]
LangSecRef=3025
Detect=HKLM\Software\Microsoft\.NETFramework
Default=False
FileKey1=%LocalAppData%\IsolatedStorage|*.*|RECURSE

[Python *]
LangSecRef=3021
Detect=HKCU\Software\Python
Default=False
FileKey1=%ProgramFiles%\Python*|*.icns|RECURSE
FileKey2=%SystemDrive%\Python*|*.icns|RECURSE
"@

Write-Output "Updating ccleaner settings"
Set-Content -Path $ccleanerSettingsFile -Value $Settings

try {
    Start-Process ccleaner -ArgumentList  "/auto" -Wait -WarningAction SilentlyContinue
} catch {
    Write-Output "Failed to clean temp files"
}
try {
    gci C:\users\Public\Desktop\ | remove-item
} catch {
    Write-Output "Failed to remove desktop shortcuts"
}

Write-Output "Finished."