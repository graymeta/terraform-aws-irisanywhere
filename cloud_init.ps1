<powershell>
# Temporary until I get IA-ASG working directly with Windows Service Manager
# Need to move this to the AMI creation and package it up
# Remove ia-mock once we get the IA sessions responding to us
Write-Host "Installing NSSM"
choco install nssm -y
Write-Host "Download IA-ASG"
New-Item "C:\Program Files\Graymeta\asg\bin" -ItemType Directory
New-Item "C:\Program Files\Graymeta\asg\logs" -ItemType Directory
Read-S3Object -BucketName sattler-test -Key ia-mock-windows -File "C:\Program Files\Graymeta\asg\bin\ia-mock.exe"
nssm install ia-mock "C:\Program Files\Graymeta\asg\bin\ia-mock.exe"
nssm set ia-mock AppStdout "C:\Program Files\Graymeta\asg\logs\ia-mock.log"
nssm set ia-mock AppStderr "C:\Program Files\Graymeta\asg\logs\ia-mock.log"
nssm set ia-mock AppStdoutCreationDisposition 4
nssm set ia-mock AppStderrCreationDisposition 4
nssm set ia-mock AppRotateFiles 1
nssm set ia-mock AppRotateOnline 0
nssm set ia-mock AppRotateSeconds 86400
nssm set ia-mock AppRotateBytes 1048576
nssm set ia-mock DisplayName ia-mock
nssm set ia-mock Description "IA-Mock application for sessions endpoint"
nssm set ia-mock Start SERVICE_AUTO_START
nssm start ia-mock
Read-S3Object -BucketName sattler-test -Key ia-asg-windows -File "C:\Program Files\Graymeta\asg\bin\ia-asg.exe"
nssm install ia-asg "C:\Program Files\Graymeta\asg\bin\ia-asg.exe"
nssm set ia-asg AppStdout "C:\Program Files\Graymeta\asg\logs\ia-asg.log"
nssm set ia-asg AppStderr "C:\Program Files\Graymeta\asg\logs\ia-asg.log"
nssm set ia-asg AppStdoutCreationDisposition 4
nssm set ia-asg AppStderrCreationDisposition 4
nssm set ia-asg AppRotateFiles 1
nssm set ia-asg AppRotateOnline 0
nssm set ia-asg AppRotateSeconds 86400
nssm set ia-asg AppRotateBytes 1048576
nssm set ia-asg DisplayName ia-asg
nssm set ia-asg Description "IA-ASG application to upload and control Autoscaling"
nssm set ia-asg AppEnvironmentExtra iris_addr=http://127.0.0.1 gm_metric_check_interval=${metric_check_interval}s gm_health_check_interval=${health_check_interval}s gm_health_check_threshold=${unhealthy_threshold} gm_cool_down=${cooldown}s
nssm set ia-asg Start SERVICE_AUTO_START
nssm start ia-asg
New-NetFirewallRule -DisplayName "Allow inbound TCP port 9000 IA-ASG" -Direction inbound -LocalPort 9000 -Protocol TCP -Action Allow

</powershell>