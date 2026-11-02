package com.aeterna.watch;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.PowerManager;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;

/**
 * Live input: streams the accelerometer (for the pinch) and the game rotation vector (for aiming) over UDP while the screen
 * is off and no app is in front, so the watch can be worn and used as a controller. Started and stopped from the laptop:
 *   adb shell am start-foreground-service -n com.aeterna.watch/.LiveService --es host LAPTOP_IP
 *   adb shell am stopservice -n com.aeterna.watch/.LiveService
 * Datagrams are the same as the recorder's: s,seq then a,time_us,x,y,z and r,time_us,x,y,z,w lines.
 */
public class LiveService extends Service implements SensorEventListener {
    private static final int PORT = 9100;
    private static final long FLUSH_US = 10_000;
    private static final int MAX_DATAGRAM = 1200;
    private static final long MAX_RUN_MS = 3L * 60 * 60 * 1000;  // a forgotten stream must not drain the watch for ever

    private final StringBuilder pending = new StringBuilder();  // sensor thread only
    private HandlerThread thread;
    private Handler handler;
    private SensorManager sensors;
    private ConnectivityManager connectivity;
    private ConnectivityManager.NetworkCallback wifiCallback;
    private PowerManager.WakeLock wakeLock;
    private WifiManager.WifiLock wifiLock;
    private DatagramSocket socket;  // sensor thread only
    private InetAddress target;
    private long lastFlushUs;
    private long sequence;
    private boolean started;

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        goForeground();  // always first: a service started as a foreground service that never calls it is killed with a crash
        String host = intent == null ? null : intent.getStringExtra("host");
        if (host == null || host.isEmpty()) {
            stopSelf();
            return START_NOT_STICKY;
        }
        if (started) {
            return START_NOT_STICKY;
        }
        started = true;
        connectivity = getSystemService(ConnectivityManager.class);
        sensors = getSystemService(SensorManager.class);
        PowerManager power = getSystemService(PowerManager.class);
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "aeterna:live");
        wakeLock.acquire(MAX_RUN_MS);
        WifiManager wifi = getSystemService(WifiManager.class);
        wifiLock = wifi.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "aeterna:live");  // low latency mode needs the screen on
        wifiLock.acquire();
        thread = new HandlerThread("live-sensors");
        thread.start();
        handler = new Handler(thread.getLooper());
        handler.post(() -> openSocket(host));
        handler.postDelayed(this::stopSelf, MAX_RUN_MS);
        wifiCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                connectivity.bindProcessToNetwork(network);
                handler.post(() -> openSocket(host));
            }
        };
        connectivity.requestNetwork(new NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build(), wifiCallback);
        for (int type : new int[]{Sensor.TYPE_ACCELEROMETER, Sensor.TYPE_GAME_ROTATION_VECTOR}) {
            Sensor sensor = sensors.getDefaultSensor(type);
            if (sensor != null) {
                sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_FASTEST, handler);
            }
        }
        return START_NOT_STICKY;
    }

    private void goForeground() {
        NotificationManager manager = getSystemService(NotificationManager.class);
        manager.createNotificationChannel(new NotificationChannel("live", "Live input", NotificationManager.IMPORTANCE_LOW));
        Notification notification = new Notification.Builder(this, "live")
                .setContentTitle("Aeterna live input")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setOngoing(true)
                .build();
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        } else {
            startForeground(1, notification);
        }
    }

    private void openSocket(String host) {
        try {
            if (socket != null) {
                socket.close();
            }
            socket = null;
            target = InetAddress.getByName(host);
            socket = new DatagramSocket();
            send("c," + System.nanoTime() / 1000 + ",-1,hello\n");
        } catch (IOException e) {
            socket = null;
        }
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        boolean rotation = event.sensor.getType() == Sensor.TYPE_GAME_ROTATION_VECTOR;
        long us = event.timestamp / 1000;
        pending.append(rotation ? 'r' : 'a').append(',').append(us);
        int count = Math.min(event.values.length, rotation ? 4 : 3);
        for (int i = 0; i < count; i++) {
            pending.append(',').append(event.values[i]);
        }
        pending.append('\n');
        if (us - lastFlushUs >= FLUSH_US || pending.length() >= MAX_DATAGRAM) {
            lastFlushUs = us;
            send(pending.toString());
            pending.setLength(0);
        }
    }

    private void send(String text) {
        if (socket == null) {
            return;
        }
        byte[] data = ("s," + (sequence++) + "\n" + text).getBytes(StandardCharsets.US_ASCII);
        try {
            socket.send(new DatagramPacket(data, data.length, target, PORT));
        } catch (IOException e) {
            // the bridge reports lost datagrams from the sequence numbers
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }

    @Override
    public void onDestroy() {
        if (sensors != null) {
            sensors.unregisterListener(this);
        }
        if (wifiCallback != null) {
            try {
                connectivity.unregisterNetworkCallback(wifiCallback);
            } catch (IllegalArgumentException e) {
                // already released
            }
            connectivity.bindProcessToNetwork(null);
        }
        if (wifiLock != null && wifiLock.isHeld()) {
            wifiLock.release();
        }
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }
        if (handler != null) {
            handler.post(() -> {
                if (socket != null) {
                    socket.close();
                }
            });
        }
        if (thread != null) {
            thread.quitSafely();
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
