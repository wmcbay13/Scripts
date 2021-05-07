$SetPowerProfile = $SystemPowerProfile
$ActivePowerProfile = POWERCFG /GetActiveScheme
Write-OuTput "Currently active power profile: $ActivePowerProfile"

if($ActivePowerProfile -notmatch $SystemPowerProfile){
    Write-Output "Applying Power Scheme $SetPowerProfile"
    POWERCFG -SetActive $SetPowerProfile
    POWERCFG /SETACVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
    POWERCFG /SETDCVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
    POWERCFG -h off
}
Write-Output "Finished."