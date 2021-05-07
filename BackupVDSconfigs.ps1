######################################
#
# PowerCLI script to backup vDS config
#
######################################
 
# Build array for each vCenter with vDS switch
$array = "vc1", "vc2", "vc3", "vc4"
for($count=0;$count -lt $array.length; $count++)
 
{
# Connect to vCenter
connect-viserver $array[$count]
 
# Get the name of each vSwitch
$vds = get-vdswitch
 
# Backup the entire vDS switch
get-vdswitch | export-vdswitch -Description "vCenter 5.5 vDS Switch" -Destination ("c:\VMware\vDS\"+ $array[$count]&amp;nbsp;+ "_" + $vds + ".zip") -Force
 
# Backup each individual Portgroup
Get-vdswitch | Get-vdportgroup | foreach {
Export-vdportgroup -vdportgroup $_ -Description "Backup of $($_.Name) PG" -Destination ("c:\VMware\vDS\" + $array[$count] + "\$($_.Name).zip") -Force
}
# Disconnect from vCenter
disconnect-viserver $array[$count] -confirm:$false
}
# Rinse and Repeat