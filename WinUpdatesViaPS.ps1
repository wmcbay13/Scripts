##PSWindowsUpdate Module install from PSGallery repo
Install-PackageProvider NuGet -Force;
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module PSWindowsUpdate -Repository PSGallery

##Search for available updates
Get-WindowsUpdate #-Severity Critical Important

##Default command to Install available updates
#Install-WindowsUpdate

##Install available updates, accept all dialogs, and do not reboot machine upon completion.
##Optional switches to select specific KBs, update types, or categories.
##Option to use scheduled reboot to coordinate group restarts.
Install-WindowsUpdate -AcceptAll –IgnoreReboot  #KBArticleID #UpdateType Software, Driver ##-ScheduledReboot

##Shows list of installed Windows updates
#Get-WUHistory