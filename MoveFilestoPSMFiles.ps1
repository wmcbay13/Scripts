#Move Files $type older than $age to psmfiles

$t=Get-Date
gci Z:\zeus -directory | ?{!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)} | %{ $f=$_
gci ($f.FullName)* -file -recurse -include $type  | ?{$_.LastAccessTime -lt $age}}  | %{ $f=$_.VersionInfo.FileName
$d="\\psmfiles.hpfod.net\FilerCluster\$($f.Replace('Z:\zeus\',''))"
echo "Moving: $f :: $d"
mkdir -force (Split-Path -Path $d)
Move-item -Path $f -Destination $d  }
$rt=(Get-Date)-$t
echo "Completed in: $([Math]::Round($rt.TotalSeconds)) seconds"

#PSZFiler01 version
$t=Get-Date
gci Z:\zeus -directory | %{ $f=$_;gci ($f.FullName)* -file -recurse -include $type  | ?{$_.LastAccessTime -lt $age}}  | %{ $f=$_.VersionInfo.FileName
$d="\\psmfiles.hpfod.net\FilerCluster\$($f.Replace('Z:\zeus\',''))"
echo "Moving: $f :: $d"
mkdir -force (Split-Path -Path $d);$j=Start-BitsTransfer -Source $f -Destination $d -Asynchronous
 while( ($j.JobState.ToString() -eq ‘Transferring’) -or ($j.JobState.ToString() -eq ‘Connecting’) ){echo $j.JobState.ToString(); $P = ($j.BytesTransferred / $j.BytesTotal)*100;echo $P "%"; sleep 3}
Complete-BitsTransfer -BitsJob $j; Remove-item $f };$rt=(Get-Date)-$t
echo "Completed in: $([Math]::Round($rt.TotalSeconds)) seconds"

#Move Files $type older than $12m newer than 24m to psmfiles
$t=Get-Date
gci Z:\zeus -directory | ?{!($_.Attributes -band [IO.FileAttributes]::ReparsePoint)} | %{ $f=$_;gci ($f.FullName)* -file -recurse -include $type  | ?{$_.LastAccessTime -ge $24m -and $_.LastAccessTime -lt $12m}}  | %{ $f=$_.VersionInfo.FileName
$d="\\psmfiles.hpfod.net\FilerCluster\$($f.Replace('Z:\zeus\',''))"
echo "Moving: $f :: $d"
mkdir -force (Split-Path -Path $d);Move-item -Path $f -Destination $d  }
$rt=(Get-Date)-$t
echo "Completed in: $([Math]::Round($rt.TotalSeconds)) seconds"
