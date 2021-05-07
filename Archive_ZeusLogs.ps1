<#   
.SYNOPSIS   
Archive Zeus Log files
    
.DESCRIPTION 
This script will crawl the standard Zeus Log locations and archive the files. 
	
.PARAMETER LogPath
Add a path to the list of folders to be archived.

.PARAMETER DestinationPath
The location of the new archives

.PARAMETER ComputerName
The folder name to use at the DestinationPath location

.PARAMETER Age
Only grab logs older than this age.

.NOTES   
Name:        Archive-ZeusLogs.ps1
Author:      Michael Stanton
DateUpdated: 2018-02-06
Version:     1.0

.EXAMPLE   
.\Archive-ZeusLogs.ps1
    
Description 
-----------     
This command runs the script with default options.

.EXAMPLE
.\Archive-ZeusLogs.ps1 -LogPath C:\Logs -DestinationPath \\psmStoreOnce.hpfod.net\backup\

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
    [Alias('LP')]
        [string]  $LogPath ,
    [Alias('SP')]
        [string]  $DestinationPath = "\\psmfiles\Zeus",
    [Alias('LF')]
        [string]  $LogFile = "$env:SYSTEMDRIVE\Logs\ArchiveZeusLogs.log",
    [Alias('SN')]
        [string]  $ComputerName = $env:COMPUTERNAME,
    [Alias('AF')]
        [string]  $ArchiveFolder = "ZeusLogs",
    [Alias('A')]
        [string]  $Age = -7
)
#PREPARE STANDARD SCRIPT ENVIRONMENT
$StartTime = Get-Date
$Error.Clear()
Set-StrictMode -Version 2.0
#Load useful functions 
if(Test-Path ".\Custom-Functions.ps1"){. ".\Custom-Functions.ps1"}
elseif(Test-Path "S:\Custom-Functions.ps1"){. "S:\Custom-Functions.ps1"}
elseif(Test-Path "C:\Scripts\Custom-Functions.ps1"){. "C:\Scripts\Custom-Functions.ps1"}
elseif(Test-Path "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"){. "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"}

#VALIDATE PARAMETERS
Write-Info "Valid Logfile: $(Validate-Log $LogFile)" $LogFile
Write-Info "Valid LogPath: $(Validate-Path $LogPath -Exit $LogFile)" $LogFile
Write-Info "Valid DestinationPath: $(Validate-Path $DestinationPath -Exit $LogFile)" $LogFile
Make-Directory "$($DestinationPath)\$($ComputerName)\$($ArchiveFolder)" $LogFile | Out-Null

#Checking Compression Utilitiy
$Compress = $true
$7z = "C:\Scripts\7z.exe"    
If(!(Validate-Path $7z)){    
    $7z = "\\hpfod.net\NETLOGON\7z.exe"
    $Compress = Validate-Path $7z 
}


#INITIALIZE VARIABLES
$LogPaths = (
    "$($env:SYSTEMDRIVE)\Logs\TenantWeb\", #All IIS Service Logs
    "$($env:SYSTEMDRIVE)\Logs\WebAPI\", #All IIS Service Logs
    "$($env:SYSTEMDRIVE)\inetpub\Logs\", #All IIS Service Logs
    "$($env:SYSTEMDRIVE)\Logs\AdminWeb\", #Admin Server Logs
    "$($env:SYSTEMDRIVE)\inetpub\moodle_3_1_5\", #LMS
    "$($env:SYSTEMDRIVE)\PHP5.6\", #LMS
    "$($env:SYSTEMDRIVE)\inetpub\MoodleData\", #LMS
    "$($env:SYSTEMDRIVE)\Logs\TaskService\", #Task Servers
    "$($env:SYSTEMROOT)\System32\*.mdmp", #Any memory Crash dump
    "D:\runtime-smb\logs\", #Filer02
    #"D:\dependencies\libraries",#Filer02
    "D:\Users\", #dynafiler
    "E:\logs\", #SQL
    "E:\Backup", #SQL
    "E:\SQL_Backup", #SQL
    "E:\SQL_Logs" #SQL
)
If($LogPath -ne ""){ $LogPaths += $LogPath }
$BackupLocation = "$($DestinationPath)\$($ComputerName)\$($ArchiveFolder)"

function Compress-Files {
    param(  [Parameter(Mandatory=$true)][string]$FolderName, 
            [Parameter(Mandatory=$true)][int]$Age)
    $ReturnArray = @()
    $CurrentDate = Get-Date
    $ArchiveDate = $CurrentDate.AddDays($Age)
    $Objects = Get-ChildItem -File -Recurse $FolderName -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $ArchiveDate } | ForEach-Object{ $_.VersionInfo.FileName}
    $CompressionMethod = "ppmd"
    $PPMdRAM = "256"
    $PPMdSwitch = "-m0=PPMd:mem"+$PPMdRAM+"m"
    ForEach ($FileName in $Objects){
        try{
            if([IO.Path]::GetExtension($FileName) -ne ".7z"){
                $7zPath = "$($FileName).7z"
                Write-Info "Compressing: $($7zPath)" $LogFile               
                $Arguments = @()
                $Arguments += "a"
                $Arguments += "-t7z"
                $Arguments += "-sdel"
                $Arguments += "-stl"
                $Arguments += "-bd"
                $Arguments += $PPMdSwitch
                $Arguments += $7zPath
                $Arguments += $FileName
                $7zip = &$7z $Arguments
                $ReturnArray += $7zPath
                Write-Info ($7zip[9]) $LogFile 
            }
            else{
                $ReturnArray += $FileName
            }
        }
        catch{
            $Error | %{ Write-Info $_ $LogFile}
        }
    }
    Return $ReturnArray
}

function Backup-Directory {
    param(  [Parameter(Mandatory=$true)][string]$FolderName, 
            [Parameter(Mandatory=$true)][string]$TargetLocation)
    try{
        if(!(Test-Path (Split-path $TargetLocation))){mkdir -Path (split-path $TargetLocation) -ErrorAction Stop| Out-Null}
        $FolderName = "$($FolderName)*"
        Write-Info "Compressing: $($FolderName) Into: $($TargetLocation)" $LogFile
        if((Test-Path $TargetLocation) -and ($TargetLocation -like "*.7z")){     
            $IncFileName = "$(Split-Path $TargetLocation)\$((Split-Path -Leaf $TargetLocation).Split('.')[0]).$(get-date -Format "yyyyMMdd" ).7z"
            Write-Info "Creating Differential Backup: IncFileName: -u- $($IncFileName), Target: $($TargetLocation), Folder: $($FolderName)" $LogFile
            $Arguments = @()
            $Arguments += "u"
            $Arguments += $TargetLocation
            $Arguments += $FolderName
            $Arguments += "-r"
            $Arguments += "-t7z"
            $Arguments += "-ssw"
            $Arguments += "-mx=7"
            $Arguments += "-u-"
            $Arguments += "-up1q1r0x1y1z0w1!$($IncFileName)"
            $7zip = &$7z $Arguments
            $7zip | %{ if($_ -ne ""){Write-Info ($_) $LogFile } }

            Write-Info "Updating Original Archive: Target: $($TargetLocation), Folder: $($FolderName)" $LogFile
            $Arguments = @()
            $Arguments += "u"
            $Arguments += $TargetLocation
            $Arguments += $FolderName
            $Arguments += "-r"
            $Arguments += "-t7z"
            $Arguments += "-ssw"
            $Arguments += "-stl"
            $Arguments += "-mx=7"
            $Arguments += "-up0q0x2"
            $7zip = &$7z $Arguments
        }
        else{
            Write-Info "Creating New Archive: 7z.exe a $($TargetLocation) $($FolderName)" $LogFile
            $Arguments = @()
            $Arguments += "a"
            $Arguments += "-r"
            $Arguments += "-t7z"
            $Arguments += "-ssw"
            $Arguments += "-stl"
            $Arguments += "-mx=7"
            $Arguments += $TargetLocation
            $Arguments += $FolderName
            $7zip = &$7z $Arguments
        }
        $7zip | %{ if($_ -ne ""){Write-Info ($_) $LogFile } }
    }
    catch{
        $Error | %{ Write-Info $_ $LogFile}
    }
}

function Backup-File {
    param(  [Parameter(Mandatory=$true)][string]$FileName,
            [Parameter(Mandatory=$true)][string]$TargetLocation)
    try{
        if(!(Test-Path (Split-path $TargetLocation))){mkdir -Path (split-path $TargetLocation) -ErrorAction Stop| Out-Null}
        Write-Info "Compressing: $($FileName) Into: $($TargetLocation)" $LogFile
        if((Test-Path $TargetLocation) -and ($TargetLocation -like "*.7z")){     
            $IncFileName = "$(Split-Path $TargetLocation)\$((Split-Path -Leaf $TargetLocation).Split('.')[0]).$(get-date -Format "yyyyMMdd" ).7z"
            Write-Info "Creating Differential Backup: IncFileName: -u- $($IncFileName), Target: $($TargetLocation), Folder: $($FileName)" $LogFile
            $Arguments = @()
            $Arguments += "u"
            $Arguments += $TargetLocation
            $Arguments += $FileName
            $Arguments += "-t7z"
            $Arguments += "-ssw"
            $Arguments += "-mx=7"
            $Arguments += "-u-"
            $Arguments += "-up1q1r0x1y1z0w1!$($IncFileName)"
            $7zip = &$7z $Arguments
            $7zip | %{ if($_ -ne ""){Write-Info ($_) $LogFile } }

            Write-Info "Updating Original Archive:  Target: $($TargetLocation), Folder: $($FileName)" $LogFile
            $Arguments = @()
            $Arguments += "u"
            $Arguments += $TargetLocation
            $Arguments += $FileName
            $Arguments += "-t7z"
            $Arguments += "-ssw"
            $Arguments += "-stl"
            $Arguments += "-mx=7"
            $Arguments += "-up0q0x2"
            $7zip = &$7z $Arguments
        }
        else{
            Write-Info "Creating New Archive: 7z.exe a  $($TargetLocation) $($FileName)" $LogFile
            $Arguments = @()
            $Arguments += "a"
            $Arguments += "-t7z"
            $Arguments += "-ssw"
            $Arguments += "-stl"
            $Arguments += "-mx=7"
            $Arguments += $TargetLocation
            $Arguments += $FileName
            $7zip = &$7z $Arguments
        }
        $7zip | %{ if($_ -ne ""){Write-Info ($_) $LogFile } }
    }
    catch{
        $Error | %{ Write-Info $_ $LogFile}
    }
}

#Move Archives to Backup Location
function Move-Files {
    param(  [Parameter(Mandatory=$true)]$FileArray, 
            [Parameter(Mandatory=$true)]$TargetLocation)
    if($FileArray -ne $null){
        if(Make-Directory $TargetLocation $LogFile){ 
            $FileArray | %{ 
                Write-Info "Moving: $($_) To: $($TargetLocation)" $LogFile 
                try{
                    Get-Item $_ | Move-Item -Destination $TargetLocation -ErrorAction Stop 
                }
                catch{
                    Write-Info $Error $LogFile
                }
            }
        }
    }
}

function Remove-Files {
    param(  [Parameter(Mandatory=$true)][string]$Files, 
            [Parameter(Mandatory=$true)]$Age)    
    $CurrentDate = Get-Date
    $ArchiveDate = $CurrentDate.AddDays($Age)
    $Objects = Get-ChildItem -File $Files -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $ArchiveDate } | ForEach-Object{ $_.VersionInfo.FileName}
    Write-Info ("Removing Files") -Progress
    try{
        $Objects | %{ Write-Info "Removing: $($_)" $LogFile; Remove-Item -Path $_ -ErrorAction Stop }
    }
    catch{
        $Error | %{ Write-Info $_ $LogFile}
    }
    Write-Done -Progress
}

# Parse Targets for Archiving.
foreach($LogLocation in $LogPaths){
    Write-Info $LogLocation $LogFile
    try{
        switch($LogLocation){
        "$($env:SYSTEMDRIVE)\Logs\AdminWeb\"{
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                $Age = -1
                Move-Files (Compress-Files $LogLocation $Age) "$($BackupLocation)\AdminWeb\"
            }
            break}
        "$($env:SYSTEMDRIVE)\Logs\TenantWeb\"{
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                Move-Files (Compress-Files $LogLocation $Age) "$($BackupLocation)\TenantWeb\"
            }
            break}
        "$($env:SYSTEMDRIVE)\Logs\WebAPI\"{
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                Move-Files (Compress-Files $LogLocation $Age) "$($BackupLocation)\WebAPI\"
            }
            break}
        "$($env:SYSTEMDRIVE)\inetpub\Logs\" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                $Age = -1
                $CompressedFiles = Compress-Files $LogLocation $Age
                $CompressedFiles | %{
                    $FileArray = @()
                    $FileArray += $_
                    if((Split-Path -Path $_) -eq $LogLocation){
                        Move-Files $FileArray "$($BackupLocation)\inetpub\Logs\"
                    }
                    else{
                        $SubFolder = Split-Path -Leaf (Split-Path -Path $_)
                        Move-Files $FileArray "$($BackupLocation)\inetpub\Logs\$($SubFolder)\"
                    }

                }
            }
            break}
        "$($env:SYSTEMDRIVE)\inetpub\moodle_3_1_5\" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                Backup-Directory $LogLocation "$($BackupLocation)\Moodle_3_1_5.7z"
            }
            break}
        "$($env:SYSTEMDRIVE)\PHP5.6\"{
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                Backup-Directory $LogLocation "$($BackupLocation)\PHP5.6.7z"   
            }         
            break}
        "$($env:SYSTEMDRIVE)\inetpub\MoodleData\" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                $BackupArchive = "$($BackupLocation)\MoodleData.7z"
                Backup-Directory $LogLocation $BackupArchive 
            }
            break}
        "$($env:SYSTEMDRIVE)\Logs\TaskService\" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                Move-Files (Compress-Files $LogLocation $Age) "$($BackupLocation)\Logs\TaskService\"
            }
            break}
        "$($env:SYSTEMROOT)\System32\*.mdmp" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                Remove-Files $LogLocation
            }
            break}
        "D:\runtime-smb\logs\" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                Foreach($cFile in (Compress-Files $LogLocation $Age)){
                    $Scanner = $cFile.split('\')[3]
                    Move-Files $cFile "$($DestinationPath)\$($Scanner)\Logs\"
                }                
            }
            break}
        "D:\dependencies\libraries" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                $BackupArchive = "$($BackupLocation)\Libraries.7z"
                Backup-Directory $LogLocation $BackupArchive 
            }
            break}
        "D:\Users\" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                Get-ChildItem -File $LogLocation | %{
                    Backup-File $_.VersionInfo.FileName "$($BackupLocation)\Users\$(Split-Path -leaf $_.VersionInfo.FileName).7z"  
                } 
            }         
            break}
        "E:\logs\" {
            if(Test-Path $LogLocation){ 
                #write-Info "Found $($LogLocation)" $LogFile
                #Write-Host "Matched!"
            }
                break}
        "E:\Backup" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                #$Compressed = Compress-Files $LogLocation -1
                #Move-Files $Compressed "$($BackupLocation)\Backup\"
            }
            break}
        "E:\SQL_Backup" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                #$Compressed = Compress-Files $LogLocation -1
                #Move-Files $Compressed "$($BackupLocation)\SQL_Backup\"
            }
            break}
        "E:\SQL_Logs" {
            if(Test-Path $LogLocation){ 
                write-Info "Found $($LogLocation)" $LogFile
                #$EncryptionOption = New-SqlBackupEncryptionOption -Algorithm Aes256 -EncryptorType ServerCertificate -EncryptorName "BackupCert"
                #Backup-SqlDatabase -ServerInstance "." -Database "MainDB" -BackupFile "MainDB.bak" -CompressionOption On -EncryptionOption $EncryptionOption
            }
            break}        
        }
    }
    catch{
        $Error | %{ Write-Info $_ $LogFile}
    }
}

Write-Info "Complete in $(Run-Time $StartTime -FullText)" $LogFile

# SIG # Begin signature block
# MIIHOAYJKoZIhvcNAQcCoIIHKTCCByUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUElcan14fRn17QyzvABP4yi6a
# NoGgggUqMIIFJjCCBA6gAwIBAgITbgAAAQkdZXaL7LtYHQAAAAABCTANBgkqhkiG
# 9w0BAQ0FADBBMRMwEQYKCZImiZPyLGQBGRYDbmV0MRUwEwYKCZImiZPyLGQBGRYF
# aHBmb2QxEzARBgNVBAMTClBTTUNFUlRTMDEwHhcNMTkwMzA4MTk1MzEyWhcNMjAw
# MzA3MTk1MzEyWjBvMRMwEQYKCZImiZPyLGQBGRYDbmV0MRUwEwYKCZImiZPyLGQB
# GRYFaHBmb2QxDDAKBgNVBAsTA0ZPRDEOMAwGA1UECxMFVXNlcnMxDDAKBgNVBAsT
# A09wczEVMBMGA1UEAxMMTWlrZSBTdGFudG9uMIGfMA0GCSqGSIb3DQEBAQUAA4GN
# ADCBiQKBgQDn0IHxs0RIP95U/Wsl7FA38X1pEm4WDVZp+m/uXHs1qukiVyXEPU8Z
# NaVpkxUxM4waxveDusgtFh8lNnC8VYliLjIKUjrotMyd70bqwXrmiCQEdlxUq1Sy
# 0xg3BWK6446FPZCkySezkVZPiA0UxHQcw6y4uHBo6S5ghLiv75wkyQIDAQABo4IC
# azCCAmcwDgYDVR0PAQH/BAQDAgeAMCUGCSsGAQQBgjcUAgQYHhYAQwBvAGQAZQBT
# AGkAZwBuAGkAbgBnMB0GA1UdDgQWBBSX/riAAwYBEExF6hGgK+36zEB2QTAfBgNV
# HSMEGDAWgBSlSAghybFdXgTP1bPcLwoWwleacDCByQYDVR0fBIHBMIG+MIG7oIG4
# oIG1hoGybGRhcDovLy9DTj1QU01DRVJUUzAxLENOPVBTTUNlcnRzMDEsQ049Q0RQ
# LENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZp
# Z3VyYXRpb24sREM9aHBmb2QsREM9bmV0P2NlcnRpZmljYXRlUmV2b2NhdGlvbkxp
# c3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludDCB3QYIKwYB
# BQUHAQEEgdAwgc0wgacGCCsGAQUFBzAChoGabGRhcDovLy9DTj1QU01DRVJUUzAx
# LENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxD
# Tj1Db25maWd1cmF0aW9uLERDPWhwZm9kLERDPW5ldD9jQUNlcnRpZmljYXRlP2Jh
# c2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTAhBggrBgEFBQcw
# AYYVaHR0cDovL3BzbWNlcnQwMS9vY3NwMBMGA1UdJQQMMAoGCCsGAQUFBwMDMC0G
# A1UdEQQmMCSgIgYKKwYBBAGCNxQCA6AUDBJtc3RhbnRvbkBocGZvZC5uZXQwDQYJ
# KoZIhvcNAQENBQADggEBAFeooEEaHWEIBQgJ9y6gyzYL74E2lx3bkyQWE2c++Dgy
# rnrPJ5FXgS+iu7UXrvTGBjHrgsfDCz/s/bRu5BY1a3OBoCA+ft6qHaoA7fQlRhtV
# vSgXpkx6DUkiEkOLUkClQAkRGMucVGVeOiOkiwoCJFN8bUY7RtBiiZMiAV0RFils
# CgF9RqsOlkDTueLfTUWc3CS+FY8aTsGEDWyefW3HGuMAVlJaYnYb02dOKiRl+715
# lESmw00xrlIjckmzW+HIxp8hRjiymMlL1x1g25uy+aFCJo/3G6ArOk8ff/BO8qsP
# eIe0UeFmuzxKDIRVMrs4eVbOPV+8y8H8oHIpr4BSueoxggF4MIIBdAIBATBYMEEx
# EzARBgoJkiaJk/IsZAEZFgNuZXQxFTATBgoJkiaJk/IsZAEZFgVocGZvZDETMBEG
# A1UEAxMKUFNNQ0VSVFMwMQITbgAAAQkdZXaL7LtYHQAAAAABCTAJBgUrDgMCGgUA
# oHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0B
# CQQxFgQUOq58bGONUrzhwWr55LGE1qYWJNMwDQYJKoZIhvcNAQEBBQAEgYB5Ev93
# LvjWdm1S+byZ3jP3BaMuK1EZoe/gDRhxmYQtFMloKfLqF4hZgG4KAt6ncB68722w
# k0nqUAvEfjBArJiIrF1FIXl/RR4BLRRLHtOkwruP22WSP6RKHfSqSblRJfX6dpbt
# eXuHkndk43OSRx9gOk+yMOtnyhu4i+ryDdlTWA==
# SIG # End signature block
