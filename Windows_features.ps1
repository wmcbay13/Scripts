Import-Module ServerManager

Install-WindowsFeature RSAT-AD-Tools
Install-WindowsFeature UpdateServices-API
Install-WindowsFeature Windows-Server-Backup

Uninstall-WindowsFeature FS-SMB1