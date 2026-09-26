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
    $file_gateway = "${file_gateway}"
    $file_gateway_ip = "${file_gateway_ip}"
    $file_gateway_id = "${file_gateway_id}"
    $file_gateway_shares = "${file_gateway_shares}"
    $file_gateway_link_root = "${file_gateway_link_root}"
    $file_gateway_link_suffix = "${file_gateway_link_suffix}"
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
        $filegateway_smb_password = $secretdata.filegateway_smb_password
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

#Map S3 File Gateway shares
#Global mappings are visible to all users and services; symlinks expose each share under the link root.
if ($file_gateway -eq "true") {
    try {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Mapping File Gateway shares from $file_gateway_ip"
        $fgwCred = New-Object System.Management.Automation.PSCredential("$file_gateway_id\smbguest", (ConvertTo-SecureString $filegateway_smb_password -AsPlainText -Force))
        Set-SmbClientConfiguration -EnableBandwidthThrottling $false -Force

        $deadline = (Get-Date).AddMinutes(10)
        while (-not (Test-Path $file_gateway_link_root) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 10 }

        foreach ($share in $file_gateway_shares.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries)) {
            $remote = "\\$file_gateway_ip\$share"
            $link = Join-Path $file_gateway_link_root "$share$file_gateway_link_suffix"

            #The share may still be coming up on a freshly created gateway
            $mapped = $false
            while (-not $mapped -and (Get-Date) -lt $deadline) {
                try {
                    if (-not (Get-SmbGlobalMapping -RemotePath $remote -ErrorAction SilentlyContinue)) {
                        New-SmbGlobalMapping -RemotePath $remote -Credential $fgwCred -Persistent $true -ErrorAction Stop | Out-Null
                    }
                    $mapped = $true
                } catch {
                    Start-Sleep -Seconds 15
                }
            }

            if (-not $mapped) {
                Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1003 -message "Could not map File Gateway share $remote"
                continue
            }
            if (-not (Test-Path $link)) {
                New-Item -ItemType SymbolicLink -Path $link -Target $remote | Out-Null
            }
        }
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Completed File Gateway share mapping"
    } catch {
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Error -eventid 1003 -message "Exception mapping File Gateway shares: $_"
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