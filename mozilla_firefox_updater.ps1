mkdir "C:\TempMozilla" -Force
Copy-Item -Path $FirefoxInstall -Destination "C:\TempMozilla"
sleep 30

cd "C:\TempMozilla"
msiexec.exe -i '.\Firefox Setup 123.0.msi' /q

Sleep 180
Remove-Item "C:\TempMozilla" -recurse