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
