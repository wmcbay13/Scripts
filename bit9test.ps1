# This script will receive a list of computer names from a text file and silently installs Bit9

Function LogWrite
{
   Param ([string]$logstring)

   $Timestamp = Get-Date -format "hh:mm:ss"

   Write-Host "$Timestamp - $computer - $logstring"

   Add-content $Logfile "$Timestamp - $computer - $logstring"

}

Function CSVWrite
{
    Param ([string]$logstring)
    Add-content $CSVfile "$computer,$logstring"

}

Function Deploy_Bit9
{
    
            # Create folder for Bit9 installer.
            LogWrite "Creating c:\Windows\temp\Bit9 directory."
            Invoke-Command -ScriptBlock {New-Item c:\windows\temp\Bit9 -type directory}

            # Download Bit9 Installer
            LogWrite "Downloading Bit9 installer from bit9.upmc.edu"
            Invoke-Command -ScriptBlock {Invoke-WebRequest -URI "https://bit9.fortifyops.net/hostpkg/pkg.php?pkg=Agent%20Disabled.msi" -outfile "c:\Windows\temp\Bit9\Agent_Disabled.msi"} 
        
            # Sleep for one minute
            #LogWrite "Sleeping for 2 minutes to account for slow download speeds."
            #sleep -s 120

            # Execute Bit9 Installer
            LogWrite "Installing Bit9"
            Invoke-Command -ScriptBlock {& msiexec /i c:\Windows\temp\Bit9\Agent_Disabled.msi /quiet}   
       


}

Function Verify_Bit9
{
    
    
        # Query for Parity process
        LogWrite "Testing for running Bit9 process"
        
        If(Invoke-Command -ScriptBlock {get-process -name Parity})
        {
        
            # Return successful status
            LogWrite "Installation Successful"
            CSVWrite "Installation Successful"

            # Removing install directory
            LogWrite "Removing installation directory"
            Invoke-Command -ScriptBlock {Remove-Item c:\Windows\temp\Bit9 -recurse}

        }
        else{
            # Return unknown status
            LogWrite "Unable to determine successful installation"
            CSVWrite "Unknown"
        }

}



