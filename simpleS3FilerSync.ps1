#Get start time
get-date -Format "yyyyMMdd"

#Sync Zeus Filer data to S3 bucket listed
aws s3 sync Z:\zeus s3://emea-data-import/Zeus
#Get final end time
get-date -Format "yyyyMMdd"
