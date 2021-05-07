#Testing trust relationships in bulk
$localAdminCredential = Get-Credential
$domainCredential = Get-Credential
 
@(Get-AdComputer -Filter *).foreach({
 
   $output = @{ ComputerName = $_.Name }
 
   if (-not (Test-Connection -ComputerName $_.Name -Quiet -Count 1)) { $output.Status = 'Offline'
   } else {
       $repairOutput = Invoke-Command -Computername $_.Name -Credential $localAdminCredential -ScriptBlock { Test-ComputerSecureChannel -Repair -Credential $using:domainCredential }
       $output.RepairOutput = $repairOutput
   }
 
   [pscustomobject]$output
 
})