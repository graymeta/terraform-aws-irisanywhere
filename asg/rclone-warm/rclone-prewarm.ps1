# Warms part of a file on an rclone mount into the rclone VFS cache by reading it through the mount.
#   -HeadMB  the first N MB, -Streams 16 MB reads at a time
#   -Mxf     -MxfBeforeKB before to -MxfKB after every partition in the MXF Random Index Pack, -MxfStreams
#            at a time, end to start
#            (the order Iris walks them when it opens the file)
# Reads bypass the Windows file cache so they reach rclone. A read that fails is skipped; the count and
# the first error are logged. Logs to C:\Logs\rclone-prewarm.log.
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$HeadMB = 0,
    [int]$Streams = 16,
    [switch]$Mxf,
    [int]$MxfKB = 48,
    [int]$MxfBeforeKB = 16,
    [int]$MxfStreams = 8
)
$log = 'C:\Logs\rclone-prewarm.log'
function Log($m) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" }

Add-Type -TypeDefinition @'
using System; using System.IO; using System.Threading; using System.Threading.Tasks;
public static class RclonePrewarm {
    const FileOptions NoBuffering = (FileOptions)0x20000000;
    public static long Failed;
    public static string FirstError;
    static void Fail(Exception e) {
        Interlocked.Increment(ref Failed);
        Interlocked.CompareExchange(ref FirstError, e.GetType().Name + ": " + e.Message, null);
    }
    public static long Read(string path, int workers, long[] offsets, int length) {
        long next = -1, done = 0;
        Parallel.For(0, workers, new ParallelOptions { MaxDegreeOfParallelism = workers }, w => {
            var buf = new byte[length];
            FileStream fs = null;
            long i;
            while ((i = Interlocked.Increment(ref next)) < offsets.Length) {
                try {
                    if (fs == null) fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 4096, NoBuffering);
                    fs.Seek(offsets[i], SeekOrigin.Begin);
                    int got = 0, n;
                    while (got < length && (n = fs.Read(buf, got, length - got)) > 0) got += n;
                    Interlocked.Add(ref done, got);
                } catch (Exception e) {
                    Fail(e);
                    if (fs != null) { fs.Dispose(); fs = null; }   // reopen for the next piece
                }
            }
            if (fs != null) fs.Dispose();
        });
        return done;
    }
}
'@

# Partition offsets from the MXF Random Index Pack at the end of the file (empty if there is none)
function Get-MxfPartitions([string]$file) {
    $fs = [IO.File]::Open($file, 'Open', 'Read', 'ReadWrite')
    try {
        $b = New-Object byte[] 4
        $fs.Seek(-4, 'End') | Out-Null; $fs.Read($b, 0, 4) | Out-Null
        $ripLen = ([long]$b[0] -shl 24) -bor ([long]$b[1] -shl 16) -bor ([long]$b[2] -shl 8) -bor [long]$b[3]
        if ($ripLen -lt 21 -or $ripLen -gt 16MB -or $ripLen -gt $fs.Length) { return @() }
        $rip = New-Object byte[] $ripLen
        $fs.Seek(-$ripLen, 'End') | Out-Null; $fs.Read($rip, 0, $ripLen) | Out-Null
        if ($rip[0] -ne 0x06 -or $rip[1] -ne 0x0E -or $rip[2] -ne 0x2B -or $rip[3] -ne 0x34 -or $rip[13] -ne 0x11) { return @() }
        $pos = 16
        if ($rip[$pos] -band 0x80) { $pos += 1 + ($rip[$pos] -band 0x7F) } else { $pos += 1 }   # BER length
        $parts = New-Object System.Collections.Generic.List[long]
        while ($pos + 12 -le $ripLen - 4) {
            $off = 0L
            for ($k = 4; $k -lt 12; $k++) { $off = ($off -shl 8) -bor [long]$rip[$pos + $k] }   # skip 4-byte BodySID
            $parts.Add($off); $pos += 12
        }
        return $parts.ToArray()
    } finally { $fs.Close() }
}

$f = Get-Item -LiteralPath $Path
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
    $got = 0L
    if ($Mxf) {
        $parts = @(Get-MxfPartitions $f.FullName)
        # One read at each partition from -MxfBeforeKB (Iris's Open dialog reads 32 KB starting 12.5 KB before
        # every other partition), 4 KB aligned for the unbuffered reads
        $offs = [long[]]@($parts | Sort-Object -Descending | ForEach-Object { [long][math]::Floor([math]::Max([long]0, [long]$_ - $MxfBeforeKB * 1KB) / 4KB) * 4KB } | Where-Object { $_ -lt $f.Length })
        Log ("Start  {0}  ({1:N1} GB, {2} MXF partitions x -{3}..+{4} KB)" -f $f.FullName, ($f.Length / 1GB), $offs.Count, $MxfBeforeKB, $MxfKB)
        if ($offs.Count -gt 0) { $got += [RclonePrewarm]::Read($f.FullName, $MxfStreams, $offs, ($MxfBeforeKB + $MxfKB) * 1KB) }
    }
    if ($HeadMB -gt 0) {
        $n = [long][math]::Ceiling([math]::Min([long]$f.Length, [long]$HeadMB * 1MB) / 16MB)
        $offs = [long[]]@(for ($i = 0L; $i -lt $n; $i++) { $i * 16MB })
        Log ("Start  {0}  ({1:N1} GB, first {2} MB)" -f $f.FullName, ($f.Length / 1GB), $HeadMB)
        $got += [RclonePrewarm]::Read($f.FullName, $Streams, $offs, 16MB)
    }
    $failed = if ([RclonePrewarm]::Failed) { "  ({0} reads failed, first: {1})" -f [RclonePrewarm]::Failed, [RclonePrewarm]::FirstError } else { '' }
    Log ("Done   {0}  {1:N0} MB in {2:N1}s{3}" -f $f.Name, ($got / 1MB), $sw.Elapsed.TotalSeconds, $failed)
} catch {
    Log ("Failed {0}: {1}" -f $f.Name, $_.Exception.Message)
}
