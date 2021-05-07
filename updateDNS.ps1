$computer = Get-Content "C:\Users\bwilson\computernames.txt"
$NICs = Get-WMIObject Win32_NetworkAdapterConfiguration -computername $computer |Where-Object{$_.IPEnabled -eq “TRUE”}
  Foreach($NIC in $NICs) {
$DNSServers = “10.140.4.74",”10.140.4.75"
 $NIC.SetDNSServerSearchOrder($DNSServers)
 $NIC.SetDynamicDNSRegistration(“TRUE”)
}