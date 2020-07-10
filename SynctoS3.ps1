Function Write-Log { 
    param(  [Parameter(Mandatory=$true)][AllowEmptyString()][string]$LogEntry, 
            [Parameter(Mandatory=$true)][string]$Logfile ) 
    Write-Verbose "Write-Log\LogPath: $($Logfile)"
    Write-Verbose "Write-Log\LogEntry: $($LogEntry)"
    $LogDate = get-date -Format "yyyyMMdd" 
    $LogEntry = "$($LogDate) <$($MyInvocation.ScriptLineNumber)> $($LogEntry)" 
    if(!(Test-Path (Split-Path $Logfile))){ mkdir -Path (Split-Path $Logfile)  | Out-Null}
    if ($Logfile) { Add-content $Logfile -value $LogEntry.replace("`n","") } 
    $Error.Clear()
} 
$Log = "aws-s3-sync.log"
$sw =  [system.diagnostics.stopwatch]::StartNew()
$sw.reset();$sw.Start()
Write-Log "Starting Sync" $Log
try  {
    Get-Date
    Start-Process aws -argument "s3 sync Z:\zeus s3://emea-data-import/Zeus"  -Wait 
    Get-Date
} catch {
    $Error | ForEach-Object{Write-Log $_ $Log}
}
Write-Log "$($sw.Elapsed)" $Log