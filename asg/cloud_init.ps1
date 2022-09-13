Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 6009 -message "TIMING: Cloud_init start at $(Get-Date)"
#Retrieve and prepare Secrets 
    $MaxSessions = "${ia_max_sessions}"
    $certcrtarn = "${ia_cert_crt_arn}"
    $certkeyarn = "${ia_cert_key_arn}"
    $iasecretarn = "${ia_secret_arn}"
    $iadomain = "${ia_domain}"
    $search_enabled = "${search_enabled}"
    $s3_sse_bucketkey_enabled = "${s3_sse_bucketkey_enabled}"
    $s3_sse_cmk_enabled = "${s3_sse_cmk_enabled}"
    $s3_sse_cmk_arn = "${s3_sse_cmk_arn}"
    $ia_video_bitrate = "${ia_video_bitrate}"
    $ia_video_codec = "${ia_video_codec}"
    $s3_progressive_retrieval = "${s3_progressive_retrieval}"
    $s3_reclaim_maxused = "${s3_reclaim_maxused}"
    $s3_reclaim_minused = "${s3_reclaim_minused}"
    $s3_reclaim_age = "${s3_reclaim_age}"
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
        $os_endpoint        = $secretdata.os_endpoint
        $os_region          = $secretdata.os_region
        $os_accessid        = $secretdata.os_accessid
        $os_secretkey       = $secretdata.os_secretkey
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Exception accessing secret $iasecretarn"
    }
    try {
        Initialize-Disk 1 -PartitionStyle GPT -Confirm:$false | Out-Null
        New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter D | Out-Null
        Format-Volume -DriveLetter D -FileSystem NTFS -Confirm:$false | Out-Null
        New-Item D:\IrisAnywhere -ItemType Directory -Force | Out-Null 
        }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error staging EBS"
    }

    # Set Leaf Certs 
    try {
        if($certcrtarn) {$crt=Get-SECSecretValue $certcrtarn ; $crt = $crt | select -expandproperty secretstring ; add-content -Value $crt 'C:\Users\Public\Documents\GrayMeta\Iris Anywhere\Certs\server.crt'
            Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Leaf Cert Added" }
        if($certkeyarn) {$key=Get-SECSecretValue $certkeyarn ; $key = $key | select -expandproperty secretstring ; add-content -Value $key 'C:\Users\Public\Documents\GrayMeta\Iris Anywhere\Certs\server.key'
            Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Private key added" 
            # Disable HTTP redir
            set-httpredir -enable true
        }
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Exception adding certificates from terraform"
    }
    # Set S3 Licensing
    try {
        add-s3license -tbuid "$iris_s3_lic_id" -tbpw "$iris_s3_lic_code" # provided by GM, supplied by TF 
        # Write to IA event log what was inserted by TF
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 license from terraform "$iris_s3_lic_id""
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error adding S3 license from terraform "$iris_s3_lic_id""
    }
    # Set S3 Bucket 
    if($s3_meta_bucketname){
        $bucketlist=$iris_s3_bucketname -split ", "
        $bucketpaths = New-Object System.Collections.ArrayList
        foreach($i in $bucketlist){
            $dir = "D:\irisanywhere\$($i)"        
            new-item $dir -ItemType Directory
            tiercli config "$dir" target s3 '""' '""' https://s3.amazonaws.com
            #tiercli config "$dir" target s3 "$iris_s3_access_key" "$iris_s3_secret_key" https://s3.amazonaws.com
            tiercli config "$dir" container  "$i"
            tiercli config policy reclaimspace turn on
            tiercli config policy reclaimspace age $s3_reclaim_age
            tiercli config policy reclaimspace maxused $s3_reclaim_maxused
            tiercli config policy reclaimspace minused $s3_reclaim_minused
            tiercli utils clear_rehydrate "$dir"
            tiercli config "$dir" meta "$s3_meta_bucketname" "$s3_meta_access_key" "$s3_meta_secret_key" yes
            Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Meta bucket $s3_meta_bucketname  & $dir"
        }
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Meta access key $s3_meta_access_key" 
        tiercli config reload
        tiercli op clean "$dir"
        $bucketpaths.add("$dir")
        tiercli config include $bucketpaths
    }
    else {
    try {
        Unregister-ScheduledTask -TaskName "HDD_init" -Confirm:$false  -ErrorAction SilentlyContinue | Out-Null
        $bucketlist=$iris_s3_bucketname -split ", "
        $bucketpaths = New-Object System.Collections.ArrayList
        foreach($i in $bucketlist){
            $dir = "D:\irisanywhere\$($i)"
            new-item $dir -ItemType Directory
            tiercli config "$dir" target s3 '""' '""' https://s3.amazonaws.com
            tiercli config "$dir" container  "$i"
            if($s3_sse_cmk_enabled = "true") {
                tiercli config "$dir" sse SSE-KMS "$s3_sse_cmk_arn"
            }
            if($s3_sse_bucketkey_enabled = "true") {
                tiercli config "$dir" sse SSE-KMS "bucket-key"
            }
            tiercli config policy reclaimspace turn on
            tiercli config policy reclaimspace age $s3_reclaim_age
            tiercli config policy reclaimspace maxused $s3_reclaim_maxused
            tiercli config policy reclaimspace minused $s3_reclaim_minused
            tiercli utils clear_rehydrate "$dir"
            tiercli config reload 
            tiercli op clean "$dir"
            
        #add-s3bucketonly -bucketname "$i" -accesskey "$iris_s3_access_key" -secretkey "$iris_s3_secret_key" # provided by GM, supplied by TF 
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 Bucket from terraform $i" 
        $bucketpaths.add("$dir")
        }
        tiercli config include $bucketpaths
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error adding S3 Bucket from terraform "$i""
        }
    }
    # Set Iris Admin Customer ID:
    try {
        set-customer -id "$admin_customer_id"
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set Customer ID from terraform $admin_customer_id"
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting Customer ID from terraform "$admin_customer_id""
    }
    # Set Iris Admin Server credentials:
    try {
        set-iaadmincreds -uid "$admin_db_id" -pass "$admin_db_pw"
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set IA Admin server credentials from terraform"
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting IA Admin server credentials from terraform"
    }
    # Set Iris Admin Server host:
    try {
        set-iaadmin -licserver "$admin_server" 
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set IA Admin Server from terraform "$admin_server""
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting IA Admin Server from terraform "$admin_server""
    }
    # Set Iris Anywhere Max Sessions:
    try {
        set-maxsessions -sessions "$MaxSessions"
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set max sessions to $MaxSessions"
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting max sessions to $MaxSessions"
    }
    # Set Iris Anywhere Video bitrate settings:
    try {
        set-videobitrate -bitrate "$ia_video_bitrate" -codec "$ia_video_codec"
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set video bitrate to $ia_video_bitrate and codec to $ia_video_codec"
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting bitrate value to $ia_video_bitrate and codec to $ia_video_codec"
    }
    # Set Okta config:
    try {
        if($okta_issuer){
        set-okta -enabled "true" -issuer "$okta_issuer" -clientid "$okta_clientid" -redirecturi "$okta_redirecturi" -scope "$okta_scope"
        # Write to IA event log what was inserted by TF
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set Okta config from terraform"}
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting Okta config from terraform"
    }
    # Set Search config:
    try {
        if($search_enabled -eq "true"){
        set-opensearch -osenabled "true" -region "$os_region" -domain "$os_endpoint" -accessid "$os_accessid" -secretkey "$os_secretkey"
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set OpenSearch config from terraform"}
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting OpenSearch config from terraform"
    }
    # Set progressive_retrieval
    try {
        if($s3_progressive_retrieval -eq "false"){
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Tiger Technology\tiger-bridge\tiersvc\settings" -name "progressive_restore_mode" -value 0 }
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Error setting Progressive Retrieval config from terraform"
    }
    # Creates Secure Credential, User and sets autologon for Iris to Run w/o intervention
    try {
        $credfile = "$($env:ProgramFiles)\GrayMeta\Iris Anywhere\ia.cred"
        if($IsNullOrWhiteSpace -eq $iris_serviceacct -or $iris_serviceacct -eq ""){$iris_serviceacct = "iris-service"}
        Add-Type -AssemblyName System.Web
        $newpassword    =[System.Web.Security.Membership]::GeneratePassword(16,3)
        $password       = ConvertTo-SecureString $newpassword -AsPlainText -Force
        $credential     = New-Object System.Management.Automation.PSCredential ("$iris_serviceacct", $password)
        $credential | Export-CliXml -Path $credfile
        $credential = Import-CliXml -Path $credfile
        New-localuser -name "$iris_serviceacct"  -fullname "Iris-service-account" -Password $credential.Password -Description "service account Iris Anywhere" -UserMayNotChangePassword -AccountNeverExpires -PasswordNeverExpires
        Add-LocalGroupMember -Group "Administrators" -Member "$iris_serviceacct" 
        $autologon  = "$($env:ChocolateyInstall)\bin\autologon.exe"
        $username   =  $credential.username
        $domain     = "$env:COMPUTERNAME"
        $password   =  $credential.Password 
        Start-Process $autologon -ArgumentList $username,$domain,$newpassword
        remove-variable autologon ; remove-variable username ; remove-variable domain ; remove-variable password ; remove-variable newpassword
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Exception establishing autologon configuration"
    }
    #CW Config
    try {
        & $env:ProgramFiles\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1 -a fetch-config -m ec2 -c file:$env:ProgramFiles\Amazon\AmazonCloudWatchAgent\config.json -s
    
    }
    catch {
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
    $webclient = new-object net.webclient
    $instanceid = $webclient.Downloadstring('http://169.254.169.254/latest/meta-data/instance-id')
    [System.Environment]::SetEnvironmentVariable('INSTANCE_ID', $instanceid, [System.EnvironmentVariableTarget]::Machine)
    [System.Environment]::SetEnvironmentVariable('INSTANCE_NAME', "${name}-"+$instanceid, [System.EnvironmentVariableTarget]::Machine)
    Import-Module -name AWSPowerShell
    $tag = New-Object Amazon.EC2.Model.Tag
    $tag.Key = "Name"
    $tag.Value = "${name}-"+$instanceid
    New-EC2Tag -Resource $instanceid -Tag $tag
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Init Complete - Restarting"
    Rename-Computer -NewName $instanceid -force
