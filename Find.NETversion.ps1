Get-ItemProperty -Path 'hklm:Software\Microsoft\NET Framework Setup\NDP\v4\Full' | Select-Object -ExpandProperty 'Version'