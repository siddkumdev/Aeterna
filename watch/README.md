# Aeterna Watch (test input, not part of the game)

Goal (Siddharth, 2026-11-02): a stand-in for hand tracking while there is no headset. The Galaxy Watch 4 Classic aims with
the wrist and detects pinch and unpinch. This folder holds step 1: a recorder that proves whether a pinch can be seen in
the sensors at all.

The watch sends UDP to the laptop on its network (`WATCH_BRIDGE` in `local.env`), and the laptop hands it to this PC over ssh.

## Build (offline, on a PC with Android Studio)
Use Android Studio's Java and SDK, with Gradle 9.5.1, from this folder:
```
gradle --offline assembleDebug
```
Set `JAVA_HOME` to Android Studio's `jbr` and `ANDROID_HOME` to the SDK first. Output: `build/outputs/apk/debug/aeterna-watch-debug.apk`.
If Gradle says "Unable to establish loopback connection", the temp path is too long: set `TEMP` and `TMP` to a short folder, and `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=<that folder>`.

## Use
Pinch with the hand that wears the watch.
```
python watch/watch_bridge.py pair <ip:pairing_port> <code>
python watch/watch_bridge.py connect <ip:port>
python watch/watch_bridge.py install
python watch/watch_bridge.py record take1
```

## Play (the watch as a stand-in for hand tracking)
Desktop mode only: the Meta XR Simulator cannot take outside input. The watch moves the mouse cursor and a pinch is a left click.
1. Watch on the right wrist, on the same Wi-Fi as the laptop, wireless debugging connected (`connect`, above).
2. `python watch/watch_bridge.py live` (starts a background service on the watch; Ctrl+C stops it, or run `stop`).
3. `powershell -File godot\run_watch.ps1` (the game in desktop mode with `AETERNA_WATCH=1`).
4. Press **K** once to calibrate (it also works however the strap sits): for 6 s start level and slowly raise and lower your forearm, then for 6 s keep it level and sweep it left and right. The forearm axis is saved in the game's user folder and reused next time. Without calibration the forearm is assumed to be the watch's +x.
5. Point your forearm at the middle of the board and press **C** to centre. Pinch to press, hold to grab, open the fingers to let go. **X** lets go if a release was missed.
Tuning: `AETERNA_WATCH_SPAN=50,35` (degrees of wrist turn across the window, sideways and up-down), `AETERNA_WATCH_AXIS=-x` (an explicit axis wins over a saved calibration; `-x`, `y` and `-y` also exist). `AETERNA_WATCH_PORT` changes the port (the test uses another one).
Test without a watch: `godot --xr-mode off --resolution 960x600 --path godot -s res://tools/watch_link_test.gd` (opens a window for a moment, prints PASS).
Each live run saves the raw stream to `_work/watch/live_<time>.csv` for tuning the detector.
