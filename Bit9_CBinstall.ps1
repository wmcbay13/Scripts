#$B9Port = "41002"
#$B9ServerID = "{b9}"
$B9Server = "bit9.fortifyops.net"
#$B9HostGroup = "11"
#$B9NoConfig = "0" # value of 1 for no config
#$B9ConfigList = "https://$($B9Server)/hostpkg/pkg.php?pkg=configlist.xml"
$Timestamp = Get-Date -format "hh:mm:ss"


Start-Transcript 
Write-Host "Starting installation process at $Timestamp"

# Create folder for Bit9 installer.
Write-Host "Creating c:\Windows\temp\Bit9 directory."
New-Item c:\windows\temp\Bit9 -type directory

# Download Bit9 Installer
Write-Host "Downloading installer from Bit9 Server"
Invoke-WebRequest -URI "http://$B9Server/hostpkg/pkg.php?pkg=Low%20Enforcement.msi" -outfile "c:\Windows\temp\Bit9\Low_Enforcement.msi"
        
# Sleep for two minutes
Write-Host "Sleeping for 2 minutes to account for slow download speeds."
sleep -s 120

# Execute Bit9 Installer
Write-Host "Installing Bit9"
msiexec /i c:\Windows\temp\Bit9\Low_Enforcement.msi /quiet
       

#Wait for install to complete then verify Bit9 process is running
sleep -s 90
# Query for Parity process
Write-Host "Testing for running Bit9 process"
        
        If(get-process -name Parity){
        
            # Return successful status
            Write-Host "Installation Successful"

            # Removing install directory
            Write-Host "Removing installation directory"
            Remove-Item c:\Windows\temp\Bit9 -recurse
        
        }
        
        else{
            # Return unknown status
            Write-Host "Unable to determine successful installation"
        }


Write-Host "Disabling Windows Defender"
Set-MpPreference -DisableRealtimeMonitoring $true


Stop-Transcript
