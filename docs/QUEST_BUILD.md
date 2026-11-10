# Building Aeterna for the Meta Quest 3

Set up on 2026-11-10. The first install on a Quest 3 worked (`adb install` Success). Not yet in git, so each machine recreates these:

## One-time setup
1. **Export templates:** Godot 4.7.2 Android templates in `%APPDATA%\Godot\export_templates\4.7.2.stable\`:
   - Files: `android_debug.apk`, `android_release.apk`, `android_source.zip`, plus `version.txt` = `4.7.2.stable`.
   - Source: the official `Godot_v4.7.2-stable_export_templates.tpz` (GitHub godotengine/godot release). Only the Android files are needed.
2. **OpenXR Vendors plugin:** GodotVR/godot_openxr_vendors `5.1.0-stable`, asset `godotopenxrvendorsaddon.zip`. Copy its `addons/godotopenxrvendors` to `godot/addons/` (git-ignored).
3. **Android build template:**
   - Unzip `android_source.zip` into `godot/android/build/` (git-ignored).
   - Write `godot/android/.build_version` = `4.7.2.stable`.
   - Add an empty `godot/android/build/.gdignore`.
4. **Quest manifest entries:** Windows Application Control on Siddharth's laptop blocks the plugin's editor DLL, so the plugin can't add them. Add these by hand to `godot/android/build/src/main/AndroidManifest.xml`.

   Before `<application>`:
   ```xml
   <uses-feature android:name="oculus.software.handtracking" android:required="true" />
   <uses-permission android:name="com.oculus.permission.HAND_TRACKING" />
   ```
   Inside `<application>`:
   ```xml
   <meta-data android:name="com.oculus.supportedDevices" android:value="quest3|quest3s" />
   ```
5. **Editor settings:** `export/android/java_sdk_path` (JDK 17) and `android_sdk_path` in Godot's editor settings.

## Build and install
Run this in your own terminal: Claude Code's background runs get stopped for low memory during the Gradle step.
```powershell
cd godot
& (Select-String -Path ..\local.env -Pattern '^GODOT_EXE=(.*)').Matches[0].Groups[1].Value.Trim('"') --headless --xr-mode off --path . --export-debug "Quest 3" ../_work/aeterna_quest.apk
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r ..\_work\aeterna_quest.apk
```
In the headset: Library → Unknown Sources → Aeterna. The headset must allow USB debugging. Check with `adb devices`, which should say `device`, not `unauthorized`.
