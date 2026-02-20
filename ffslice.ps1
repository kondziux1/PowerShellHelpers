<#
.SYNOPSIS
    FFmpeg Slicer script (ffslice).

.DESCRIPTION
    Divides media files based on a duration timestamp with smart-tail handling.

    FLAGS:
    -k : Keep Remainder (Merges the final "leftover" seconds into the last chunk).
    -q : Full Quiet (Silences script output entirely).
    -v : FFmpeg Verbose (Shows full technical output from FFmpeg).

.PARAMETER InputFile
    The path to the source video or audio file.

.PARAMETER OutputPattern
    The naming convention for output files (e.g., "part_{0:D2}.mp4").

.PARAMETER SplitTime
    The duration for each segment (Format: "HH:mm:ss" or "mm:ss").

.PARAMETER Flags
    Shorthand configuration flags (e.g., "-kq", "-kv", "-q").

.EXAMPLE
    .\ffslice.ps1 "movie.mkv" "chunk_{0:D3}.mkv" "20:00" -kq
    Slices the movie into 20-minute chunks, merges the remainder, and stays quiet.
#>

param (
    [Parameter(Mandatory=$false, Position=0)]
    [string]$InputFile,

    [Parameter(Mandatory=$false, Position=1)]
    [string]$OutputPattern,

    [Parameter(Mandatory=$false, Position=2)]
    [string]$SplitTime,

    # We use ValueFromRemainingArguments so you can type -kq without it breaking
    [Parameter(Mandatory=$false, Position=3, ValueFromRemainingArguments=$true)]
    [string[]]$FlagInput = ""
)

# silly
$SuccessMessages = @(
    "Don't forget where you saved them :3",
    "We sliced them good!",
    "FFmybeloved",
    "You want that to go?",
    "Snip snip!",
    "Look at you, a digital butcher.",
    "I hope you're happy with what you've done.",
    "Chef's kiss! Perfect slices.",
	"Tis but a scratch!",
	"I came here to kick ass and slice!",
    "The bitrate was high, but my spirit was higher."
)
$ErrorActionPreference = "Stop"
$StartTimeStamp = Get-Date

# --- 1. Flag Handling ---
$CleanFlags = ($FlagInput -join "").ToLower()
if ($CleanFlags.Contains("-h") -or $CleanFlags.Contains("--help")) {
    Write-Host "`n[ HELP MENU - FFSLICE ]" -ForegroundColor White
    Write-Host "Usage: ffslice input output time -flags"
    Write-Host "`nFlags:"
    Write-Host "  k : Keep Remainder (Merges last bit into last chunk)"
    Write-Host "  q : Full Quiet (Silences all script output)"
    Write-Host "  v : FFmpeg Verbose (Shows raw FFmpeg logs)"
    Write-Host "  h : Show this help menu"
    Write-Host "`nExample:"
    Write-Host "  ffslice video.mp4 chunk_{0}.mp4 20:00 -kq"
    exit
}
$CleanFlags = ($FlagInput -join "").Replace("-", "").ToLower()
$KeepRemainder = $CleanFlags.Contains("k")
$ScriptQuiet   = $CleanFlags.Contains("q")
$FFmpegVerbose = $CleanFlags.Contains("v")

$ffmpegQuiet = if ($FFmpegVerbose) { "" } else { "-hide_banner -loglevel error" }

function Write-Status ($Message, $Color = "Cyan") {
    if (-not $ScriptQuiet) { Write-Host $Message -ForegroundColor $Color }
}

# --- 2. Precision Calculations ---
try {
    $norm = if ($SplitTime.Split(':').Count -eq 2) { "00:$SplitTime" } else { $SplitTime }
    $ts = [timespan]::Parse($norm)
    $segmentSec = $ts.TotalSeconds

    $durationRaw = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $InputFile
    $totalSec = [double]$durationRaw
} catch {
    Write-Error "Calculations failed. Check your file or time format, ye silly!"
    exit
}

# Calculate how many full chunks fit
$fullChunks = [math]::Floor($totalSec / $segmentSec)
$hasRemainder = ($totalSec % $segmentSec) -gt 0.1 # Tolerance for tiny leftovers

# Determine Loop Count
# If we keep remainder, we do (FullChunks - 1) normal cuts, then 1 "long" cut at the end.
# If we don't, we just do Ceiling (every piece gets its own file).
if ($KeepRemainder -and $hasRemainder -and $fullChunks -gt 0) {
    $loopLimit = $fullChunks
    $mergeLast = $true
} else {
    $loopLimit = [math]::Ceiling($totalSec / $segmentSec)
    $mergeLast = $false
}

# --- 3. Pathing ---
$FullOutputPath = [System.IO.Path]::GetFullPath($OutputPattern)
$OutputDir = Split-Path $FullOutputPath -Parent
$EncodedPath = [uri]::EscapeUriString("file:///$($OutputDir.Replace('\', '/'))")

# --- 4. Processing ---
Write-Status "`n[ STARTING ENGINE ]" -Color White
Write-Status "--------------------------------------------------"
Write-Status "File:        $(Split-Path $InputFile -Leaf)"
Write-Status "Duration:    $totalSec sec"
Write-Status "Slice:       $segmentSec sec"
Write-Status "Flags:       KeepRemainder:$KeepRemainder | Quiet:$ScriptQuiet"
Write-Status "--------------------------------------------------`n"

for ($i = 0; $i -lt $loopLimit; $i++) {
    $currentStart = $i * $segmentSec
    $currentOutput = $OutputPattern -f ($i + 1)
    
    # Logic: If this is the LAST loop iteration AND mergeLast is true, don't use -t (duration)
    if ($mergeLast -and ($i -eq $loopLimit - 1)) {
        Write-Status ">>> [PART $($i + 1)] Merging remainder into: $currentOutput" -Color DarkCyan
        $cmd = "ffmpeg $ffmpegQuiet -ss $currentStart -i `"$InputFile`" -c copy -y `"$currentOutput`""
    } else {
        Write-Status ">>> [PART $($i + 1)] Slicing at $currentStart seconds..." -Color Blue
        $cmd = "ffmpeg $ffmpegQuiet -ss $currentStart -t $segmentSec -i `"$InputFile`" -c copy -y `"$currentOutput`""
    }
    
    Invoke-Expression $cmd
}

# --- 5. Post-Process Summary ---
$EndTimeStamp = Get-Date
$Elapsed = $EndTimeStamp - $StartTimeStamp
$Elapsed.mili

Write-Status "`n[ MISSION COMPLETE ]" -Color Green
Write-Status "Duration:        $($Elapsed.Minutes.ToString('D2')):$($Elapsed.Seconds.ToString('D2')).$($Elapsed.Milliseconds.ToString('D3'))"
Write-Status "Files Created:   $loopLimit"
Write-Status "Directory:       $OutputDir" -Color Gray
Write-Status "Click to Open:   $EncodedPath" -Color White
Write-Status "--------------------------------------------------"
Write-Status ($SuccessMessages | Get-Random) -Color Magenta
