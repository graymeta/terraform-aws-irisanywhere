# Warms files in the local rclone cache when they are opened, in two stages.
# rclone (--vfs-cache-mode full) creates a metadata file under <cache-dir>\vfsMeta\<remote>\<bucket>\
# when a file is first opened. For each new one of at least $MinSizeGB, or any caption/audio/xml file
# (image-sequence frames are skipped):
#   stage 1  non-MXF only, right away: the first 512 MB (front only)
#   stage 2  MXF only, $ProbeHeadSec after mediainfo.exe (the probe behind the Open dialog) starts, or
#            $ProbeGapSec after it exits if sooner, so its reads and the dialog's partition walk right after
#            are mostly done before the warm's queue up (rclone starts new reads in a file about one at a
#            time); with no probe, right away: every MXF partition, which Iris walks one
#            by one when it opens the file after OK.
# An MXF reopened within $RecentSec after the cache dropped it goes straight to stage 2.
# At most $MaxWarms warms run at once.
# --buffer-size is set to $OpenBuffer through the bucket mount's rc port (from its --rc-addr) while a file is being
# opened: every read at a new position would otherwise pull a whole buffer in the background, and the media
# probes, the partition warm and Iris's steps after OK all jump around the file. It goes to 0 at the first
# open of an MXF and back to its previous value when mxfdump (the last step Iris runs after OK) exits, or
# $AfterOkSec after OK (OK: the file's second mediainfo run, an "mediainfo --Inform" run, or mxfdump), or
# $OpenBufferMaxSec after the first open if OK is never seen, so playback never runs on the open buffer. Not
# when the partition warm is done: the Open dialog walks every partition again, and with the buffer back
# each of those reads pulls a whole buffer (22 s instead of ~2 s on a 686-partition file). Other files are
# opened with only a few reads and keep the playback buffer throughout. A stage 2 warm still running keeps it low until it ends.
# The mounts rest at the playback buffer, set by the launch script.
# Iris's Whisper language detection (python main.py, ~half the CPU for minutes after a load) runs at idle
# priority so opens get the CPU first.
# A file to be warmed is held open by this watcher from its first open, so rclone (short --vfs-cache-max-age
# drops closed files) keeps the warm while the Open dialog is up and until Iris plays it. Holds are released
# when the next main file (MXF or >= $MinSizeGB, not a caption/audio/xml sidecar) is opened, or after
# $HoldMaxSec.
$metaRoot  = "D:\rclone-cache\vfsMeta\S3BUCKETS"
$mountRoot = "D:\IrisAnywhere"
$log       = "C:\Logs\rclone-autowarm.log"
$warmLog   = "C:\Logs\rclone-prewarm.log"
$MaxWarms  = 4
$MinSizeGB = 1
$RecentSec = 120
$ProbeWaitSec = 20
$ProbeStartSec = 0
$ProbeHeadSec = 2     # mediainfo still running this long after it started: warm anyway
$ProbeGapSec = 0.5    # otherwise this long after it exits (Iris's dialog walk runs right after)
$HoldMaxSec = 900
$AfterOkSec = 20
$OpenBufferMaxSec = 120   # buffer back regardless this long after the first open (OK not seen)
$PlayBuffer = 64MB   # --buffer-size for playback
$OpenBuffer = 0      # --buffer-size while an MXF is being opened (the mounts rest at $PlayBuffer)
$AlwaysExt = @('.srt', '.scc', '.vtt', '.ttml', '.dfxp', '.xml', '.stl', '.cap', '.sub', '.ass', '.ssa', '.sbv', '.itt', '.mcc',
               '.wav', '.bwf', '.w64', '.aif', '.aiff', '.mp3', '.aac', '.m4a', '.flac', '.ac3', '.ec3', '.eac3', '.dts', '.mp2', '.ogg', '.opus')
$SkipExt   = @('.dpx', '.exr', '.tif', '.tiff', '.png', '.jpg', '.jpeg', '.tga', '.cin', '.j2c', '.j2k', '.jp2', '.ari', '.dng')

function Log($m) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" }
function Log-Warm($m) { Add-Content -Path $warmLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" }

# Warms run on background tasks in this process (compiled once here, no PowerShell start per warm).
# Reads go through the mount and bypass the Windows file cache so they reach rclone (files under 16 MB,
# e.g. caption sidecars, are read normally); a failed read is retried once on a new handle, then skipped
# and counted. MXF: one read from -BeforeKB to +AfterKB at every partition in the Random Index
# Pack, end to start (the order Iris walks them); Iris's Open dialog reads 32 KB at every other partition
# start and 32 KB from 12.8 KB before the next one. Other files: the first HeadMB in 16 MB reads.
Add-Type -TypeDefinition @'
using System; using System.IO; using System.Threading; using System.Threading.Tasks; using System.Collections.Generic;
public class RcloneWarm {
    const FileOptions NoBuffering = (FileOptions)0x20000000;
    static int ids;
    public int Id; public string Path; public string What = ""; public string Error;
    public long Bytes, Failed, Retried; public string FirstError, FirstRetry;
    public System.Diagnostics.Stopwatch Watch = System.Diagnostics.Stopwatch.StartNew();
    public Task Work;
    public bool HasExited { get { return Work.IsCompleted; } }
    public static RcloneWarm Start(string path, bool mxf, int headMB, int workers, int beforeKB, int afterKB) {
        var w = new RcloneWarm(); w.Id = Interlocked.Increment(ref ids); w.Path = path;
        w.Work = Task.Run(() => {
            try {
                long len = new FileInfo(path).Length;
                var offs = new List<long>(); var lens = new List<int>();
                if (mxf) {
                    // One window per partition (4 KB pages); windows that overlap or touch are merged into one
                    // read (many files pair each body partition with a small index partition a few KB later)
                    var parts = Partitions(path); parts.Sort();
                    long cs = -1, ce = -1;
                    foreach (long p in parts) {
                        long s = Math.Max(0L, p - beforeKB * 1024L) / 4096 * 4096, e = (p + afterKB * 1024L + 4095) / 4096 * 4096;   // the read stops at the end of the file
                        if (s >= len) continue;
                        if (cs >= 0 && s <= ce && e - cs <= 1048576) { ce = Math.Max(ce, e); continue; }
                        if (cs >= 0) { offs.Add(cs); lens.Add((int)(ce - cs)); }
                        cs = s; ce = e;
                    }
                    if (cs >= 0) { offs.Add(cs); lens.Add((int)(ce - cs)); }
                    offs.Reverse(); lens.Reverse();   // end to start, the order Iris walks them
                    w.What = string.Format("{0} MXF partitions in {1} reads, -{2}..+{3} KB", parts.Count, offs.Count, beforeKB, afterKB);
                    if (offs.Count > 0) w.Read(offs.ToArray(), lens.ToArray(), workers, NoBuffering);
                    // Then 32 MB around 1/3, 1/2 and 2/3 of the duration, where Iris decodes frames after OK
                    // (from the index tables the partition warm just cached)
                    var spots = new List<long>();
                    try { foreach (long t in TimeOffsets(path, parts, new[] { 1 / 3.0, 0.5, 2 / 3.0 })) spots.Add(Math.Max(0L, t - 8388608) / 4096 * 4096); } catch { }
                    if (spots.Count > 0) {
                        w.What += string.Format(", {0} frame spots", spots.Count);
                        w.Read(spots.ToArray(), spots.ConvertAll(x => 33554432).ToArray(), spots.Count, NoBuffering);
                    }
                } else {
                    long n = (Math.Min(len, headMB * 1048576L) + 16777215) / 16777216;
                    int size = (int)Math.Min(16777216L, Math.Max(len, 4096L));
                    for (long i = 0; i < n; i++) { offs.Add(i * 16777216); lens.Add(size); }
                    w.What = string.Format("first {0} MB", headMB);
                    w.Read(offs.ToArray(), lens.ToArray(), workers, len < 16777216 ? FileOptions.None : NoBuffering);
                }
            } catch (Exception e) { w.Error = e.GetType().Name + ": " + e.Message; }
            w.Watch.Stop();
        });
        return w;
    }
    void Read(long[] offsets, int[] lengths, int workers, FileOptions opts) {
        long next = -1;
        int max = 0; foreach (int l in lengths) max = Math.Max(max, l);
        Parallel.For(0, workers, new ParallelOptions { MaxDegreeOfParallelism = workers }, k => {
            var buf = new byte[max];
            FileStream fs = null;
            long i;
            while ((i = Interlocked.Increment(ref next)) < offsets.Length) {
                for (int attempt = 0; ; attempt++) {
                    bool opening = fs == null;
                    try {
                        if (fs == null) fs = new FileStream(Path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 4096, opts);
                        opening = false;
                        fs.Seek(offsets[i], SeekOrigin.Begin);
                        // Stop at the end of the file: an unbuffered read continuing after the short last one
                        // is unaligned (ERROR_INVALID_PARAMETER, which .NET reports as "Handle does not support
                        // synchronous operations"); requests stay whole 4 KB pages
                        long left = fs.Length - offsets[i]; int length = lengths[i];
                        int want = (int)Math.Min((long)length, left), ask = (int)Math.Min((long)length, (left + 4095) / 4096 * 4096);
                        int got = 0, r;
                        while (got < want && (r = fs.Read(buf, got, ask - got)) > 0) got += r;
                        Interlocked.Add(ref Bytes, got);
                        break;
                    } catch (Exception e) {
                        if (fs != null) { fs.Dispose(); fs = null; }   // new handle for the retry and the next piece
                        string where = string.Format("{0}: {1} ({2} at {3:N0})", e.GetType().Name, e.Message, opening ? "opening" : "reading", offsets[i]);
                        if (attempt == 0) { Interlocked.Increment(ref Retried); Interlocked.CompareExchange(ref FirstRetry, where, null); continue; }
                        Interlocked.Increment(ref Failed); Interlocked.CompareExchange(ref FirstError, where, null);
                        break;
                    }
                }
            }
            if (fs != null) fs.Dispose();
        });
    }
    // Partition offsets from the MXF Random Index Pack at the end of the file (empty if there is none)
    // File offsets of the frames at the given fractions of the duration: index table segments give each
    // edit unit's offset in the essence stream (or a fixed size per unit), and each body partition's
    // BodyOffset maps the stream to the file
    static long BE(byte[] b, int o, int n) { long v = 0; for (int i = 0; i < n; i++) v = (v << 8) | b[o + i]; return v; }
    static long Ber(byte[] b, ref int p) { if ((b[p] & 0x80) == 0) return b[p++]; int n = b[p++] & 0x7f; long v = BE(b, p, n); p += n; return v; }
    static bool Is(byte[] b, int o, params int[] k) { if (b.Length < o + 16) return false; for (int i = 0; i < k.Length; i++) if (k[i] >= 0 && b[o + i] != k[i]) return false; return true; }
    static bool IsFill(byte[] b, int o) { return Is(b, o, 6, 14, 43, 52, 1, 1, 1, -1, 3, 1, 2, 16, 1); }
    static byte[] At(FileStream fs, long off, int n) { var b = new byte[n]; fs.Seek(off, SeekOrigin.Begin); int got = 0, r; while (got < n && (r = fs.Read(b, got, n - got)) > 0) got += r; if (got < n) Array.Resize(ref b, got); return b; }
    static List<long> TimeOffsets(string path, List<long> parts, double[] fracs) {
        var body = new List<long[]>(); var segs = new List<long[]>(); var arrs = new List<long[]>();
        using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 65536)) {
            foreach (long p in parts) {
                var h = At(fs, p, 128); if (!Is(h, 0, 6, 14, 43, 52, 2, 5, 1, 1, 13, 1, 2, 1, 1)) continue;
                int q = 16; long plen = Ber(h, ref q);
                long hbc = BE(h, q + 32, 8), ibc = BE(h, q + 40, 8), bodyOff = BE(h, q + 52, 8), bodySid = BE(h, q + 60, 4), cur = p + q + plen;
                if (hbc == 0) { var c = At(fs, cur, 32); if (IsFill(c, 0)) { int k = 16; long fl = Ber(c, ref k); cur += k + fl; } }
                cur += hbc;
                if (ibc > 0 && ibc < 64 << 20) {
                    var ix = At(fs, cur, (int)ibc); int o = 0;
                    while (o + 17 <= ix.Length) {
                        bool idx = Is(ix, o, 6, 14, 43, 52, 2, 83, 1, 1, 13, 1, 2, 1, 1, 16, 1, 0); int k = o + 16; long vl = Ber(ix, ref k); int end = (int)Math.Min(ix.Length, k + vl);
                        if (idx) {
                            long start = 0, dur = 0, eubc = 0; long[] so = null;
                            for (int v = k; v + 4 <= end; ) { int tag = (int)BE(ix, v, 2), tl = (int)BE(ix, v + 2, 2), d = v + 4;
                                if (tag == 0x3F0C) start = BE(ix, d, 8); else if (tag == 0x3F0D) dur = BE(ix, d, 8); else if (tag == 0x3F05) eubc = BE(ix, d, 4);
                                else if (tag == 0x3F0A) { int n = (int)BE(ix, d, 4), il = (int)BE(ix, d + 4, 4); so = new long[n]; for (int e = 0; e < n; e++) so[e] = BE(ix, d + 8 + e * il + 3, 8); }
                                v = d + tl; }
                            segs.Add(new[] { start, dur, eubc }); arrs.Add(so);
                        }
                        o = end;
                    }
                    cur += ibc;
                }
                if (bodySid != 0) { var e2 = At(fs, cur, 32); if (IsFill(e2, 0)) { int k = 16; long fl = Ber(e2, ref k); cur += k + fl; } body.Add(new[] { bodyOff, cur }); }
            }
        }
        body.Sort((a, b) => a[0].CompareTo(b[0]));
        long total = 0, eu = 0; foreach (var g in segs) { total = Math.Max(total, g[0] + g[1]); if (g[2] > 0) eu = g[2]; }
        var res = new List<long>();
        foreach (double f in fracs) {
            long fr = (long)(total * f), so = -1;
            if (eu > 0) so = fr * eu;
            else for (int i = 0; i < segs.Count; i++) { var a = arrs[i]; if (a != null && fr >= segs[i][0] && fr - segs[i][0] < a.Length) { so = a[fr - segs[i][0]]; break; } }
            long file = -1; if (so >= 0) foreach (var b in body) if (b[0] <= so) file = b[1] + (so - b[0]);
            if (file > 0 && !res.Contains(file)) res.Add(file);
        }
        return res;
    }
    static List<long> Partitions(string path) {
        var parts = new List<long>();
        using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
            var b = new byte[4]; fs.Seek(-4, SeekOrigin.End); fs.Read(b, 0, 4);
            long ripLen = ((long)b[0] << 24) | ((long)b[1] << 16) | ((long)b[2] << 8) | b[3];
            if (ripLen < 21 || ripLen > 16777216 || ripLen > fs.Length) return parts;
            var rip = new byte[ripLen]; fs.Seek(-ripLen, SeekOrigin.End);
            int got = 0, r; while (got < ripLen && (r = fs.Read(rip, got, (int)ripLen - got)) > 0) got += r;
            if (rip[0] != 0x06 || rip[1] != 0x0E || rip[2] != 0x2B || rip[3] != 0x34 || rip[13] != 0x11) return parts;
            int pos = 16; pos += (rip[pos] & 0x80) != 0 ? 1 + (rip[pos] & 0x7F) : 1;   // BER length
            while (pos + 12 <= ripLen - 4) {
                long off = 0; for (int k = 4; k < 12; k++) off = (off << 8) | rip[pos + k];   // skip 4-byte BodySID
                parts.Add(off); pos += 12;
            }
        }
        return parts;
    }
}
'@

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

function Hold-Buffer($bucket, $why) {
    if ($bufHold.ContainsKey($bucket)) { $bufHold[$bucket].Count++; return $true }
    $url = Get-RcUrl $bucket
    if (-not $url) { return $false }
    $saved = Get-Buffer $url; if ($saved -le $OpenBuffer) { $saved = $PlayBuffer }
    if (-not (Set-Buffer $url $OpenBuffer)) { return $false }
    $bufHold[$bucket] = @{ Url = $url; Count = 1; Saved = $saved }
    Log "buffer $($OpenBuffer / 1MB)M on $bucket ($why)"
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
$session = $null   # the main file being opened: @{ Path; Leaf; Bucket; Mxf; Held; Since; OkAt; DumpSeen; Probes }

function End-Session($why) {
    if ($script:session -and $script:session.Held) {
        $script:session.Held = $false
        Log "open of $($script:session.Leaf) done ($why)"
        Release-Buffer $script:session.Bucket
    }
}

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
    $bucket = $path.Substring($mountRoot.Length + 1).Split('\')[0]
    Hold-File $path
    $held = ($stage -eq 2) -and (Hold-Buffer $bucket 'partition warm')
    Log "stage $stage warming $path"
    Log-Warm "Start  $path"
    if ($stage -eq 1) { $p = [RcloneWarm]::Start($path, $false, 512, 16, 0, 0) }   # first 512 MB
    else              { $p = [RcloneWarm]::Start($path, $true, 0, 32, 16, 32) }     # MXF partitions, -16..+32 KB, 32 at once
    if ($held) { $warmOf[$p.Id] = $bucket }
    $warmPath[$p.Id] = $path
    $p
}

# Files already cached when the watcher starts are not warmed again
$known = New-Object System.Collections.Generic.HashSet[string]
foreach ($m in Get-Meta) { [void]$known.Add($m) }
$queue    = New-Object System.Collections.Generic.Queue[object]   # @{ Path; Stage }
$pending2 = @{}                                                   # MXF path -> time stage 1 was queued
$recent   = @{}                                                   # path -> time first seen
$running  = @()
$wasProbing = $false
$wasProbingSession = $false
$tick = 0
$lowered = New-Object System.Collections.Generic.HashSet[int]
# Wake as soon as rclone creates a cache entry (an open) instead of only every 200 ms
$fsw = $null
try { if (Test-Path $metaRoot) { $fsw = New-Object IO.FileSystemWatcher $metaRoot; $fsw.IncludeSubdirectories = $true } } catch { $fsw = $null }
Log "watching $metaRoot ($($known.Count) files already cached, two-stage, min $MinSizeGB GB, max $MaxWarms at once)"

# A watcher killed mid-open (no finally) leaves a mount at the open buffer: back to the playback buffer
foreach ($c in Get-CimInstance Win32_Process -Filter "Name = 'rclone.exe'") {
    if ($c.CommandLine -match '--rc-addr\s+"?([\d.]+:\d+)') {
        $u = "http://$($Matches[1])"
        if ((Get-Buffer $u) -eq $OpenBuffer -and (Set-Buffer $u $PlayBuffer)) { Log "buffer $($PlayBuffer / 1MB)M reset on $u (left at $($OpenBuffer / 1MB)M)" }
    }
}
# An error in one pass is logged and the loop carries on; on any exit the script controls, lowered buffers
# go back and held files are closed
try {
while ($true) {
    try {
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
                if ($isMxf -or ($size -ge $MinSizeGB * 1GB -and $AlwaysExt -notcontains $ext)) {
                    Release-Holds $path 'next file opened'
                    End-Session 'next file opened'
                }
                # Only MXF opens jump around the file (hundreds of partition reads); other files keep the full buffer
                if ($isMxf) {
                    $bucket = $path.Substring($mountRoot.Length + 1).Split('\')[0]
                    if (Hold-Buffer $bucket 'file opened') {
                        $session = @{ Path = $path; Leaf = [IO.Path]::GetFileName($path); Bucket = $bucket; Mxf = $isMxf; Held = $true; Since = $now; OkAt = $null; DumpSeen = $false; Probes = [int]$probing }
                    }
                }
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

        # Stage 2 $ProbeHeadSec after the media probe (mediainfo.exe) starts, or $ProbeGapSec after it exits if sooner;
        # if none shows up within $ProbeStartSec, start anyway
        $probing = [bool](Get-Process -Name mediainfo -ErrorAction SilentlyContinue)
        if ($probing -ne $wasProbing) { Log ("mediainfo {0}" -f $(if ($probing) { 'started' } else { 'exited' })); $wasProbing = $probing }
        if ($pending2.Count -gt 0) {
            foreach ($p in @($pending2.Keys)) {
                $e = $pending2[$p]; if ($probing -and -not $e.Seen) { $e.Seen = $true; $e.SeenAt = $now }
                if ($e.Seen -and -not $probing -and -not $e.ExitedAt) { $e.ExitedAt = $now }
                $age = ($now - $e.Queued).TotalSeconds
                if (($e.Seen -and (($e.ExitedAt -and ($now - $e.ExitedAt).TotalSeconds -ge $ProbeGapSec) -or ($now - $e.SeenAt).TotalSeconds -ge $ProbeHeadSec)) -or
                    (-not $e.Seen -and $age -ge $ProbeStartSec) -or $age -ge $ProbeWaitSec) {
                    Log ("queued stage 2 for {0} ({1:N1}s after first open, mediainfo {2})" -f $p, $age, $(if ($e.Seen) { 'seen' } else { 'not seen' }))
                    $pending2.Remove($p)
                    $queue.Enqueue(@{ Path = $p; Stage = 2 })
                }
            }
        }
        # Buffer back just before playback: OK is Iris's first "mediainfo --Inform" run on the file; for MXF
        # wait for mxfdump, the last step Iris runs after OK
        if ($session -and $session.Held) {
            # Each new mediainfo run while the file is open; the dialog's probe is the first
            if ($probing -and -not $wasProbingSession) { $session.Probes++ }
            if (-not $session.OkAt -and $session.Probes -ge 2) { $session.OkAt = $now; Log "OK clicked for $($session.Leaf) (second mediainfo run)" }
            if (-not $session.OkAt -and $probing) {
                foreach ($c in Get-CimInstance Win32_Process -Filter "Name = 'mediainfo.exe'") {
                    if ($c.CommandLine -match '--Inform' -and $c.CommandLine.ToLower().Contains($session.Leaf.ToLower())) {
                        $session.OkAt = $now; Log "OK clicked for $($session.Leaf)"; break
                    }
                }
            }
            if ($session.Held -and $session.OkAt -and -not $session.Mxf) { End-Session 'OK clicked' }
            $dumping = $session.Held -and [bool](Get-Process -Name mxfdump -ErrorAction SilentlyContinue)
            if ($dumping -and -not $session.OkAt) { $session.OkAt = $now; Log "OK clicked for $($session.Leaf) (mxfdump)" }
            if ($session.Held -and $session.OkAt) {
                if ($dumping) { $session.DumpSeen = $true }
                elseif ($session.DumpSeen) { End-Session 'mxfdump done' }
                elseif (($now - $session.OkAt).TotalSeconds -ge $AfterOkSec) { End-Session "$AfterOkSec s after OK" }
            }
            if ($session.Held -and ($now - $session.Since).TotalSeconds -ge $OpenBufferMaxSec) { End-Session "after $OpenBufferMaxSec s" }
        }
        $wasProbingSession = $probing
        foreach ($p in @($holds.Keys)) {
            if (($now - $holds[$p].Since).TotalSeconds -ge $HoldMaxSec) { try { $holds[$p].Stream.Dispose() } catch { }; $holds.Remove($p); Log "released $p (after $HoldMaxSec s)" }
        }
        foreach ($p in @($recent.Keys)) { if (($now - $recent[$p]).TotalSeconds -ge $RecentSec) { $recent.Remove($p) } }

        foreach ($p in @($running | Where-Object { $_.HasExited })) {
            $name = [IO.Path]::GetFileName($p.Path)
            if ($p.Error) { Log-Warm "Failed $name ($($p.What)): $($p.Error)" }
            else {
                $failed = if ($p.Retried) { "  ($($p.Retried) reads retried, first: $($p.FirstRetry))" } else { '' }
            if ($p.Failed) { $failed += "  ($($p.Failed) reads failed, first: $($p.FirstError))" }
                Log-Warm ("Done   {0}  {1:N0} MB in {2:N1}s  ({3}){4}" -f $name, ($p.Bytes / 1MB), $p.Watch.Elapsed.TotalSeconds, $p.What, $failed)
            }
            if ($warmOf.ContainsKey($p.Id)) { Release-Buffer $warmOf[$p.Id]; $warmOf.Remove($p.Id) }
            $warmPath.Remove($p.Id)
        }
        $running = @($running | Where-Object { -not $_.HasExited })
        while ($queue.Count -gt 0 -and $running.Count -lt $MaxWarms) {
            $w = $queue.Dequeue()
            $running += Start-Warm $w.Path $w.Stage
        }
        if (($tick = $tick + 1) % 5 -eq 0) {
            foreach ($p in Get-Process -Name python -ErrorAction SilentlyContinue) {
                if ($lowered.Contains($p.Id)) { continue }
                [void]$lowered.Add($p.Id)
                $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId = $($p.Id)").CommandLine
                if ($cmd -match 'main\.py') { try { $p.PriorityClass = 'Idle'; Log "whisper python $($p.Id) set to idle priority" } catch { } }
            }
        }
    } catch {
        Log "error: $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
        Start-Sleep -Seconds 1
    }
    if ($fsw) { [void]$fsw.WaitForChanged([IO.WatcherChangeTypes]::Created, 200) } else { Start-Sleep -Milliseconds 200 }
}
} finally {
    foreach ($b in @($bufHold.Keys)) { if (Set-Buffer $bufHold[$b].Url $bufHold[$b].Saved) { Log "buffer $($bufHold[$b].Saved / 1MB)M restored on $b (watcher exiting)" } }
    Release-Holds $null 'watcher exiting'
}
