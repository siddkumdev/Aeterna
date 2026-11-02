# Run the game in desktop mode with the Galaxy Watch as the hand (see watch/README.md). Start the bridge first:
#   python watch/watch_bridge.py live
# Usage:  powershell -File godot\run_watch.ps1
# Paths come from local.env at the repo root (GODOT_EXE).
$project = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path (Split-Path -Parent $project) 'local.env'
$cfg = @{}
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        $t = $line.Trim()
        if ($t -and -not $t.StartsWith('#') -and $t.Contains('=')) {
            $k, $v = $t.Split('=', 2)
            $cfg[$k.Trim()] = $v.Trim().Trim('"')
        }
    }
}
$godot = $cfg['GODOT_EXE']
if (-not $godot -or -not (Test-Path $godot)) { Write-Error "GODOT_EXE missing or wrong in $envFile (run: python tools/doctor.py)"; exit 1 }
$env:AETERNA_WATCH = '1'
& $godot --path $project --xr-mode off
