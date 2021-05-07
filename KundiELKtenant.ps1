#Configure ELK logs
$elkserver = $ELKServer
$Region = $ELKRegion
$service = "tenant"
$environment = $ELKEnvironment
$LogFolder = $ELKTenantLogs
$InstallFolder = $ELKInstallPath
$hasSvc = $false
$dupSvc = $false

Write-Output "Server: $ElkServer"
Write-Output "Product: $ELKProduct"
Write-Output "service: $service"
Write-Output "LogFolder: $LogFolder"
Write-Output "environment: $environment"
Write-Output "InstallFolder: $InstallFolder"

# Algorithm
# Check if beatYML file has been updated before
# #hasSvc:
Function ChkYML_hasSvc {
    param($File)
    Get-Content $File | %{
        if($_ -match "#hasSvc:") {
            $hasSvc = $true
        }
    }
    return $hasSvc
    
}

Function ChkYML_dupSvc {
    param($File)
    Get-Content $File | %{
        if($_ -match "#hasSvc:") {
            $dupSvc = $_.split(' ') -contains $Service
        }
    }
    return $dupSvc
    
}


Function UpdateYML_Ins {
    param($File, $ELK, $Region, $Service, $Env, $Logs)
    Write-Host "Updating YML file $File"
    $NewYML = @()
    $Skip = $false
    $SetupILM = $false
    $Inputs = $false
    $Paths = $false
    $Fields = $false
    $SetupTemplate = $false
    $ElasticSearch = $false
    $LogStash = $false
    $CertFolder = "C:/ELK/certs"
    
    Get-Content $File | %{
        $Skip = $false
        if($_.contains('#hasSvc:')) {
            $Skip = $true ; $NewYML += "$_ $service"
        }
        if($_ -match '- type: log') {
            $NewYML += "#Insert starts"
            $NewYML += $_
            $NewYML += "  enabled: true"
            $NewYML += "  paths:"
            $NewYML += "    - $Logs\*.txt"
            $NewYML += "  fields:";$NewYML += "    env: $Env";$NewYML += "    region: $Region";$NewYML += "    service: $Service";
            $NewYML += "#Insert ends"
        }
        if(-Not $Skip){
            $NewYML += $_ 
        }
	}
    return $NewYML   
}

Function UpdateYML {
    param($File, $ELK, $Region, $Service, $Env, $Logs)
    Write-Host "Updating YML file $File"
    $NewYML = @()
    $Skip = $false
    $SetupILM = $false
    $Inputs = $false
    $Paths = $false
    $Fields = $false
    $SetupTemplate = $false
    $ElasticSearch = $false
    $LogStash = $false
    $CertFolder = "C:/ELK/certs"
    
    Get-Content $File | %{
        $Skip = $false
        if($_ -match 'setup.ilm'){$SetupILM = $true}
        if($_ -match 'inputs:' -and $SetupILM -eq $false){$NewYML += "setup.ilm.enabled: false";$inputs=$true}
        if($_ -match 'enabled:' -and $inputs ){$NewYML += "  enabled: true";$Skip = $true;$inputs = $false}
        if($_ -match 'metricbeat.config.modules:' -and $SetupILM -eq $false){$NewYML += "setup.ilm.enabled: false";$SetupILM= $true}
        if($_ -match 'paths:'){$Paths = $true}
        if($_ -match '    - ' -and $Paths){$Paths = $false;$Skip = $true;$NewYML += "    - $Logs\*.txt"; $NewYML += "  fields:";$NewYML += "    env: $Env";$NewYML += "    region: $Region";$NewYML += "    service: $Service";  }
        if($_ -match 'setup.template'){$SetupTemplate = $true}
        if($_ -match 'fields:' -and $SetupTemplate){$Skip = $true;$Fields = $true;$NewYML += "#fields:"}
        if($_ -match '  ' -and $Fields){$Skip = $true}
        if($_ -match '#' -and $Fields){$Skip = $false;$Fields = $false}
        if($_ -match 'setup.kibana:'){$NewYML += "#setup.kibana:";$Skip = $true}
        if($_ -match 'output.elasticsearch:'){$ElasticSearch = $true; $NewYML += "#output.elasticsearch:";$Skip = $true}
        if($_ -match 'hosts:' -and $ElasticSearch){$ElasticSearch = $false;$NewYML += "#" + $_ ;$Skip = $true}
        if($_ -match 'output.logstash'){$LogStash = $true; $NewYML += "output.logstash:";$Skip = $true}
        if($_ -match 'hosts' -and $LogStash){$LogStash = $false;$NewYML += '  hosts: ["' + "$($ELK):443" + '"' + "]";$Skip = $true}
        if($_ -match 'ssl.certificate_authorities'){$NewYML += '  ssl.certificate_authorities: ["' + "$($CertFolder)/fortifyopsca.pem" + '"' + "]";$Skip = $true}
        if($_ -match 'ssl.certificate:'){$NewYML += '  ssl.certificate: "' + "$($CertFolder)/filebeat.pem" + '"' ;$Skip = $true}
        if($_ -match 'ssl.key'){$NewYML += '  ssl.key: "' + "$($CertFolder)/filebeat.key" + '"' ;$Skip = $true}
        if(-Not $Skip){
            $NewYML += $_ 
        }
	}
    return $NewYML   
}

ForEach ($BeatFolder in (gci $InstallFolder -directory | ?{$_ -match 'beat'})){
    Write-Output "Current Folder: $($BeatFolder.FullName)"
    $filename = $BeatFolder.Name.split('-')[0]
    Write-Output "Filename: $filename"
    #if($filename -notin $Packages){echo "$filename is not Included in deployment, update ELKBeatPackages to include";continue}
    $file = Join-Path $BeatFolder.FullName "$($filename).yml"
    Write-Output "File: $file"
    $NewYML = @()
    $Skip = $false
    $LogStashM =  $false
    
    switch($filename){
        'filebeat' {
            $hasSvc = ChkYML_hasSvc $file
            $dupSvc = ChkYML_dupSvc $file
            Write-Output "hasSvc: $hasSvc, dupSvc: $dupSvc"
            if ( -not $hasSvc -and -not $dupSvc) {
                Write-Output "## no prev, no dup block"
                $NewYML += "#hasSvc: $service"
                $FileYML = UpdateYML $file $elkserver $Region $service $environment $LogFolder
                
            } elseif ( $hasSvc -and -not $dupSvc ) {
                Write-Output "## yes prev, no dup block"
                $FileYML = UpdateYML_Ins $file $elkserver $Region $service $environment $LogFolder
            } else {
                Write-Output "## no change block"
                $FileYML = get-content $File                
            }
            $FileYML | %{ 
                $NewYML += $_ 
            }
            break
            
        }
        'metricbeat' {
            $hasSvc = ChkYML_hasSvc $file
            if ( -not $hasSvc ) {
                Write-Output "## no prev"
                $NewYML += "#hasSvc: metricbeat"
                $FileYML = UpdateYML $file $elkserver $Region $service $environment $LogFolder
                $FileYML | %{ 
                    $Skip = $false
                    if($_ -match 'output.logstash'){$LogStashM = $true; $NewYML += "output.logstash:";$Skip = $true}
                    if($_ -match '  hosts:' -and $LogStashM ){$LogStashM = $false;$NewYML += '  hosts: ["' + "$($elkserver):8443" + '"' + "]";$Skip = $true; Write-Output "FOUND HOSTS"}
                    if(-Not $Skip){
                        $NewYML += $_ 
                    }
                }
                
            } else {
                Write-Output "## yes prev"            }
            break
        }
        'winlogbeat' {
            $FileYML | %{ 
                $NewYML += $_ 
            }
            break
        }
        default {
            $FileYML | %{ 
                $NewYML += $_ 
            }
        }
    }
    
    Write-Output "NewYML = $($NewYML.count) lines"
    $NewYML | set-content $file
    
}





