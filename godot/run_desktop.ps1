# Run the game on the desktop (no headset, no simulator): mouse and keys, OpenXR off.
# Usage:  powershell -File godot\run_desktop.ps1
# Keys: 1 / 2 / 3 pick a tower, left click builds, Esc or right click cancels, Enter or Space starts the
# night, Tab toggles x2 speed, R starts a new run. Debug builds: F5 = x5, F6 = x10. Paths: local.env (GODOT_EXE).
$project = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path (Split-Path -Parent $project) 'local.env'
$godot = $null
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        $t = $line.Trim()
        if ($t.StartsWith('GODOT_EXE=')) { $godot = $t.Split('=', 2)[1].Trim().Trim('"') }
    }
}
if (-not $godot -or -not (Test-Path $godot)) { Write-Error "GODOT_EXE missing or wrong in $envFile (run: python tools/doctor.py)"; exit 1 }
& $godot --path $project --xr-mode off --resolution 1600x900
