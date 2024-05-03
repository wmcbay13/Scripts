<# Scripted installations by Chocolatey:
    Google Chrome
    WizTree 
    7zip
    NotepadPlusPlus
    Visual Studio Code
    Jave Runtime 8
    .NET Framework 4.8
    AWS Command Line Interface 2.0.40
    Octopus Deploy Tentacle
    Nagios Client
#>

choco install googlechrome -y
choco install 7zip.install -y
choco install wiztree -y
choco install notepadplusplus.install -y
choco install vscode -y
choco install jre8 -y
choco install awscli -y 
choco install octopusdeploy.tentacle --version=3.12.4 -y 
choco install nscp --version=0.5.0.62 -y 
choco install netfx-4.8-devpack -y

Restart-Computer -Force