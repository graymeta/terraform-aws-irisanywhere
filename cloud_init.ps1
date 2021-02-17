<powershell>
Write-Host "Download IA-ASG"
Read-S3Object -BucketName sattler-test -Key ia-mock-windows -File "C:\ia-mock-windows.exe"
Read-S3Object -BucketName sattler-test -Key ia-asg-windows -File "C:\ia-asg-windows.exe"


# Requires declared TF Variables

# $tfliccontent      = IA license file data
# $tfcertfile        = Certificate in x509 format DER
# $tfcertkeycontent  = Private for Cert
# $tfS3ConnID        = S3 Connector SaaS license UID
# $tfS3ConnPW        = S3 Connector SaaS license PW 
# $tfcustomerID      = Set Iris CustomerID
# $tfserviceacct     = Sets Service Account for autologon
# $tfbucketname      = Bucket Name
# $tfAccecssKey      = Access key for bucket access
# $tfSecretKey       = Secret key for bucket access

# Set S3 Licensing
try {
    add-s3license -tbuid $tfS3ConnID -tbpw $tfS3ConnPW # provided by GM, supplied by TF 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 license from terraform $tfs3connID and $tfS3ConnPW"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting S3 license" -ForegroundColor Red 
}

# Set S3 Bucket 
try {
    add-s3bucketonly -bucketname "$tfbucketname" -accesskey "$tfAccecssKey" -secretkey "$tfSecretKey" # provided by GM, supplied by TF 
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Added S3 Bucket from terraform $tfbucketname"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting S3 license" -ForegroundColor Red 
}
# Set Customer ID:
try {
    set-customerid -id $tfcustomerid
    # Write to IA event log what was inserted by TF
    Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set Customer ID from terraform $tfcustomerid"
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception setting Customer ID" -ForegroundColor Red 
}
   
# Set IA Licensing (Admin only)
try {
    $liccontent = $tfliccontent #declared in tf
    $licpath = "$($env:PUBLIC)\Documents\GrayMeta\Iris Server\License\ForImport"
    if ($liccontent) {
        New-Item -Path $licpath\license.plic -ItemType File 
        Add-content -Path $licpath\license.plic -Value $liccontent 
        # Write to IA event log what was inserted by TF
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Set IA License from terraform $tfliccontent"
    } 
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception during the S3 Licensing process" -ForegroundColor Red 
}
    
# Set SSL Certs 
try {
    $certfile = $tfcertfile #declared in tf
    $certkey = $tfcertkeycontent #declared in tf
    $certpath = "$($env:PUBLIC)\Documents\GrayMeta\Iris Anywhere\Certs"
    # if cert info is present create file
    if ($certkey) {
        $certkey = New-Item -Path $certpath\server.key -ItemType File
        Add-content -Path $certpath\server.key -Value $certkey
        # Write to IA event log what was inserted by TF
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Certificate Private Key set successfully"
    }
    if ($certfile) {
        $certfile = New-Item -Path $certpath\server.crt -ItemType File 
        Add-content -Path $certpath\server.crt -Value $certfile         
        # Write to IA event log what was inserted by TF   
        Write-EventLog -LogName IrisAnywhere -source IrisAnywhere -EntryType Information -eventid 1000 -message "Certificate CRT set successfully"
    }
}
catch {
    Write-host $_.Exception | Format-List -force
    Write-host "Exception during the certificate configuration process" -ForegroundColor Red 
    }

# Creates Secure Credential, User and sets autologon for Iris to Run w/o intervention
$credfile = "${env:ProgramFiles}\GrayMeta\Iris Anywhere\ia.cred"
# Import System.Web assembly
    Add-Type -AssemblyName System.Web
# Generate random password
    $newpassword    =[System.Web.Security.Membership]::GeneratePassword(16,3)
    $password       = ConvertTo-SecureString $newpassword -AsPlainText -Force
    $credential     = New-Object System.Management.Automation.PSCredential ("$tfserviceacct", $password)

# Stores credential securely
    $credential | Export-CliXml -Path $credfile

# Retreives credential securely
    $credential = Import-CliXml -Path $credfile

# Creates Local User for logon
    New-localuser -name $tfserviceacct -fullname "Iris-service-account" -Password $credential.Password -Description "service account Iris Anywhere" -UserMayNotChangePassword -AccountNeverExpires -PasswordNeverExpires

# Adds User to local Admin
    Add-LocalGroupMember -Group "Administrators" -Member $tfserviceacct

# Sets autologon
    $autologon  = "${env:ChocolateyInstall}\bin\autologon.exe"
    $username   =  $credential.username
    $domain     = "$env:COMPUTERNAME"
    $password   =  $credential.Password 
    Start-Process $autologon -ArgumentList $username,$domain,$password

</powershell>