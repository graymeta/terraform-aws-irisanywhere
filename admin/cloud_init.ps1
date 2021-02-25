<powershell>

#remove jobs from startup
$jobs = "HDD_init", "sync-s3", "check-iris", "launchiris", "G4DN-VideoDrivers", "iastdlog"
foreach($job in $jobs){ Unregister-ScheduledTask -TaskName "$job" -Confirm:$false  -ErrorAction SilentlyContinue | Out-Null }

</powershell>