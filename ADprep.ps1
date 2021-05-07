$MachineId = $OctopusParameters["Octopus.Machine.Id"]
$MachineName = $OctopusParameters["Octopus.Machine.Name"]
$SecurePassword = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
$ADCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($DomainAdminUser, $SecurePassword)

Write-Output "Validate Domain Credentials"
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
Write-Output "Setting Context"
$ContextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
$UserDomain = $ADCreds.GetNetworkCredential().Domain
if($UserDomain -eq ""){ $UserDomain = "hpfod.net"}

Write-Output "User Domain: <$UserDomain>"
    $PrincipalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext $ContextType,$UserDomain
Write-Output "Testing if account is Valid"
    $ValidAccount = $PrincipalContext.ValidateCredentials($ADCreds.username,$ADCreds.GetNetworkCredential().password)
if(-Not($ValidAccount)){
    Write-Error "Domain Credentials Failed Validation"
}
( Get-ADUser $ADCreds.username -Properties memberof ).memberof | %{
    if( $_ -like 'CN=Domain Admins*'){
        Write-Output "$($ADCreds.username) is a Domain Admin"
    } else {
        Write-Warning "$($ADCreds.username) is not a Domain Admin"
    }
}

$MakeGroup = $False
try {
    Write-Output "Searching for AD Group named after this machine"
    $ADGroup = Get-ADGroup $MachineName -Credential $ADCreds
    Write-Output "Group Found!"
} catch {
    $MakeGroup = $True
}
if($MakeGroup){
    Write-Output "No Group Found.  Creating Group."
    try {
        New-ADGroup -Name $MachineName -GroupScope "DomainLocal" -Path "OU=Local Admins,OU=Groups,OU=FOD,DC=hpfod,DC=net" -GroupCategory Security -Credential $ADCreds
        Write-Output "New-ADGroup completed successfully"
        $ADGroup = Get-ADGroup $MachineName -Credential $ADCreds
        Write-Output "Adding Global Local Admins to new group"
        Add-ADGroupMember -Identity $ADGroup -Members "Global Local Admin Access" -Credential $ADCreds
        Write-Output "Adding Service Account to new group"
        Add-ADGroupMember -Identity $ADGroup -Members $DomainServiceAccount -Credential $ADCreds
    } catch {
        Write-Warning "Error Updating Computer Domain Admin Group" -ErrorAction SilenetlyContinue
    }
} else {
    Write-Output "Verifying default Admin users"
    $AddGlobal = $true
    Get-ADGroupMember $ADGroup | %{ 
        if($_.SamAccountName -eq "Global Local Admin Access") { $AddGlobal = $false; Write-Output "Global Local Admins found" }
    }
    if ($AddGlobal){  Write-Output "Adding Global Local Admins "; Add-ADGroupMember -Identity $ADGroup -Members "Global Local Admin Access" -Credential $ADCreds }
}



