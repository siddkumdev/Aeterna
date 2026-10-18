# Run the Godot project against the Meta XR Simulator for THIS process only (no registry changes).
# Usage:  powershell -File godot\run_sim.ps1            (runs the project; close the window to quit)
#         powershell -File godot\run_sim.ps1 -Report    (logs XR info after 3 s and quits)
# Paths come from local.env at the repo root (GODOT_EXE, META_XR_SIM_JSON); see local.env.example.
param([switch]$Report)

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
$simJson = $cfg['META_XR_SIM_JSON']
if (-not $simJson) { $simJson = 'C:\Program Files\MetaXRSimulator\v207.1\meta_openxr_simulator.json' }
if (-not $godot -or -not (Test-Path $godot)) { Write-Error "GODOT_EXE missing or wrong in $envFile (run: python tools/doctor.py)"; exit 1 }
if (-not (Test-Path $simJson)) { Write-Error "META_XR_SIM_JSON not found: $simJson (run: python tools/doctor.py)"; exit 1 }
$env:XR_RUNTIME_JSON = $simJson

$args = @('--path', $project, '--xr-mode', 'on')
if ($Report) { $args += @('--', '--quit-after-report') }
& $godot @args
