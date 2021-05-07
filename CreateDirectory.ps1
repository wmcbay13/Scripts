# Create new directory if one does not already exist.

$path = "C:\AppLogs"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}