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
 * Lines: a/g/r,time_us,values (accelerometer, gyroscope, game rotation vector), c,time_us,cue.
 * Tap the screen to start. Host comes from the launch extra "host" (see watch/watch_bridge.py) and is remembered.
 */
public class MainActivity extends Activity implements SensorEventListener {
    private static final int PORT = 9100;
    private static final long FLUSH_US = 10_000;
    private static final int MAX_DATAGRAM = 1200;

    private final StringBuilder pending = new StringBuilder();  // touched on the sensor thread only
    private final Handler ui = new Handler(Looper.getMainLooper());
    private HandlerThread sensorThread;
    private Handler sensorHandler;
    private SensorManager sensors;
    private ConnectivityManager connectivity;
    private ConnectivityManager.NetworkCallback wifiCallback;
    private DatagramSocket socket;
    private InetAddress target;
    private String host = "";
    private long lastFlushUs;
    private TextView label;
    private boolean running;

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

    private static List<Cue> script() {
        Random rnd = new Random();
        List<Cue> cues = new ArrayList<>();
        cues.add(new Cue("still", "HOLD STILL", Color.DKGRAY, 10_000));
        for (int i = 0; i < 20; i++) {  // arm at rest: the cleanest signal a pinch can give
            cues.add(new Cue("pinch", "PINCH", Color.rgb(0, 150, 60), 1500));
            cues.add(new Cue("open", "OPEN", Color.BLACK, 1500 + rnd.nextInt(1000)));
        }
        cues.add(new Cue("move", "MOVE ARM\nno pinching", Color.rgb(170, 100, 0), 30_000));  // what must NOT count as a pinch
        for (int i = 0; i < 15; i++) {  // the real case: aiming and pinching together
            cues.add(new Cue("aim", "AIM AROUND", Color.rgb(170, 100, 0), 2000 + rnd.nextInt(1000)));
            cues.add(new Cue("pinch_moving", "PINCH", Color.rgb(0, 150, 60), 1500));
            cues.add(new Cue("open_moving", "OPEN", Color.BLACK, 700));
        }
        cues.add(new Cue("done", "DONE", Color.DKGRAY, 0));
        return cues;
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
        label.setText(host.isEmpty() ? "NO HOST\nsee watch_bridge.py" : "TAP TO START\n" + host);
        label.setOnClickListener(v -> start());
        setContentView(label);
        connectivity = getSystemService(ConnectivityManager.class);
        sensors = getSystemService(SensorManager.class);
        sensorThread = new HandlerThread("sensors");
        sensorThread.start();
        sensorHandler = new Handler(sensorThread.getLooper());
        sensorHandler.post(this::openSocket);
        useWifi();
    }

    /** Wear OS sends traffic through the phone's Bluetooth by default; a local UDP stream needs the watch's own Wi-Fi. */
    private void useWifi() {
        wifiCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                connectivity.bindProcessToNetwork(network);
                sensorHandler.post(MainActivity.this::openSocket);
            }
        };
        NetworkRequest wifi = new NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build();
        connectivity.requestNetwork(wifi, wifiCallback);
    }

    private void openSocket() {
        if (host.isEmpty()) {
            return;
        }
        try {
            if (socket != null) {
                socket.close();
            }
            target = InetAddress.getByName(host);
            socket = new DatagramSocket();
            send("c," + nowUs() + ",hello\n");
        } catch (IOException e) {
            showOnUi("NETWORK ERROR\n" + e.getMessage());
        }
    }

    private void start() {
        if (running || host.isEmpty()) {
            return;
        }
        running = true;
        for (int type : new int[]{Sensor.TYPE_ACCELEROMETER, Sensor.TYPE_GYROSCOPE, Sensor.TYPE_GAME_ROTATION_VECTOR}) {
            Sensor sensor = sensors.getDefaultSensor(type);
            if (sensor != null) {
                sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_FASTEST, sensorHandler);
            }
        }
        runCue(script(), 0);
    }

    private void runCue(List<Cue> cues, int index) {
        Cue cue = cues.get(index);
        label.setText(cue.text);
        label.setBackgroundColor(cue.color);
        long now = nowUs();
        sensorHandler.post(() -> {
            pending.append("c,").append(now).append(',').append(cue.name).append('\n');
            flush();
        });
        if (index + 1 == cues.size()) {
            ui.postDelayed(this::stopStream, 500);
            return;
        }
        ui.postDelayed(() -> runCue(cues, index + 1), cue.ms);
    }

    private void stopStream() {
        sensors.unregisterListener(this);
        sensorHandler.post(() -> {
            pending.append("c,").append(nowUs()).append(",end\n");
            flush();
        });
        running = false;
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
            return;
        }
        byte[] data = text.getBytes(StandardCharsets.US_ASCII);
        try {
            socket.send(new DatagramPacket(data, data.length, target, PORT));
        } catch (IOException e) {
            showOnUi("SEND ERROR\n" + e.getMessage());
        }
    }

    private void showOnUi(String text) {
        ui.post(() -> {
            if (!running) {
                label.setText(text);
            }
        });
    }

    private static long nowUs() {
        return SystemClock.elapsedRealtimeNanos() / 1000;  // the same clock as SensorEvent.timestamp
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }

    @Override
    protected void onDestroy() {
        sensors.unregisterListener(this);
        ui.removeCallbacksAndMessages(null);
        connectivity.unregisterNetworkCallback(wifiCallback);
        connectivity.bindProcessToNetwork(null);
        sensorThread.quitSafely();
        super.onDestroy();
    }
}
