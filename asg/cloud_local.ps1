Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Initiate Cloud Init..."
#Retrieve and prepare Secrets 
    $MaxSessions = "${ia_max_sessions}"
    $keepalivetimeout = "${ia_keepalivetimeout}"
    $certcrtarn = "${ia_cert_crt_arn}"
    $certkeyarn = "${ia_cert_key_arn}"
    $iasecretarn = "${ia_secret_arn}"
    $iadomain = "${ia_domain}"
    $search_enabled = "${search_enabled}"
    $ia_video_bitrate = "${ia_video_bitrate}"
    $ia_video_codec = "${ia_video_codec}"
    $s3_enterprise = "${s3_enterprise}"
    $haproxy = "${haproxy}"
    $saml_enabled = "${saml_enabled}"
    $saml_cert_secret_arn = "${saml_cert_secret_arn}"
    $disk_data_size = "${disk_data_size}"
    $otlp_enabled = "${otlp_enabled}"
    $otlp_agent_gateway_endpoint = "${otlp_exporter_destination}"
    #$wasabi = "${wasabi}"
    #Retrieve and prepare Secrets
    try {
        $secretdata = get-SECsecretValue $iasecretarn ; $secretdata=$secretdata.secretstring | convertfrom-json
        #Set init variables
        $admin_customer_id      = $secretdata.admin_customer_id
        $admin_db_id            = $secretdata.admin_db_id
        $admin_db_pw            = $secretdata.admin_db_pw
        $admin_server           = $secretdata.admin_server
        $okta_issuer            = $secretdata.okta_issuer
        $okta_clientid	        = $secretdata.okta_clientid
        $okta_redirecturi       = $secretdata.okta_redirecturi
        $okta_scope             = $secretdata.okta_scope
        $os_endpoint            = $secretdata.os_endpoint
        $os_region              = $secretdata.os_region
        $saml_uniqueid          = $secretdata.saml_uniqueid
        $saml_displayname       = $secretdata.saml_displayname
        $saml_entryPoint        = $secretdata.saml_entryPoint
        $saml_samlissuer        = $secretdata.saml_samlissuer
        $saml_acsUrlBasePath    = $secretdata.saml_acsUrlBasePath
        $saml_acsUrlRelativePath = $secretdata.saml_acsUrlRelativePath
        $rfm_filters             = $secretdata.rfm_filters
        #$otlp_agent_gateway_endpoint = $secretdata.otlp_agent_gateway_endpoint
        #$wasabi_access_key       = $secretdata.wasabi_access_key
        #$wasabi_secret_access_key= $secretdata.wasabi_secret_access_key
        #$wasabi_endpoint         = $secretdata.wasabi_endpoint
        #$wasabi_region            = $secretdata.wasabi_region
        #$wasabi_buckets          = $secretdata.wasabi_buckets
    }
    catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1001 -message "Exception accessing secret $iasecretarn"
    }


    try {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Initiate local_init... "
        & "C:\ProgramData\GrayMeta\launch\scripts\local_init_enterprise_rclone.ps1"
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Completed local_init"
    } catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType `
        Error -eventid 1002 -message "Exception executing local_init_enterprise_rclone.ps1: $_"
    }

#rclone warm: retune the mounts local_init wrote and install the auto-warm watcher (runs at startup)
if ($s3_enterprise -eq "true" -and "${file_warm}" -eq "true") {
    try {
        $warmDir = "C:\rclone\warm"
        New-Item -ItemType Directory -Force -Path $warmDir | Out-Null
        $gz = New-Object IO.Compression.GZipStream((New-Object IO.MemoryStream(,[Convert]::FromBase64String('${rclone_warm_watcher}'))), [IO.Compression.CompressionMode]::Decompress)
        $out = [IO.File]::Create((Join-Path $warmDir 'rclone-autowarm.ps1')); $gz.CopyTo($out); $out.Close(); $gz.Close()

        #Mount flags; --rc (one localhost port per bucket, 5572 up) lets the watcher lower --buffer-size while it warms
        $flags = @{ 'vfs-cache-max-age' = '${rclone_warm_max_age}'; 'vfs-read-chunk-size' = '64K'; 'vfs-read-chunk-size-limit' = '2M'
                    'vfs-read-chunk-streams' = '16'; 'vfs-read-ahead' = '0'; 'buffer-size' = '64M'; 'low-level-retries' = '10' }
        $mountScript = Get-Content C:\rclone\bucketmount.ps1 -Raw
        $watchdogScript = Get-Content C:\rclone\watchdog.ps1 -Raw
        foreach ($k in $flags.Keys) {
            $mountScript = $mountScript -replace "('--$k',\s*)'[^']*'", "`$1'$($flags[$k])'"
            $watchdogScript = $watchdogScript -replace "(`"--$k`",)`"[^`"]*`"", "`$1`"$($flags[$k])`""
        }
        $port = [ref]5571
        $mountScript = [regex]::Replace($mountScript, "'--log-level', 'NOTICE'", { param($m) $port.Value++; "'--log-level', 'NOTICE', '--rc', '--rc-addr', '127.0.0.1:$($port.Value)', '--rc-no-auth'" })
        $watchdogScript = $watchdogScript.Replace('"--log-level","NOTICE"', '"--log-level","NOTICE","--rc","--rc-addr","127.0.0.1:$(5572 + [array]::IndexOf($buckets, $b))","--rc-no-auth"')
        Set-Content C:\rclone\bucketmount.ps1 -Value $mountScript -NoNewline
        Set-Content C:\rclone\watchdog.ps1 -Value $watchdogScript -NoNewline

        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$warmDir\rclone-autowarm.ps1`""
        #At startup, and every minute so a stopped watcher comes back (skipped while it is running)
        $triggers = @((New-ScheduledTaskTrigger -AtStartup), (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)))
        $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName 'rclone-autowarm' -Action $action -Trigger $triggers -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "rclone warm installed: mounts retuned, rclone-autowarm task registered"
    } catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1002 -message "Exception installing rclone warm: $_"
    }
}

#Start SSM Service
Set-Service -Name AmazonSSMAgent -StartupType Automatic ; Start-Service AmazonSSMAgent

#Update Instance
$instanceid = Get-MetaData -MetaDataType "instanceId"

[System.Environment]::SetEnvironmentVariable('INSTANCE_ID', $instanceid, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('INSTANCE_NAME', "${name}-$instanceid", [System.EnvironmentVariableTarget]::Machine)

Import-Module -Name AWSPowerShell #deprecated
#Import-Module AWS.Tools.S3  -ErrorAction Stop
#Import-Module AWS.Tools.EC2 -ErrorAction Stop


$tag = New-Object Amazon.EC2.Model.Tag
$tag.Key = "Name"
$tag.Value = "${name}-$instanceid"
New-EC2Tag -Resource $instanceid -Tag $tag

Rename-Computer -NewName $instanceid -force
Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Cloud Init Complete - Restarting EC2 Instance"