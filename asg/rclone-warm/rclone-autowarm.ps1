# Warms files in the local rclone cache when they are opened, in two stages.
# rclone (--vfs-cache-mode full) creates a metadata file under <cache-dir>\vfsMeta\<remote>\<bucket>\
# when a file is first opened. For each new one of at least $MinSizeGB, or any caption/audio/xml file
# (image-sequence frames are skipped):
#   stage 1  non-MXF only, right away: the first 512 MB (front only)
#   stage 2  MXF only, $ProbeHeadSec after mediainfo.exe (the probe behind the Open dialog) starts, or
#            when it exits if sooner, so most of its reads are done before the warm's queue up (rclone
#            starts new reads in a file about one at a time): every MXF partition, which Iris walks one
#            by one when it opens the file after OK.
# An MXF reopened within $RecentSec after the cache dropped it goes straight to stage 2.
# At most $MaxWarms warms run at once.
# While a stage 2 warm runs, that bucket's mount has --buffer-size set to 0 through its rc port (from the
# mount's --rc-addr): every partition read would otherwise pull a whole buffer in the background. The
# previous value goes back when the bucket's last stage 2 warm ends.
# A file to be warmed is held open by this watcher from its first open, so rclone (short --vfs-cache-max-age
# drops closed files) keeps the warm while the Open dialog is up and until Iris plays it. Holds are released
# when the next main file (MXF or >= $MinSizeGB, not a caption/audio/xml sidecar) is opened, or after
# $HoldMaxSec.
$metaRoot  = "D:\rclone-cache\vfsMeta\S3BUCKETS"
$mountRoot = "D:\IrisAnywhere"
$log       = "C:\Logs\rclone-autowarm.log"
$MaxWarms  = 4
$MinSizeGB = 1
$RecentSec = 120
$ProbeWaitSec = 20
$ProbeStartSec = 3
$ProbeHeadSec = 0.5
$HoldMaxSec = 900
$PlayBuffer = 128MB   # fallback when the mount's own value can't be read
$AlwaysExt = @('.srt', '.scc', '.vtt', '.ttml', '.dfxp', '.xml', '.stl', '.cap', '.sub', '.ass', '.ssa', '.sbv', '.itt', '.mcc',
               '.wav', '.bwf', '.w64', '.aif', '.aiff', '.mp3', '.aac', '.m4a', '.flac', '.ac3', '.ec3', '.eac3', '.dts', '.mp2', '.ogg', '.opus')
$SkipExt   = @('.dpx', '.exr', '.tif', '.tiff', '.png', '.jpg', '.jpeg', '.tga', '.cin', '.j2c', '.j2k', '.jp2', '.ari', '.dng')

function Log($m) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" }

function Get-Meta {
    if (-not (Test-Path $metaRoot)) { return @() }
    Get-ChildItem $metaRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
}

# rc address of the mount serving a bucket, from its --rc-addr
function Get-RcUrl($bucket) {
    $c = (Get-CimInstance Win32_Process -Filter "Name = 'rclone.exe'" |
        Where-Object { $_.CommandLine -match "S3BUCKETS:$([regex]::Escape($bucket))\s" } | Select-Object -First 1).CommandLine
    if ($c -match '--rc-addr\s+"?([\d.]+:\d+)') { "http://$($Matches[1])" }
}

function Get-Buffer($url) {
    try { [long](Invoke-RestMethod -Method Post -Uri "$url/options/get" -TimeoutSec 5).main.BufferSize } catch { -1 }
}

function Set-Buffer($url, $bytes) {
    try {
        Invoke-RestMethod -Method Post -Uri "$url/options/set" -ContentType 'application/json' -Body "{`"main`":{`"BufferSize`":$bytes}}" -TimeoutSec 5 | Out-Null
        $true
    } catch { Log "rc $url set buffer $bytes failed: $($_.Exception.Message)"; $false }
}

$bufHold = @{}   # bucket -> @{ Url; Count; Saved }  (stage 2 warms running with buffer 0)
$warmOf  = @{}   # warm process id -> bucket
$warmPath = @{}  # warm process id -> path

function Hold-Buffer($bucket) {
    if ($bufHold.ContainsKey($bucket)) { $bufHold[$bucket].Count++; return $true }
    $url = Get-RcUrl $bucket
    if (-not $url) { return $false }
    $saved = Get-Buffer $url; if ($saved -le 0) { $saved = $PlayBuffer }
    if (-not (Set-Buffer $url 0)) { return $false }
    $bufHold[$bucket] = @{ Url = $url; Count = 1; Saved = $saved }
    Log "buffer 0 on $bucket for partition warm"
    $true
}

function Release-Buffer($bucket) {
    $h = $bufHold[$bucket]; if (-not $h) { return }
    $h.Count--
    if ($h.Count -le 0) {
        $bufHold.Remove($bucket)
        if (Set-Buffer $h.Url $h.Saved) { Log "buffer $($h.Saved / 1MB)M restored on $bucket" }
    }
}

$holds = @{}   # path -> @{ Stream; Since }

function Hold-File($path) {
    if ($holds.ContainsKey($path)) { return }
    try {
        # rclone only ties a handle to its cache item on the first read, so read the (already cached) header
        $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
        [void]$fs.Read((New-Object byte[] 4096), 0, 4096)
        $holds[$path] = @{ Stream = $fs; Since = Get-Date }
        Log "holding open $path"
    } catch { Log "hold failed for ${path}: $($_.Exception.Message)" }
}

function Release-Holds($except, $why) {
    foreach ($k in @($holds.Keys)) {
        if ($k -eq $except) { continue }
        try { $holds[$k].Stream.Dispose() } catch { }
        $holds.Remove($k)
        Log "released $k ($why)"
    }
}

function Start-Warm($path, $stage) {
    $warmArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$PSScriptRoot\rclone-prewarm.ps1", '-Path', "`"$path`"")
    if ($stage -eq 1) { $warmArgs += @('-HeadMB', '512') }                              # first 512 MB
    else              { $warmArgs += @('-Mxf', '-MxfStreams', '8', '-MxfKB', '256') }   # MXF partitions
    $bucket = $path.Substring($mountRoot.Length + 1).Split('\')[0]
    Hold-File $path
    $held = ($stage -eq 2) -and (Hold-Buffer $bucket)
    Log "stage $stage warming $path"
    $p = Start-Process -FilePath powershell.exe -WindowStyle Hidden -PassThru -ArgumentList $warmArgs
    if ($held) { $warmOf[$p.Id] = $bucket }
    $warmPath[$p.Id] = $path
    $p
}

# A previous watcher may have been stopped mid-warm with a buffer left at 0
Get-CimInstance Win32_Process -Filter "Name = 'rclone.exe'" | ForEach-Object {
    if ($_.CommandLine -match '--rc-addr\s+"?([\d.]+:\d+)') {
        $url = "http://$($Matches[1])"
        if ((Get-Buffer $url) -eq 0 -and (Set-Buffer $url $PlayBuffer)) { Log "buffer restored on $url at startup" }
    }
}

# Files already cached when the watcher starts are not warmed again
$known = New-Object System.Collections.Generic.HashSet[string]
foreach ($m in Get-Meta) { [void]$known.Add($m) }
$queue    = New-Object System.Collections.Generic.Queue[object]   # @{ Path; Stage }
$pending2 = @{}                                                   # MXF path -> time stage 1 was queued
$recent   = @{}                                                   # path -> time first seen
$running  = @()
$wasProbing = $false
Log "watching $metaRoot ($($known.Count) files already cached, two-stage, min $MinSizeGB GB, max $MaxWarms at once)"

while ($true) {
    $now = Get-Date
    $current = New-Object System.Collections.Generic.HashSet[string]
    foreach ($m in Get-Meta) {
        [void]$current.Add($m)
        if ($known.Contains($m)) { continue }
        # vfsMeta\S3BUCKETS\<bucket>\<path> -> D:\IrisAnywhere\<bucket>\<path>
        $path = Join-Path $mountRoot $m.Substring($metaRoot.Length + 1)
        $ext  = [IO.Path]::GetExtension($path).ToLower()
        if ($SkipExt -contains $ext) { continue }
        $size = (Get-Item -LiteralPath $path -ErrorAction SilentlyContinue).Length
        if ($size -lt $MinSizeGB * 1GB -and $AlwaysExt -notcontains $ext) { continue }
        $isMxf = $ext -eq '.mxf'
        if ($holds.ContainsKey($path) -or $pending2.ContainsKey($path) -or ($warmPath.Values -contains $path)) {
            continue   # already held or being warmed: rclone just re-listed it
        }
        if ($isMxf -and $recent.ContainsKey($path) -and ($now - $recent[$path]).TotalSeconds -lt $RecentSec) {
            # Reopened (Iris after OK) after the cache dropped it: partitions now
            Log ("reopen of {0}, queued stage 2" -f $path)
            $pending2.Remove($path)
            $queue.Enqueue(@{ Path = $path; Stage = 2 })
        } else {
            $recent[$path] = $now
            if ($isMxf -or ($size -ge $MinSizeGB * 1GB -and $AlwaysExt -notcontains $ext)) { Release-Holds $path 'next file opened' }
            Hold-File $path
            if ($isMxf) {
                Log ("first open of {0} ({1:N2} GB), stage 2 pending" -f $path, ($size / 1GB))
                $pending2[$path] = @{ Queued = $now; Seen = $false }
            } else {
                Log ("first open of {0} ({1:N2} GB), queued stage 1" -f $path, ($size / 1GB))
                $queue.Enqueue(@{ Path = $path; Stage = 1 })
            }
        }
    }
    # Entries rclone evicted drop out, so the next open is seen again
    $known = $current

    # Stage 2 $ProbeHeadSec after the media probe (mediainfo.exe) starts, or when it exits if sooner;
    # if none shows up within $ProbeStartSec, start anyway
    $probing = [bool](Get-Process -Name mediainfo -ErrorAction SilentlyContinue)
    if ($probing -ne $wasProbing) { Log ("mediainfo {0}" -f $(if ($probing) { 'started' } else { 'exited' })); $wasProbing = $probing }
    if ($pending2.Count -gt 0) {
        foreach ($p in @($pending2.Keys)) {
            $e = $pending2[$p]; if ($probing -and -not $e.Seen) { $e.Seen = $true; $e.SeenAt = $now }
            $age = ($now - $e.Queued).TotalSeconds
            if (($e.Seen -and (-not $probing -or ($now - $e.SeenAt).TotalSeconds -ge $ProbeHeadSec)) -or
                (-not $e.Seen -and $age -ge $ProbeStartSec) -or $age -ge $ProbeWaitSec) {
                Log ("queued stage 2 for {0} ({1:N1}s after first open, mediainfo {2})" -f $p, $age, $(if ($e.Seen) { 'seen' } else { 'not seen' }))
                $pending2.Remove($p)
                $queue.Enqueue(@{ Path = $p; Stage = 2 })
            }
        }
    }
    foreach ($p in @($holds.Keys)) {
        if (($now - $holds[$p].Since).TotalSeconds -ge $HoldMaxSec) { try { $holds[$p].Stream.Dispose() } catch { }; $holds.Remove($p); Log "released $p (after $HoldMaxSec s)" }
    }
    foreach ($p in @($recent.Keys)) { if (($now - $recent[$p]).TotalSeconds -ge $RecentSec) { $recent.Remove($p) } }

    foreach ($p in @($running | Where-Object { $_.HasExited })) {
        if ($warmOf.ContainsKey($p.Id)) { Release-Buffer $warmOf[$p.Id]; $warmOf.Remove($p.Id) }
        $warmPath.Remove($p.Id)
    }
    $running = @($running | Where-Object { -not $_.HasExited })
    while ($queue.Count -gt 0 -and $running.Count -lt $MaxWarms) {
        $w = $queue.Dequeue()
        $running += Start-Warm $w.Path $w.Stage
    }
    Start-Sleep -Milliseconds 200
}
