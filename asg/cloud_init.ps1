Write-Output "TIMING: Cloud_init start at $(Get-Date)"

$MaxSessions = "${ia_max_sessions}"
$certcrtarn = "${ia_cert_crt_arn}"
$certkeyarn = "${ia_cert_key_arn}"
$iasecretarn = "${ia_secret_arn}"
$iadomain = "${ia_domain}"
$search_enabled = "${search_enabled}"

#Retrieve and prepare Secrets
try {
    $secretdata = get-SECsecretValue $iasecretarn ; $secretdata=$secretdata.secretstring | convertfrom-json

    #Set init variables
    $admin_customer_id  = $secretdata.admin_customer_id
    $admin_db_id        = $secretdata.admin_db_id
    $admin_db_pw        = $secretdata.admin_db_pw
    $admin_server       = $secretdata.admin_server
    $iris_s3_bucketname = $secretdata.iris_s3_bucketname
    $iris_s3_access_key = $secretdata.iris_s3_access_key
    $iris_s3_secret_key = $secretdata.iris_s3_secret_key
    $iris_s3_lic_code   = $secretdata.iris_s3_lic_code
    $iris_s3_lic_id     = $secretdata.iris_s3_lic_id
    $iris_serviceacct   = $secretdata.iris_serviceacct

    $okta_issuer        = $secretdata.okta_issuer
    $okta_clientid	    = $secretdata.okta_clientid
    $okta_redirecturi   = $secretdata.okta_redirecturi
    $okta_scope         = $secretdata.okta_scope

    $s3_meta_bucketname = $secretdata.s3_meta_bucketname
    $s3_meta_access_key = $secretdata.s3_meta_access_key
    $s3_meta_secret_key = $secretdata.s3_meta_secret_key

    $os_endpoint = $secretdata.os_endpoint
    $os_region = $secretdata.os_region
    $os_accessid = $secretdata.os_accessid
    $os_secretkey = $secretdata.os_secretkey
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception accessing secret $iasecretarn" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Exception accessing secret $iasecretarn"
}

# Set Leaf Certs 
try {
    if($certcrtarn) {$crt=Get-SECSecretValue $certcrtarn ; $crt = $crt | select -expandproperty secretstring ; add-content -Value $crt 'C:\Users\Public\Documents\GrayMeta\Iris Anywhere\Certs\server.crt'
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Leaf Cert Added" }
    if($certkeyarn) {$key=Get-SECSecretValue $certkeyarn ; $key = $key | select -expandproperty secretstring ; add-content -Value $key 'C:\Users\Public\Documents\GrayMeta\Iris Anywhere\Certs\server.key'
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Private key added" }
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception adding certificates" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Exception adding certificates from terraform"
}

# Set S3 Licensing
try {
    add-s3license -tbuid "$iris_s3_lic_id" -tbpw "$iris_s3_lic_code" # provided by GM, supplied by TF 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 license from terraform "$iris_s3_lic_id""
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting S3 license" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error adding S3 license from terraform "$iris_s3_lic_id""
}

# Set S3 Bucket 

if($s3_meta_bucketname){
    $bucketlist=$iris_s3_bucketname -split ", "
    foreach($i in $bucketlist){
        $dir = "D:\irisanywhere\$($i)"
        new-item $dir -ItemType Directory
        Write-Host "Found Meta config for bucket $i to directory "$dir" with meta credentials $s3_meta_access_key"
        tiercli config "$dir" target s3 '""' '""' http://s3.amazonaws.com
        #tiercli config "$dir" target s3 "$iris_s3_access_key" "$iris_s3_secret_key" http://s3.amazonaws.com
        tiercli config "$dir" container  "$i"
        tiercli config "$dir" meta "$s3_meta_bucketname" "$s3_meta_access_key" "$s3_meta_secret_key"    
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Meta bucket $s3_meta_bucketname  & $dir"
    }
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Meta access key $s3_meta_access_key" 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Meta secret key $s3_meta_secret_key"    
    tiercli config reload
}
else {

try {
    Unregister-ScheduledTask -TaskName "HDD_init" -Confirm:$false  -ErrorAction SilentlyContinue | Out-Null
    $bucketlist=$iris_s3_bucketname -split ", "
    foreach($i in $bucketlist){
        $dir = "D:\irisanywhere\$($i)"
        new-item $dir -ItemType Directory
        tiercli config "$dir" target s3 '""' '""' http://s3.amazonaws.com
        tiercli config "$dir" container  "$i"
        tiercli config reload
    #add-s3bucketonly -bucketname "$i" -accesskey "$iris_s3_access_key" -secretkey "$iris_s3_secret_key" # provided by GM, supplied by TF 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 Bucket from terraform $i" 
    }
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception S3 Bucket" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error adding S3 Bucket from terraform "$i""
    }
}
# Set Iris Admin Customer ID:
try {
    set-customer -id "$admin_customer_id"
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set Customer ID from terraform $admin_customer_id"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting Customer ID" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting Customer ID from terraform "$admin_customer_id""
}

# Set Iris Admin Server credentials:
try {
    set-iaadmincreds -uid "$admin_db_id" -pass "$admin_db_pw"
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
    set-iaadmin -licserver "$admin_server" 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set IA Admin Server from terraform "$admin_server""
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting IrisAdmin ID" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting IA Admin Server from terraform "$admin_server""
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

# Set Okta config:
try {
    if($okta_issuer){
    set-okta -enabled "true" -issuer "$okta_issuer" -clientid "$okta_clientid" -redirecturi "$okta_redirecturi" -scope "$okta_scope"
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set Okta config from terraform"}
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting Okta Config" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting Okta config from terraform"
}

try {
    if($search_enabled){
    set-opensearch -osenabled "true" -region "$os_region" -domain "$os_endpoint" -accessid "$os_accessid" -secretkey "$os_secretkey"
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set OpenSearch config from terraform"}
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting OpenSearch Config" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting OpenSearch config from terraform"
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

# Creates Secure Credential, User and sets autologon for Iris to Run w/o intervention

try {
    $credfile = "$($env:ProgramFiles)\GrayMeta\Iris Anywhere\ia.cred"

    # Import System.Web assembly
    Add-Type -AssemblyName System.Web

    # Generate random password
    $newpassword    =[System.Web.Security.Membership]::GeneratePassword(16,3)
    $password       = ConvertTo-SecureString $newpassword -AsPlainText -Force
    $credential     = New-Object System.Management.Automation.PSCredential ("$iris_serviceacct", $password)
    # Add logic to remove pw var, add event log entry and catch exceptions

    # Stores credential securely
    $credential | Export-CliXml -Path $credfile

    # Retreives credential securely
    $credential = Import-CliXml -Path $credfile

    # Creates Local User for logon
    New-localuser -name "$iris_serviceacct"  -fullname "Iris-service-account" -Password $credential.Password -Description "service account Iris Anywhere" -UserMayNotChangePassword -AccountNeverExpires -PasswordNeverExpires

    # Adds User to local Admin
    Add-LocalGroupMember -Group "Administrators" -Member "$iris_serviceacct" 

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

#CW Config
try {
    & $env:ProgramFiles\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1 -a fetch-config -m ec2 -c file:$env:ProgramFiles\Amazon\AmazonCloudWatchAgent\config.json -s

}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Error setting cloudwatch config" -ForegroundColor Red 
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting config"
}

# Setup the ia-asg service
$nodefqdn= -join("$env:COMPUTERNAME",".","$iadomain")
$ia_https_url="https://$($nodefqdn):443"
$ia_http_url="http://127.0.0.1:8080"

if($certkeyarn){
    [System.Environment]::SetEnvironmentVariable('gm_ia_addr', $ia_https_url, [System.EnvironmentVariableTarget]::Machine)

    $HostFile = 'C:\Windows\System32\drivers\etc\hosts'     
    Add-content -path $HostFile -value "127.0.0.1 `t $nodefqdn"

}else {
    [System.Environment]::SetEnvironmentVariable('gm_ia_addr', $ia_http_url, [System.EnvironmentVariableTarget]::Machine)
}
[System.Environment]::SetEnvironmentVariable('gm_ia_metric_interval', "${metric_check_interval}s", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('gm_ia_health_interval', "${health_check_interval}s", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('gm_ia_health_threshold', "${unhealthy_threshold}", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('gm_ia_cooldown', "${cooldown}s", [System.EnvironmentVariableTarget]::Machine)
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
[System.Environment]::SetEnvironmentVariable('INSTANCE_ID', $instanceid, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('INSTANCE_NAME', "${name}-"+$instanceid, [System.EnvironmentVariableTarget]::Machine)
Import-Module -name AWSPowerShell
$tag = New-Object Amazon.EC2.Model.Tag
$tag.Key = "Name"
$tag.Value = "${name}-"+$instanceid
New-EC2Tag -Resource $instanceid -Tag $tag

# Restarting host to invoke autologon
Start-Sleep -Seconds 10
Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Init Complete - Restarting"

