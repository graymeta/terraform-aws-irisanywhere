<powershell>
Write-Host "Download IA-ASG"
Read-S3Object -BucketName sattler-test -Key ia-mock-windows -File "C:\ia-mock-windows.exe"
Read-S3Object -BucketName sattler-test -Key ia-asg-windows -File "C:\ia-asg-windows.exe"


</powershell>