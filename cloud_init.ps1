<powershell>
# Write-Host "Download IA-ASG"
# Read-S3Object -BucketName sattler-test -Key ia-mock-windows -File "C:\ia-mock-windows.exe"
# Read-S3Object -BucketName sattler-test -Key ia-asg-windows -File "C:\ia-asg-windows.exe"


$liccontent = "${tfliccontent}"
$certfile = "${tfcertfile}"
$certkeycontent = "${tfcertkeycontent}"
$S3ConnID = "${tfS3ConnID}"
$S3ConnPW = "${tfS3ConnPW}"
$customerID = "${tfcustomerID}"
$adminserver = "${tfadminserver}"
$serviceacct = "${tfserviceacct}" 
$bucketname = "${tfbucketname}"
$AccecssKey = "${tfAccecssKey}"
$SecretKey = "${tfSecretKey}"

# Set S3 Licensing
try {
    add-s3license -tbuid "$S3ConnID" -tbpw "$S3ConnPW" # provided by GM, supplied by TF 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 license from terraform "$S3ConnID" and "$S3ConnPW""
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting S3 license" -ForegroundColor Red 
}

# Set S3 Bucket 
try {
    add-s3bucketonly -bucketname "$bucketname" -accesskey "$AccecssKey" -secretkey "$SecretKey" # provided by GM, supplied by TF 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 Bucket from terraform "$bucketname""
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting S3 license" -ForegroundColor Red 
}

# Set Customer ID:
try {
    set-customer -id "$customerID"
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set Customer ID from terraform $customerID"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting Customer ID" -ForegroundColor Red 
}

# Set IrisAdmin Server host:
try {
    set-iaadmin -licserver "$adminserver" 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set IA Admin Server from terraform "$adminserver""
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting IrisAdmin ID" -ForegroundColor Red 
}

# Set IA License File (Admin only)
try {
    
    $licpath = "$($env:PUBLIC)\Documents\GrayMeta\Iris Server\License\ForImport"
    if ($liccontent) {
        New-Item -Path $licpath\license.plic -ItemType File 
        Add-content -Path $licpath\license.plic -Value "$liccontent"
        # Write to IA event log what was inserted by TF
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set IA License from terraform "$liccontent""
    } 
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception during the S3 Licensing process" -ForegroundColor Red 
}
    
# Set SSL Certs 
try {
    $certfile = "$certfile"
    $certkey = "$certkeycontent"
    $certpath = "$($env:PUBLIC)\Documents\GrayMeta\Iris Anywhere\Certs"
    # if cert info is present create file
    if ($certkeycontent) {
        New-Item -Path $certpath\server.key -ItemType File
        Add-content -Path $certpath\server.key -Value "$certkeycontent"
        # Write to IA event log what was inserted by TF
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Certificate Private Key set successfully"
    }
    if ($certfile) {
        New-Item -Path $certpath\server.crt -ItemType File 
        Add-content -Path $certpath\server.crt -Value "$certfile"        
        # Write to IA event log what was inserted by TF   
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Certificate CRT set successfully"
    }
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception during the certificate configuration process" -ForegroundColor Red 
    }

# Creates Secure Credential, User and sets autologon for Iris to Run w/o intervention
$credfile = "$($env:ProgramFiles)\GrayMeta\Iris Anywhere\ia.cred"

# Import System.Web assembly
    Add-Type -AssemblyName System.Web
# Generate random password
    $newpassword    =[System.Web.Security.Membership]::GeneratePassword(16,3)
    $password       = ConvertTo-SecureString $newpassword -AsPlainText -Force
    $credential     = New-Object System.Management.Automation.PSCredential ("$serviceacct", $password)
    # Add logic to remove pw var, add event log entry and catch exceptions

# Stores credential securely
    $credential | Export-CliXml -Path $credfile

# Retreives credential securely
    $credential = Import-CliXml -Path $credfile

# Creates Local User for logon
    New-localuser -name "$serviceacct"  -fullname "Iris-service-account" -Password $credential.Password -Description "service account Iris Anywhere" -UserMayNotChangePassword -AccountNeverExpires -PasswordNeverExpires

# Adds User to local Admin
    Add-LocalGroupMember -Group "Administrators" -Member "$serviceacct" 

# Sets autologon
    $autologon  = "$($env:ChocolateyInstall)\bin\autologon.exe"
    $username   =  $credential.username
    $domain     = "$env:COMPUTERNAME"
    $password   =  $credential.Password 
    Start-Process $autologon -ArgumentList $username,$domain,$password
    # Add event log entry and catch exceptions


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


Start-Sleep -Seconds 30
Restart-Computer -Force

</powershell>