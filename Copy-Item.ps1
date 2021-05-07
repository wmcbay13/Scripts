<# 
Copy Item templates to use if needed...

$remoteFilePath = '\\WEBSRV1\c$\File.txt'
Copy-Item -Path C:\File.txt -Destination $remoteFilePath
Write-Host "I've just copied the file to $remoteFilePath"

$copiedFile = Copy-Item -Path C:\File.txt -Destination '\\WEBSRV1\c


$session = New-PSSession -ComputerName WEBSRV1
Copy-Item -Path C:\File.txt -ToSession $session -Destination 'C:\'
#>

Get-ChildItem -Path C:\PointA\ | Copy-Item -Destination C:\PointB -Recurse