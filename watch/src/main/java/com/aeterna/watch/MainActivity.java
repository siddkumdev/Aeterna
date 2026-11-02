package com.aeterna.watch;

import android.app.Activity;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.TextView;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Pinch feasibility recorder: streams the raw motion sensors over UDP and shows timed cues, so the recording says when each
 * pinch and unpinch was asked for. Cues are on screen only: a vibration would shake the same sensors we are measuring.
 * Each datagram starts with s,seq. Then lines: a/g/r,time_us,values (accelerometer, gyroscope, game rotation vector),
 * c,time_us,index,cue (sent three times, because a lost cue would mislabel the take), and at the end
 * e,time_us,cues_sent,send_failures,reason (sent five times). watch_bridge.py removes duplicates and reports anything lost.
 * Tap the screen to start. Host comes from the launch extra "host" (see watch/watch_bridge.py) and is remembered.
 */
public class MainActivity extends Activity implements SensorEventListener {
    private static final int PORT = 9100;
    private static final long FLUSH_US = 10_000;
    private static final int MAX_DATAGRAM = 1200;
    private static final int WIFI_TIMEOUT_MS = 20_000;

    private final Handler ui = new Handler(Looper.getMainLooper());
    private final Object cueTimers = new Object();
    private WifiManager.WifiLock wifiLock;  // Wi-Fi power saving would drop bursts of the stream
    private HandlerThread sensorThread;
    private Handler sensorHandler;
    private SensorManager sensors;
    private ConnectivityManager connectivity;
    private ConnectivityManager.NetworkCallback wifiCallback;
    private String host = "";
    private TextView label;
    // UI thread only
    private boolean wifiReady;
    private boolean running;
    private int cuesSent;
    private int nextPart;
    // sensor thread only
    private final StringBuilder pending = new StringBuilder();
    private DatagramSocket socket;
    private InetAddress target;
    private long lastFlushUs;
    private long sequence;
    private int sendFailures;

    private static final class Cue {
        final String name;
        final String text;
        final int color;
        final long ms;

        Cue(String name, String text, int color, long ms) {
            this.name = name;
            this.text = text;
            this.color = color;
            this.ms = ms;
        }
    }

    /**
     * Two parts, each about 80 s: Wear OS takes an app off the screen after roughly 150 s (seen on the Galaxy Watch 4 in
     * the first long take), which ends a longer run. Each tap runs the next part; a part that ends early is repeated.
     */
    private static List<Cue> script(int part) {
        Random rnd = new Random();
        List<Cue> cues = new ArrayList<>();
        if (part == 0) {
            cues.add(new Cue("still", "HOLD STILL", Color.DKGRAY, 8_000));
            for (int i = 0; i < 20; i++) {  // arm at rest: the cleanest signal a pinch can give
                cues.add(new Cue("pinch", "PINCH", Color.rgb(0, 150, 60), 1500));
                cues.add(new Cue("open", "OPEN", Color.BLACK, 1500 + rnd.nextInt(1000)));
            }
        } else {
            cues.add(new Cue("move", "MOVE ARM\nno pinching", Color.rgb(170, 100, 0), 25_000));  // what must NOT count as a pinch
            for (int i = 0; i < 12; i++) {  // the real case: aiming and pinching together
                cues.add(new Cue("aim", "AIM AROUND", Color.rgb(170, 100, 0), 2000 + rnd.nextInt(1000)));
                cues.add(new Cue("pinch_moving", "PINCH", Color.rgb(0, 150, 60), 1500));
                cues.add(new Cue("open_moving", "OPEN", Color.BLACK, 700));
            }
        }
        cues.add(new Cue("done", "DONE", Color.DKGRAY, 0));
        return cues;
    }

    private String idleText() {
        return "TAP TO START\npart " + (nextPart + 1) + " of 2\n" + host;
    }

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        SharedPreferences prefs = getSharedPreferences("bridge", MODE_PRIVATE);
        String extra = getIntent().getStringExtra("host");
        if (extra != null) {
            prefs.edit().putString("host", extra).apply();
        }
        host = prefs.getString("host", "");
        label = new TextView(this);
        label.setGravity(Gravity.CENTER);
        label.setTextSize(26);
        label.setTextColor(Color.WHITE);
        label.setBackgroundColor(Color.BLACK);
        label.setText(host.isEmpty() ? "NO HOST\nsee watch_bridge.py" : "WAITING FOR WIFI");
        label.setOnClickListener(v -> start());
        setContentView(label);
        connectivity = getSystemService(ConnectivityManager.class);
        sensors = getSystemService(SensorManager.class);
        wifiLock = getSystemService(WifiManager.class).createWifiLock(WifiManager.WIFI_MODE_FULL_LOW_LATENCY, "aeterna:stream");
        wifiLock.setReferenceCounted(false);
        sensorThread = new HandlerThread("sensors");
        sensorThread.start();
        sensorHandler = new Handler(sensorThread.getLooper());
        if (!host.isEmpty()) {
            useWifi();
        }
    }

    /** Wear OS sends traffic through the phone's Bluetooth by default; a local UDP stream needs the watch's own Wi-Fi. */
    private void useWifi() {
        wifiCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                connectivity.bindProcessToNetwork(network);
                sensorHandler.post(MainActivity.this::openSocket);
            }

            @Override
            public void onUnavailable() {
                ui.post(() -> setIdle(false, "NO WIFI\nconnect the watch\nand reopen"));
            }

            @Override
            public void onLost(Network network) {
                ui.post(() -> setIdle(false, "WAITING FOR WIFI"));
            }
        };
        NetworkRequest wifi = new NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build();
        connectivity.requestNetwork(wifi, wifiCallback, WIFI_TIMEOUT_MS);
    }

    private void setIdle(boolean ready, String text) {
        wifiReady = ready;
        if (!running && !label.getText().toString().startsWith("DONE") && !label.getText().toString().startsWith("STOPPED")) {
            label.setText(text);
            label.setBackgroundColor(Color.BLACK);
        }
    }

    private void openSocket() {
        try {
            if (socket != null) {
                socket.close();
            }
            socket = null;
            target = InetAddress.getByName(host);
            socket = new DatagramSocket();
            send("c," + nowUs() + ",-1,hello\n");
            ui.post(() -> setIdle(true, idleText()));
        } catch (IOException e) {
            socket = null;
            ui.post(() -> setIdle(false, "NETWORK ERROR\n" + e.getMessage()));
        }
    }

    private void start() {
        if (running || !wifiReady) {
            return;
        }
        running = true;
        cuesSent = 0;
        wifiLock.acquire();
        for (int type : new int[]{Sensor.TYPE_ACCELEROMETER, Sensor.TYPE_GYROSCOPE, Sensor.TYPE_GAME_ROTATION_VECTOR}) {
            Sensor sensor = sensors.getDefaultSensor(type);
            if (sensor != null) {
                sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_FASTEST, sensorHandler);
            }
        }
        sensorHandler.post(() -> sendFailures = 0);
        runCue(script(nextPart), 0);
    }

    private void runCue(List<Cue> cues, int index) {
        Cue cue = cues.get(index);
        label.setText(cue.text);
        label.setBackgroundColor(cue.color);
        cuesSent = index + 1;
        String line = "c," + nowUs() + "," + index + "," + cue.name + "\n";
        sensorHandler.post(() -> {
            pending.append(line);
            flush();
        });
        // Copies spread over a second: one Wi-Fi hiccup at the start of a part took out all three copies sent within 60 ms.
        sensorHandler.postDelayed(() -> send(line), 150);
        sensorHandler.postDelayed(() -> send(line), 500);
        sensorHandler.postDelayed(() -> send(line), 1000);
        if (index + 1 == cues.size()) {
            ui.postDelayed(() -> stopRun("complete"), cueTimers, 500);
            return;
        }
        ui.postDelayed(() -> runCue(cues, index + 1), cueTimers, cue.ms);
    }

    private void stopRun(String reason) {
        if (!running) {
            return;
        }
        running = false;
        if (reason.equals("complete")) {
            nextPart = (nextPart + 1) % 2;
        }
        ui.removeCallbacksAndMessages(cueTimers);
        sensors.unregisterListener(this);
        if (wifiLock.isHeld()) {
            wifiLock.release();
        }
        int cues = cuesSent;
        sensorHandler.post(() -> {
            flush();
            String end = "e," + nowUs() + "," + cues + "," + sendFailures + "," + reason + "\n";
            for (int i = 0; i < 5; i++) {
                sensorHandler.postDelayed(() -> send(end), i * 50L);
            }
            int failures = sendFailures;
            ui.post(() -> {
                boolean complete = reason.equals("complete");
                label.setText((complete ? "DONE" : "STOPPED EARLY\n" + reason) + "\n" + failures + " send errors\n\ntap: " + (complete ? "next part" : "repeat part")
                        + " " + (nextPart + 1));
                label.setBackgroundColor(Color.DKGRAY);
            });
        });
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        char tag;
        switch (event.sensor.getType()) {
            case Sensor.TYPE_ACCELEROMETER:
                tag = 'a';
                break;
            case Sensor.TYPE_GYROSCOPE:
                tag = 'g';
                break;
            default:
                tag = 'r';
                break;
        }
        long us = event.timestamp / 1000;
        pending.append(tag).append(',').append(us);
        int count = Math.min(event.values.length, tag == 'r' ? 4 : 3);
        for (int i = 0; i < count; i++) {
            pending.append(',').append(event.values[i]);
        }
        pending.append('\n');
        if (us - lastFlushUs >= FLUSH_US || pending.length() >= MAX_DATAGRAM) {
            lastFlushUs = us;
            flush();
        }
    }

    private void flush() {
        if (pending.length() > 0) {
            send(pending.toString());
            pending.setLength(0);
        }
    }

    private void send(String text) {
        if (socket == null) {
            sendFailures++;
            return;
        }
        byte[] data = ("s," + (sequence++) + "\n" + text).getBytes(StandardCharsets.US_ASCII);
        try {
            socket.send(new DatagramPacket(data, data.length, target, PORT));
        } catch (IOException e) {
            sendFailures++;
        }
    }

    private static long nowUs() {
        return SystemClock.elapsedRealtimeNanos() / 1000;  // the same clock as SensorEvent.timestamp
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }

    @Override
    protected void onPause() {
        stopRun("aborted");  // cues nobody can see must not keep labelling the take
        super.onPause();
    }

    @Override
    protected void onStop() {
        super.onStop();
        finish();  // reopening starts fresh, so a timed-out Wi-Fi request cannot leave the screen stuck on NO WIFI
    }

    @Override
    protected void onDestroy() {
        ui.removeCallbacksAndMessages(null);
        if (wifiCallback != null) {
            try {
                connectivity.unregisterNetworkCallback(wifiCallback);
            } catch (IllegalArgumentException e) {
                // a timed-out request was already released
            }
        }
        connectivity.bindProcessToNetwork(null);
        sensorThread.quitSafely();
        super.onDestroy();
    }
}
