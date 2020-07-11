Start-Transcript C:\Fileroutput

Write-Host "Starting S3 Sync..."

get-date -Format "dddd MM/dd/yyyy HH:mm"

#Sync Zeus Filer data to S3 bucket listed
aws s3 sync C:\ZeusShared s3://apac-filerbackup
#Get final end time
get-date -Format "dddd MM/dd/yyyy HH:mm"

Write-Host "Sync is complete."

Stop-Transcript
