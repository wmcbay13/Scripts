Function OptimizeTCP {
    param($Adapter, $Settings, $Value, $Name )
    if(($Settings | ?{$_.DisplayName -eq $Name}).DisplayValue -ne $Value) {
        Write-Output "Optimizing $Name"
        try {
            Set-NetAdapterAdvancedProperty $Adapter -DisplayName $Name -DisplayValue $Value -NoRestart
        } catch {
            Write-Warning "Error configuring $Name" -ErrorAction SilentlyContinue
        }
    }
}

$NetAdapter = Get-NetAdapter -Physical
$IPStack = Get-NetIpAddress | ?{$_.InterfaceIndex -eq $NetAdapter.ifIndex}
$DNS = $DNSServers.Split(",").Trim()
$IfDNS = Get-DnsClientServerAddress | ?{$_.InterfaceIndex -eq $NetAdapter.ifIndex -and $_.AddressFamily -eq "2"}
$Update = $false
if($DNS.count -ne $IfDNS.ServerAddresses.count){
    $Update = $true
} else {
    foreach ($Server in $DNS){
        if($IfDNS.ServerAddresses -notcontains $Server ){
            $Update = $true
        }
    }
}
if($Update){
    Set-DNSClientServerAddress -InterfaceIndex $NetAdapter.ifIndex -ServerAddresses $DNSServers
}

Write-Output "Optimizing TCP configuration"

$TCPSettings = Get-NetAdapterAdvancedProperty $NetAdapter.Name

OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "Offload IP Options" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "Offload tagged traffic" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "Offload TCP Options" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "Recv Segment Coalescing (IPv4)" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "Recv Segment Coalescing (IPv6)" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "TCP Checksum Offload (IPv4)" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "TCP Checksum Offload (IPv6)" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "UDP Checksum Offload (IPv4)" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "UDP Checksum Offload (IPv6)" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Jumbo 9000" "Jumbo Packet" 
OptimizeTCP $NetAdapter.Name $TCPSettings "8192" "Large Rx Buffers" 

#Trade CPU for Network
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "IPv4 TSO Offload" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "Large Send Offload V2 (IPv4)" 
OptimizeTCP $NetAdapter.Name $TCPSettings "Disabled" "Large Send Offload V2 (IPv6)" 
OptimizeTCP $NetAdapter.Name $TCPSettings "4096" "Rx Ring #1 Size" 
OptimizeTCP $NetAdapter.Name $TCPSettings "4096" "Rx Ring #2 Size" 
OptimizeTCP $NetAdapter.Name $TCPSettings "8192" "Small Rx Buffers" 




$NetSh = (netsh int tcp show global)
$Chimney =      ( $NetSh | ?{$_ -match "Chimney"}).split(":")[1].trim()
$RSS =          ( $NetSh  | ?{$_ -match "Receive-Side"}).split(":")[1].trim()
$AutoTuning =   ( $NetSh  | ?{$_ -match "Auto-Tuning"}).split(":")[1].trim()
$DCA =          ( $NetSh  | ?{$_ -match "DCA"}).split(":")[1].trim()
$Congestion =   ( $NetSh  | ?{$_ -match "Congestion"}).split(":")[1].trim()
$ECN =          ( $NetSh  | ?{$_ -match "ECN"}).split(":")[1].trim()
$Timestamps =   ( $NetSh  | ?{$_ -match "Timestamps"}).split(":")[1].trim()
$RTO =          ( $NetSh  | ?{$_ -match "RTO"}).split(":")[1].trim()
$Coalescing =   ( $NetSh  | ?{$_ -match "Coalescing"}).split(":")[1].trim()
$Rtt =          ( $NetSh  | ?{$_ -match "Rtt"}).split(":")[1].trim()
$SYN =          ( $NetSh  | ?{$_ -match "SYN"}).split(":")[1].trim()

if($Chimney -ne "disabled") {
    Write-Output "Optimizing Chimney Offload State"
    netsh int tcp set global chimney=disabled
}
if($RSS -ne "enabled") {
    Write-Output "Optimizing Receive-Side Scaling State"
    netsh int tcp set global rss=enabled
}
if($AutoTuning -ne "normal") {
    Write-Output "Optimizing Receive Window Auto-Tuning Level"
    netsh int tcp set global autotuninglevel=normal
}
if($DCA -ne "disabled") {
    Write-Output "Optimizing Direct Cache Access (DCA)"
    netsh int tcp set global dca=disabled
}
if($Congestion -ne "none") {
    Write-Output "Optimizing Direct Cache Access (DCA)"
    netsh int tcp set supplemental custom congestionprovider=none
}
if($ECN -ne "enabled") {
    Write-Output "Optimizing ECN Capability"
    netsh int tcp set global ecncapability=enabled
}
if($Timestamps -ne "disabled") {
    Write-Output "Optimizing RFC 1323 Timestamps"
    netsh int tcp set global timestamps=disabled
}
if($RTO -ne "3000") {
    Write-Output "Optimizing Initial RTO"
    netsh int tcp set global initialrto=3000
}
if($Coalescing -ne "enabled") {
    Write-Output "Optimizing Receive Segment Coalescing State"
    netsh int tcp set global rsc=enabled
}
if($Rtt -ne "disabled") {
    Write-Output "Non Sack Rtt Resiliency"
    netsh int tcp set global nonsackrttresiliency=disabled
}
if($SYN -ne "2") {
    Write-Output "Optimizing Max SYN Retransmissions"
    netsh int tcp set global maxsynretransmissions=2
}

#Validate network protocols are enabled
get-netadapterbinding $NetAdapter.Name | ?{$_.ComponentID -ne "ms_implat"} | %{
    if(-Not $_.Enabled){
        Write-Output "Enabling Protocol $($_.DisplayName)"
        try{
            Enable-NetAdapterBinding -componentID $_.Componentid
        } catch {
            Write-Output "Failed to enable protocol"
        }
    }
}

