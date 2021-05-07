<# Scripted installations by Chocolatey:
    Google Chrome
    WizTree 
    7zip
    NotepadPlusPlus
    Jave Runtime 8
    .NET Framework 4.8
    AWS Command Line Interface 2.0.40
    Octopus Deploy Tentacle
    Nagios Client

    Package Repository last updated 11/10/2020 by ~Will McBay~
#>

choco install googlechrome -y
choco install 7zip.install -y
choco install wiztree -y
choco install notepadplusplus.install -y
choco install jre8 -y
choco install netfx-4.8-devpack -y
choco install awscli -y 
choco install octopusdeploy.tentacle --version=3.12.4 -y 
choco install nscp --version=0.5.0.62 -y 

Restart-Computer -Force