---
name: quest-build
description: Build Aeterna for the Meta Quest 3 and install it on the headset - the export command the user runs, the adb install, how to read the headset log, and the known traps (memory reaper, blocked vendor plugin, hand-edited manifest). Use when asked to build, export, install, or debug the game on the Quest.
---

# quest-build

Full setup (templates, the vendors plugin, the Android build template) is in `docs/QUEST_BUILD.md`. Read that only when the setup itself is broken. This is the routine.

## 1. Before building
1. `python tools/selftest.py` must end with `game_selftest: 0 failure(s)`.
2. Everything committed and pushed.

## 2. Export: the user runs it
Claude Code's shell gets killed by the low-memory reaper during the Gradle step, so hand the user this for their own PowerShell and wait for `[ DONE ] export`:

```powershell
cd C:\Users\sykeriin\Desktop\Projects\Aeterna\godot
& (Select-String -Path ..\local.env -Pattern '^GODOT_EXE=(.*)').Matches[0].Groups[1].Value.Trim('"') --headless --xr-mode off --path . --export-debug "Quest 3" ../_work/aeterna_quest.apk
```

## 3. Install (Claude runs it once the user says the export is done and the headset is connected)
```bash
ADB=/c/Users/sykeriin/AppData/Local/Android/Sdk/platform-tools/adb.exe
$ADB devices | tail -3
ls -la _work/aeterna_quest.apk          # check the time is the new build
$ADB install -r _work/aeterna_quest.apk | tail -2
```
- `unauthorized` or no device: the user has to put the headset on and accept the USB prompt. The headset sleeps when taken off, and then adb sees nothing.
- Other APKs the user asked for (for example OVR Metrics Tool, which they download themselves) install the same way, in the same step.

## 4. Reading the headset log (keep it small)
```bash
$ADB logcat -d -t 400 | grep -iE "godot|openxr|passthrough|hand" | tail -40
```
Never dump the whole log. The headset must be awake and worn.

## 5. Known traps
- **Vendor plugin blocked.** Windows Application Control blocks `libgodotopenxrvendors.dll`, so the export plugin cannot add Meta's manifest entries. They are hand-written in `godot/android/build/src/main/AndroidManifest.xml` (git-ignored): hand tracking feature and permission, `com.oculus.feature.PASSTHROUGH`, supported devices, the VR category. If the build template is reinstalled, these must be re-added. Do not touch the Windows block unless the user asks.
- **Passthrough** needs `xr/openxr/extensions/meta/passthrough` in `project.godot`, the manifest feature, and `start_passthrough()` in `haze_dome.gd`. Symptom when it fails: a black room.
- **Hands show only an ember orb** when the tracker has no data: controllers are in hand, hand tracking is off in the Quest settings, or the tracker name is wrong. Check the log before changing code.
- **What is on the headset** is whatever was last installed, not what is in git. Record the installed build in `docs/STATUS.md`.
