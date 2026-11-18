# Meta XR Simulator frame grab for THIS process only (no registry changes). Usage: powershell -File godot\xr_sim_shot.ps1 OUT_PREFIX
param([string]$Out = "xr_sim")
$project = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg = @{}
foreach ($line in Get-Content (Join-Path (Split-Path -Parent $project) 'local.env')) {
    $t = $line.Trim()
    if ($t -and -not $t.StartsWith('#') -and $t.Contains('=')) { $k, $v = $t.Split('=', 2); $cfg[$k.Trim()] = $v.Trim().Trim('"') }
}
$env:XR_RUNTIME_JSON = $cfg['META_XR_SIM_JSON']
$env:AETERNA_EASY_REACH = '1'
& $cfg['GODOT_EXE'] --path $project --xr-mode on -s res://tools/xr_sim_shot.gd -- $Out
