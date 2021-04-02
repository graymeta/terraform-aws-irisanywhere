<powershell>
Write-Output "TIMING: Cloud_init start at $(Get-Date)"

$iadmid = "${ia_adm_id}"
$iadmpw = "${ia_adm_pw}"
$certfile = "${ia_cert_file}"
$certkeycontent = "${ia_cert_key_content}"
$S3ConnID = "${ia_s3_conn_id}"
$S3ConnPW = "${ia_s3_conn_code}"
$customerID = "${ia_customer_id}"
$adminserver = "${ia_admin_server}"
$serviceacct = "${ia_service_acct}" 
$bucketname = "${ia_bucket_name}"
$AccessKey = "${ia_access_key}"
$SecretKey = "${ia_secret_key}"
$MaxSessions = "${ia_max_sessions}"

# Set S3 Licensing
try {
    add-s3license -tbuid "$S3ConnID" -tbpw "$S3ConnPW" # provided by GM, supplied by TF 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 license from terraform "$S3ConnID""
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting S3 license" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error adding S3 license from terraform "$S3ConnID""
}

# Set S3 Bucket 
try {
    Unregister-ScheduledTask -TaskName "HDD_init" -Confirm:$false  -ErrorAction SilentlyContinue | Out-Null
    add-s3bucketonly -bucketname "$bucketname" -accesskey "$AccessKey" -secretkey "$SecretKey" # provided by GM, supplied by TF 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 Bucket from terraform $bucketname"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting S3 license" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error adding S3 Bucket from terraform $bucketname"
}

# Set Iris Admin Customer ID:
try {
    set-customer -id "$customerID"
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set Customer ID from terraform $customerID"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting Customer ID" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting Customer ID from terraform $customerID"
}

# Set Iris Admin Server credentials:
try {
    set-iaadmincreds -uid "$iadmid" -pass "$iadmpw"
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set IA Admin server credentials from terraform"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting Iris Admin credentials" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting IA Admin server credentials from terraform"
}

# Set Iris Admin Server host:
try {
    set-iaadmin -licserver "$adminserver" 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set IA Admin Server from terraform "$adminserver""
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting IrisAdmin ID" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting IA Admin Server from terraform "$adminserver""
}

# Set Iris Anywhere Max Sessions:
try {
    set-maxsessions -sessions "$MaxSessions"
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set max sessions to $MaxSessions"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting max session value" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting max sessions to $MaxSessions"
}

# Set Iris Admin License 
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
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting IA License from terraform "$liccontent""
}
    
# Set SSL Certs 
try {
    $certfile = "$certfile"
    #$certkey = "$certkeycontent"
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
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting certificate data"
}

# Creates Secure Credential, User and sets autologon for Iris to Run w/o intervention

# Set SSL Certs 
try {
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
    Start-Process $autologon -ArgumentList $username,$domain,$newpassword
    # Remove vars
    remove-variable autologon ; remove-variable username ; remove-variable domain ; remove-variable password ; remove-variable newpassword
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception establishing autologon configuration" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Exception establishing autologon configuration"
}

# Setup the ia-asg service
[System.Environment]::SetEnvironmentVariable('gm_ia_addr', 'http://127.0.0.1:8080', [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('gm_ia_metric_interval', "${metric_check_interval}s", [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('gm_ia_health_interval', "${health_check_interval}s", [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('gm_ia_health_threshold', "${unhealthy_threshold}", [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('gm_ia_cooldown', "${cooldown}s", [System.EnvironmentVariableTarget]::User)
New-Service -Name ia-asg `
    -BinaryPathName "C:\Program Files\Graymeta\asg\bin\ia_asg.exe" `
    -DisplayName ia-asg `
    -Description "Iris Anywhere Autoscaling Service" `
    -StartupType "Automatic"
Start-Service -Name ia-asg
New-NetFirewallRule -DisplayName "Allow inbound TCP port 9000 IA-ASG" -Direction inbound -LocalPort 9000 -Protocol TCP -Action Allow

# Create a Name tag
$webclient = new-object net.webclient
$instanceid = $webclient.Downloadstring('http://169.254.169.254/latest/meta-data/instance-id')
[System.Environment]::SetEnvironmentVariable('INSTANCE_ID', $instanceid, [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('INSTANCE_NAME', "${name}-"+$instanceid, [System.EnvironmentVariableTarget]::User)
Import-Module -name AWSPowerShell
$tag = New-Object Amazon.EC2.Model.Tag
$tag.Key = "Name"
$tag.Value = "${name}-"+$instanceid
New-EC2Tag -Resource $instanceid -Tag $tag

# Restarting host to invoke autologon
Start-Sleep -Seconds 30
Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Init Complete - Restarting"
Write-Output "TIMING: rebooting now at $(Get-Date)"
Restart-Computer -Force

</powershell>
