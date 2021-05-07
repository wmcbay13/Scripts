﻿<#   
.SYNOPSIS   
Archive files from specified list
    
.DESCRIPTION 
This script will parse a list of files to archive to the desired location

.PARAMETER DestinationPath
The location where the new archive will be created

.PARAMETER ListPath
The file that will be parsed to archive

.PARAMETER Label
Insert text into file name to differentiate it from other archives.

.PARAMETER Compress
Compress the archive with 7zip

.NOTES   
Name:        Archive-FilerCluster.ps1
Author:      Michael Stanton
DateUpdated: 2018-06-13
Version:     1.0

.EXAMPLE   
.\Archive-FilerCluster.ps1
    
Description 
-----------     
This command runs the script with default options.

.EXAMPLE
gci Z:\archive\* -file -include *.txt | sort Length | %{.\Archive-FilerCluster.ps1 -ListPath $_.VersionInfo.FileName}

Description
-----------
This command adds a new folder to backup and changes the backup location
#>
[cmdletbinding(SupportsShouldProcess)]
param (
    [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]
    [Alias('SP')]
        [string]  $DestinationPath = "\\psmfiles\FilerCluster",
    [Alias('LP')]
        [string]  $ListPath,
    [Alias('L')]
        [string]  $Label,
    [Alias('A')]
        [switch]  $NoCompress,
    [Alias('LF')]
        [string]  $LogFile = "$env:SYSTEMDRIVE\Logs\ArchiveFilerCluster.log"
)
#PREPARE STANDARD SCRIPT ENVIRONMENT
$StartTime = Get-Date
$Error.Clear()
Set-StrictMode -Version 2.0
Import-Module BitsTransfer
#Load useful functions 
if(Test-Path ".\Custom-Functions.ps1"){. ".\Custom-Functions.ps1"}
elseif(Test-Path "S:\Custom-Functions.ps1"){. "S:\Custom-Functions.ps1"}
elseif(Test-Path "C:\Scripts\Custom-Functions.ps1"){. "C:\Scripts\Custom-Functions.ps1"}
elseif(Test-Path "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"){. "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"}

#VALIDATE PARAMETERS
Write-Info "Valid Logfile: $(Validate-Log $LogFile)" $LogFile
Write-Info "Valid ListPath: $(Validate-Path $ListPath -Exit $LogFile)" $LogFile
Write-Info "Valid DestinationPath: $(Validate-Path $DestinationPath -Exit $LogFile)" $LogFile

#Checking Compression Utilitiy
if(!($NoCompress)){
    $Compress = $true
    $7z = "C:\Scripts\7z.exe"    
    If(!(Validate-Path $7z)){    
        $7z = "\\hpfod.net\NETLOGON\7z.exe"
        $Compress = Validate-Path $7z 
    }
}


#INITIALIZE VARIABLES
$FileName = ([System.IO.Path]::GetFileNameWithoutExtension($ListPath)).Split("-")
$Tenant = $FileName[0]
If($Label -eq "" -and $FileName[1] -ne ""){
$Label = "-$($FileName[1])"
}


function Compress-File {
    param(  [Parameter(Mandatory=$true)][string]$BigFileName,
            [Parameter(Mandatory=$true)][string]$SmallFileName)
    $CompressionMethod = "ppmd"
    $PPMdRAM = "256"
    $PPMdSwitch = "-m0=PPMd:mem"+$PPMdRAM+"m"
    try{
        Write-Info "Compressing: $($BigFileName)" $LogFile -Progress            
        $Arguments = @()
        $Arguments += "a"
        $Arguments += "-t7z"
        $Arguments += "-sdel"
        $Arguments += "-stl"
        $Arguments += "-spf2"
        $Arguments += "-bd"
        $Arguments += $PPMdSwitch
        $Arguments += $SmallFileName
        $Arguments += $BigFileName
        $7zip = &$7z $Arguments
        Write-Done "" $LogFile -Progress
    }
    catch{
        $Error | %{ Write-Info $_ $LogFile}
    }
}

function Test-FileLock {
  param (
    [parameter(Mandatory=$true)][string]$Path
  )

  $oFile = New-Object System.IO.FileInfo $Path

  if ((Test-Path -Path $Path) -eq $false) {
    return $false
  }

  try {
    $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)

    if ($oStream) {
      $oStream.Close()
    }
    $false
  } catch {
    # file is locked by a process.
    return $true
  }
}

[Scriptblock]$TransferJob = {
    param(  [Parameter(Mandatory=$true)]$JobFile, 
            [Parameter(Mandatory=$true)]$Destination)
    If(!(Test-Path (Split-Path $Destination))){
        mkdir -Path (Split-Path $Destination) | Out-Null
    }
    $Job = Start-BitsTransfer -Source $JobFile -Destination $Destination -Asynchronous -TransferType Upload -DisplayName ([System.IO.Path]::GetFileNameWithoutExtension($JobFile))
    sleep 5
    While(($Job.JobState -eq "Transferring") -or ($Job.JobState -eq "Connecting")){ sleep 5}
    Switch($Job.JobState)
    {
        "Transferred" { Complete-BitsTransfer -BitsJob $Job
                        Remove-Item -Path $JobFile -Force
                      }
        "Error" {$Job | Format-List } # List the errors.
    }
    echo "Job Status: $($Job.JobState)"
}

$Jobs = get-job -State Completed 
$Jobs | %{echo "Job: $($_.Name)"; $_ | receive-job }
$Jobs | remove-job

$FileList = Get-Content $ListPath
$ArchiveName = "$($tenant)-$(get-date -f 'yyyy-MM-dd')$($Label).7z"
$ArchiveFile = "Z:\archive\$($ArchiveName)"


# Parse Targets for Compressing.
foreach($File in $FileList){
    Write-Info $File $LogFile
    try{
        If(!($NoCompress)){
            Compress-File $File $ArchiveFile
        }
        else {
            if(!(Test-FileLock $ArchiveFile)){
                Start-Job -ScriptBlock $TransferJob -ArgumentList $File,("$(($File).Replace("z:\zeus",$DestinationPath))" ) -Name "$($Tenant)$($Label)"
            }
        }        
    }
    catch{
        $Error | %{ Write-Info $_ $LogFile}
    }
}

# Move new archive to Filer

If(!($NoCompress)){
    if(!(Test-FileLock $ArchiveFile)){
        Start-Job -ScriptBlock $TransferJob -ArgumentList $ArchiveFile,("$($DestinationPath)\$($Tenant)\$($ArchiveName)") -Name "$($Tenant)$($Label)"
    }
}


Get-Item $ListPath | Remove-Item -Force | Out-Null


Get-Job | %{Write-Info $_ "$($LogFile).job.log"}

Write-Info "Complete in $(Run-Time $StartTime -FullText)" $LogFile

# SIG # Begin signature block
# MIIIPQYJKoZIhvcNAQcCoIIILjCCCCoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWxxA4+lN5d3/57IwmD1lKBei
# Wh6gggWuMIIFqjCCBJKgAwIBAgITbgAAAKzOi+ol+RGLKQAAAAAArDANBgkqhkiG
# 9w0BAQ0FADBBMRMwEQYKCZImiZPyLGQBGRYDbmV0MRUwEwYKCZImiZPyLGQBGRYF
# aHBmb2QxEzARBgNVBAMTClBTTUNFUlRTMDEwHhcNMTgwMjA5MjIwMDM0WhcNMTkw
# MjA5MjIwMDM0WjBvMRMwEQYKCZImiZPyLGQBGRYDbmV0MRUwEwYKCZImiZPyLGQB
# GRYFaHBmb2QxDDAKBgNVBAsTA0ZPRDEOMAwGA1UECxMFVXNlcnMxDDAKBgNVBAsT
# A09wczEVMBMGA1UEAxMMTWlrZSBTdGFudG9uMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAvk9oqgeTwJGtl8uZNUgf9gyqRi/Lxtyj8zrFlJqrW/yeuJAA
# /XeBQqyPMkBd3Eq6H7Xmx286JOsCH7O7MvZGAUoE7m9gg0nXVIUvADukwK1CMQgF
# ILrowvBYe6gusnn7a+kiYm68usv+OBU3UVcg7brOMZru6OisJFwwhw1HLzNOINwb
# /aFst4MgRIpUZkVr5y/p32N9uNwPbZDeE0GGIiavnnKzlTGBpSNHSUNq+l6yAr2w
# Gl6WS87MQYWXkXMMhdGRNSQJDwkwtw6uWIF0cee3TI2wqXIHTTWS3hzhVpnGnJ3w
# spoWhk2yXGXciP5zKd5uKInRrwqmjoeihjX8/QIDAQABo4ICazCCAmcwJQYJKwYB
# BAGCNxQCBBgeFgBDAG8AZABlAFMAaQBnAG4AaQBuAGcwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwDgYDVR0PAQH/BAQDAgeAMB0GA1UdDgQWBBTGErOn7vtJpZuLu1MtnX4m
# nK3M6zAfBgNVHSMEGDAWgBSlSAghybFdXgTP1bPcLwoWwleacDCByQYDVR0fBIHB
# MIG+MIG7oIG4oIG1hoGybGRhcDovLy9DTj1QU01DRVJUUzAxLENOPVBTTUNlcnRz
# MDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2Vz
# LENOPUNvbmZpZ3VyYXRpb24sREM9aHBmb2QsREM9bmV0P2NlcnRpZmljYXRlUmV2
# b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2lu
# dDCB3QYIKwYBBQUHAQEEgdAwgc0wgacGCCsGAQUFBzAChoGabGRhcDovLy9DTj1Q
# U01DRVJUUzAxLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1T
# ZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWhwZm9kLERDPW5ldD9jQUNlcnRp
# ZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTAh
# BggrBgEFBQcwAYYVaHR0cDovL3BzbWNlcnQwMS9vY3NwMC0GA1UdEQQmMCSgIgYK
# KwYBBAGCNxQCA6AUDBJtc3RhbnRvbkBocGZvZC5uZXQwDQYJKoZIhvcNAQENBQAD
# ggEBAGj5z+lYcJzFAN7dU/Wcok/uyG0K5FxvNAERyYMjIY/rR6jndFQbnd/qu7Vw
# AymOC8wDLYhoaYDs6XYzwA4aI5XkWslJPrS49nZPvqYcY0lXDPJX8Ryv85vdkIyc
# 55+LD6iDy7Q51sMinrOljSzhkpfQ/87izHXomxF1TyzGk/qURi8w6P5u6Lbf5F0s
# ri+MSAVEJrfAJZC/QIn9rVtGoxtEr7qLQOikGkDVrNZe+5hJtzkb9/hL5035VzTE
# XRW3TXZhvoE9Cno57Z5YYX7oK82VduDroo3Jxt/Bd9VCbhHlCIPu4HuqAGVKBIDn
# PMwnCQ9rZKD0uRWGUQwXjIFs9rMxggH5MIIB9QIBATBYMEExEzARBgoJkiaJk/Is
# ZAEZFgNuZXQxFTATBgoJkiaJk/IsZAEZFgVocGZvZDETMBEGA1UEAxMKUFNNQ0VS
# VFMwMQITbgAAAKzOi+ol+RGLKQAAAAAArDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGC
# NwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUrvmV3P3O
# eaDmvvB1eMyF4rxAyl8wDQYJKoZIhvcNAQEBBQAEggEAZIUIH0munaRx0bzya2x9
# DCpxNSrvbdP/OP3gGfeazGTL0/zSM0Ly41U/in8nUWZ0DyRCR7wY2qp9pd2I8nRs
# J9P2tXOQ4d769abcvs0YRFWysOACyVpn8Yryff7GJyUU2KiqhrITIL1CwsH0mQ8R
# ICi6+zQzpY1l05l2pO2p2nVZuW7KMu4jHuMg2L3n4EBNBWKu9kYS7NHeTXWa0ksc
# Q+T4MSPb/Ac/5IKHQjYClh6UBKqnZlYo01QqQtKO1xoKp+sgGpCrD8xozzuz12ic
# XXGXifC+f4G1TdTCqI2b9fWXm35ioWniHDYaasjDtYz1UMUQUwDUCiX3owwbGKS5
# Ww==
# SIG # End signature block
