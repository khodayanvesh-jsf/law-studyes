param(
  [string]$Version = "3.2.5",
  [int]$VersionCode = 325,
  [switch]$SkipApkBuild
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$env:PYTHONIOENCODING = "utf-8"

$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$wwwDir = Join-Path $root "www"
$modDir = Join-Path $wwwDir "js\modules"
$jsDir = Join-Path $wwwDir "js"
$androidMain = Join-Path $root "android\app\src\main"
$manifestPath = Join-Path $androidMain "AndroidManifest.xml"
New-Item -ItemType Directory -Path $modDir, $jsDir -Force | Out-Null

$mainAct = Get-ChildItem (Join-Path $androidMain "java") -Recurse -Filter "MainActivity.java" -File | Select-Object -First 1
if (-not $mainAct) { throw "MainActivity.java not found under android/app/src/main/java!" }
$origJava = [System.IO.File]::ReadAllText($mainAct.FullName, $u)
$pkgMatch = [regex]::Match($origJava, 'package\s+([A-Za-z0-9_.]+);')
if (-not $pkgMatch.Success) { throw "Could not detect Java package name in MainActivity.java" }
$pkgName = $pkgMatch.Groups[1].Value
$pkgDir = $mainAct.DirectoryName
Write-Host "[INFO] Detected Android Package: $pkgName" -ForegroundColor Cyan

Write-Host "`n=== 1. Updating AndroidManifest.xml (Foreground Media Playback + WakeLock + Lock-Screen Notification) ===" -ForegroundColor Cyan
$mTxt = [System.IO.File]::ReadAllText($manifestPath, $u)
$perms = @(
  "android.permission.WAKE_LOCK",
  "android.permission.FOREGROUND_SERVICE",
  "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
  "android.permission.POST_NOTIFICATIONS"
)
foreach ($perm in $perms) {
  if ($mTxt -notmatch [regex]::Escape($perm)) {
    $mTxt = $mTxt -replace '(<manifest[^>]*>)', "`$1`r`n    <uses-permission android:name=`"$perm`" />"
    Write-Host "  [ADDED] Permission $perm" -ForegroundColor Green
  }
}

if ($mTxt -notmatch 'LsAudioForegroundService') {
  $svcXml = "`r`n        <service android:name=`".LsAudioForegroundService`" android:enabled=`"true`" android:exported=`"false`" android:foregroundServiceType=`"mediaPlayback`" />`r`n"
  $mTxt = $mTxt -replace '(</application>)', ($svcXml + '    $1')
  Write-Host "  [ADDED] Foreground service <service android:name='.LsAudioForegroundService' />" -ForegroundColor Green
}
[System.IO.File]::WriteAllText($manifestPath, $mTxt, $u)

Write-Host "`n=== 2. Installing Native Android Foreground TTS Service (LsAudioForegroundService.java) ===" -ForegroundColor Cyan
$svcJava = @"
package $pkgName;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.speech.tts.Voice;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public class LsAudioForegroundService extends Service implements TextToSpeech.OnInitListener {
    public static final String CHANNEL_ID = "law_studyes_audio_playback";
    public static final int NOTIF_ID = 32501;

    public static final String ACT_PLAY_QUEUE = "LS_ACT_PLAY_QUEUE";
    public static final String ACT_PAUSE      = "LS_ACT_PAUSE";
    public static final String ACT_RESUME     = "LS_ACT_RESUME";
    public static final String ACT_STOP       = "LS_ACT_STOP";
    public static final String ACT_NEXT       = "LS_ACT_NEXT";
    public static final String ACT_PREV       = "LS_ACT_PREV";
    public static final String ACT_SET_SPEED  = "LS_ACT_SET_SPEED";
    public static final String ACT_SET_VOICE  = "LS_ACT_SET_VOICE";
    public static final String ACT_JUMP       = "LS_ACT_JUMP";

    public static volatile boolean isPlaying = false;
    public static volatile boolean isPaused = false;
    public static volatile int currentIndex = 0;
    public static volatile int totalItems = 0;
    public static volatile String currentTitle = "Law Studyes Audio";
    public static volatile String currentCaption = "";
    public static volatile String currentTopicId = "";
    public static volatile int currentStepIdx = -1;
    public static volatile String currentVoiceLabel = "Indian Voice";
    public static volatile float currentRate = 0.98f;
    public static volatile String currentLang = "en-IN";
    public static volatile String requestedVoiceName = "";
    public static volatile boolean repeatTopic = false;

    private static final List<JSONObject> queueItems = new ArrayList<>();
    private static volatile int speakGeneration = 0;

    private TextToSpeech tts;
    private boolean ttsReady = false;
    private boolean pendingStart = false;
    private PowerManager.WakeLock wakeLock;
    private AudioManager audioManager;
    private AudioFocusRequest focusRequest;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public static String getSnapshotJson() {
        try {
            JSONObject o = new JSONObject();
            o.put("playing", isPlaying);
            o.put("paused", isPaused);
            o.put("index", currentIndex);
            o.put("total", totalItems);
            o.put("title", currentTitle);
            o.put("caption", currentCaption);
            o.put("topicId", currentTopicId);
            o.put("stepIdx", currentStepIdx);
            o.put("voiceName", currentVoiceLabel);
            o.put("rate", currentRate);
            return o.toString();
        } catch (Exception e) {
            return "{}";
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        audioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        createNotificationChannel();
        tts = new TextToSpeech(getApplicationContext(), this);
    }

    @Override
    public void onInit(int status) {
        if (status == TextToSpeech.SUCCESS && tts != null) {
            ttsReady = true;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                tts.setAudioAttributes(new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build());
            }
            tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override
                public void onStart(String utteranceId) {}

                @Override
                public void onDone(String utteranceId) {
                    handleUtteranceFinished(utteranceId);
                }

                @Override
                public void onError(String utteranceId) {
                    handleUtteranceFinished(utteranceId);
                }
            });
            if (pendingStart && isPlaying && !isPaused) {
                pendingStart = false;
                speakCurrentIndex();
            }
        }
    }

    private void handleUtteranceFinished(final String utteranceId) {
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                String expected = "ls_" + speakGeneration + "_" + currentIndex;
                if (!expected.equals(utteranceId)) return;
                if (!isPlaying || isPaused) return;
                if (currentIndex + 1 < queueItems.size()) {
                    currentIndex++;
                    speakCurrentIndex();
                } else if (repeatTopic && !queueItems.isEmpty()) {
                    currentIndex = 0;
                    speakCurrentIndex();
                } else {
                    stopPlaybackAndService();
                }
            }
        });
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_NOT_STICKY;
        String action = intent.getAction();
        if (action == null) return START_NOT_STICKY;

        if (ACT_PLAY_QUEUE.equals(action)) {
            String qJson = intent.getStringExtra("queueJson");
            String lang = intent.getStringExtra("lang");
            float rate = intent.getFloatExtra("rate", 0.98f);
            String vName = intent.getStringExtra("voiceName");
            int startIdx = intent.getIntExtra("startIndex", 0);
            repeatTopic = intent.getBooleanExtra("repeat", false);

            queueItems.clear();
            try {
                JSONArray arr = new JSONArray(qJson != null ? qJson : "[]");
                for (int i = 0; i < arr.length(); i++) {
                    queueItems.add(arr.getJSONObject(i));
                }
            } catch (Exception ignored) {}

            totalItems = queueItems.size();
            if (totalItems == 0) {
                stopPlaybackAndService();
                return START_NOT_STICKY;
            }
            currentIndex = Math.max(0, Math.min(startIdx, totalItems - 1));
            currentLang = (lang != null && !lang.isEmpty()) ? lang : "en-IN";
            currentRate = Math.max(0.6f, Math.min(1.8f, rate));
            requestedVoiceName = (vName != null) ? vName : "";
            isPlaying = true;
            isPaused = false;

            acquireWakeLock();
            requestAudioFocus();
            promoteToForeground();

            if (ttsReady) {
                speakCurrentIndex();
            } else {
                pendingStart = true;
            }
        } else if (ACT_PAUSE.equals(action)) {
            if (isPlaying && !isPaused) {
                isPaused = true;
                speakGeneration++;
                if (tts != null) tts.stop();
                releaseWakeLock();
                updateNotification();
                notifyJsBridge();
            }
        } else if (ACT_RESUME.equals(action)) {
            if (isPlaying && isPaused && !queueItems.isEmpty()) {
                isPaused = false;
                acquireWakeLock();
                requestAudioFocus();
                promoteToForeground();
                if (ttsReady) speakCurrentIndex();
                else pendingStart = true;
            }
        } else if (ACT_NEXT.equals(action)) {
            if (!queueItems.isEmpty()) {
                currentIndex = Math.min(queueItems.size() - 1, currentIndex + 1);
                isPlaying = true;
                isPaused = false;
                acquireWakeLock();
                promoteToForeground();
                if (ttsReady) speakCurrentIndex();
            }
        } else if (ACT_PREV.equals(action)) {
            if (!queueItems.isEmpty()) {
                currentIndex = Math.max(0, currentIndex - 1);
                isPlaying = true;
                isPaused = false;
                acquireWakeLock();
                promoteToForeground();
                if (ttsReady) speakCurrentIndex();
            }
        } else if (ACT_JUMP.equals(action)) {
            int idx = intent.getIntExtra("index", 0);
            if (!queueItems.isEmpty()) {
                currentIndex = Math.max(0, Math.min(idx, queueItems.size() - 1));
                isPlaying = true;
                isPaused = false;
                acquireWakeLock();
                promoteToForeground();
                if (ttsReady) speakCurrentIndex();
            }
        } else if (ACT_SET_SPEED.equals(action)) {
            float r = intent.getFloatExtra("rate", 0.98f);
            currentRate = Math.max(0.6f, Math.min(1.8f, r));
            if (isPlaying && !isPaused && ttsReady) speakCurrentIndex();
            else notifyJsBridge();
        } else if (ACT_SET_VOICE.equals(action)) {
            String v = intent.getStringExtra("voiceName");
            requestedVoiceName = (v != null) ? v : "";
            if (isPlaying && !isPaused && ttsReady) speakCurrentIndex();
            else notifyJsBridge();
        } else if (ACT_STOP.equals(action)) {
            stopPlaybackAndService();
        }

        return START_NOT_STICKY;
    }

    private void applyLanguageAndVoice(String bcp47) {
        if (tts == null) return;
        Locale loc = Locale.forLanguageTag(bcp47 != null ? bcp47 : "en-IN");
        tts.setLanguage(loc);
        tts.setSpeechRate(currentRate);
        tts.setPitch(1.0f);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                Set<Voice> voices = tts.getVoices();
                if (voices != null && !voices.isEmpty()) {
                    Voice picked = null;
                    if (requestedVoiceName != null && !requestedVoiceName.isEmpty() && !"auto".equalsIgnoreCase(requestedVoiceName)) {
                        for (Voice v : voices) {
                            if (v != null && requestedVoiceName.equals(v.getName())) {
                                picked = v;
                                break;
                            }
                        }
                    }
                    if (picked == null) {
                        String targetLang = loc.getLanguage().toLowerCase(Locale.ROOT);
                        int bestScore = -999;
                        for (Voice v : voices) {
                            if (v == null || v.getLocale() == null) continue;
                            String vl = v.getLocale().getLanguage().toLowerCase(Locale.ROOT);
                            String vc = v.getLocale().getCountry().toUpperCase(Locale.ROOT);
                            if (!targetLang.equals(vl)) continue;
                            int sc = "IN".equals(vc) ? 200 : 80;
                            String vn = v.getName().toLowerCase(Locale.ROOT);
                            if (vn.contains("network") || vn.contains("neural") || vn.contains("wavenet")) sc += 70;
                            if (!v.isNetworkConnectionRequired()) sc += 20;
                            if (sc > bestScore) { bestScore = sc; picked = v; }
                        }
                    }
                    if (picked != null) {
                        tts.setVoice(picked);
                        currentVoiceLabel = picked.getName();
                        return;
                    }
                }
            } catch (Exception ignored) {}
        }
        currentVoiceLabel = "Indian Voice (" + currentLang + ")";
    }

    private void speakCurrentIndex() {
        if (!ttsReady || tts == null || currentIndex < 0 || currentIndex >= queueItems.size()) return;
        try {
            JSONObject item = queueItems.get(currentIndex);
            String text = item.optString("text", "").trim();
            currentTitle = item.optString("topicTitle", currentTitle);
            currentTopicId = item.optString("topicId", currentTopicId);
            currentStepIdx = item.optInt("stepIdx", -1);
            currentCaption = text;
            String itemLang = item.optString("lang", currentLang);
            if ("te".equalsIgnoreCase(itemLang)) itemLang = "te-IN";
            else if ("hi".equalsIgnoreCase(itemLang)) itemLang = "hi-IN";
            else if ("en".equalsIgnoreCase(itemLang)) itemLang = "en-IN";
            currentLang = itemLang;

            if (text.isEmpty()) {
                if (currentIndex + 1 < queueItems.size()) {
                    currentIndex++;
                    speakCurrentIndex();
                } else {
                    stopPlaybackAndService();
                }
                return;
            }

            speakGeneration++;
            String uttId = "ls_" + speakGeneration + "_" + currentIndex;
            applyLanguageAndVoice(currentLang);
            updateNotification();
            notifyJsBridge();

            Bundle params = new Bundle();
            params.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_MUSIC);
            params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f);
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, uttId);
        } catch (Exception ignored) {}
    }

    private void stopPlaybackAndService() {
        speakGeneration++;
        isPlaying = false;
        isPaused = false;
        if (tts != null) {
            try { tts.stop(); } catch (Exception ignored) {}
        }
        abandonAudioFocus();
        releaseWakeLock();
        notifyJsBridge();
        try { stopForeground(true); } catch (Exception ignored) {}
        stopSelf();
    }

    private void promoteToForeground() {
        Notification notif = buildNotification();
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
            } else {
                startForeground(NOTIF_ID, notif);
            }
        } catch (Exception e) {
            try { startForeground(NOTIF_ID, notif); } catch (Exception ignored) {}
        }
    }

    private void updateNotification() {
        try {
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null && isPlaying) nm.notify(NOTIF_ID, buildNotification());
        } catch (Exception ignored) {}
    }

    private PendingIntent makeActionIntent(String action, int reqCode) {
        Intent i = new Intent(this, LsAudioForegroundService.class);
        i.setAction(action);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags |= PendingIntent.FLAG_IMMUTABLE;
        return PendingIntent.getService(this, reqCode, i, flags);
    }

    private Notification buildNotification() {
        Intent openIntent = new Intent(this, MainActivity.class);
        openIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        int piFlags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) piFlags |= PendingIntent.FLAG_IMMUTABLE;
        PendingIntent contentPi = PendingIntent.getActivity(this, 100, openIntent, piFlags);

        Notification.Builder b = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);

        String sub = isPaused
                ? "Paused (" + (currentIndex + 1) + "/" + Math.max(1, totalItems) + ")"
                : ((currentIndex + 1) + "/" + Math.max(1, totalItems) + " - " + currentCaption);

        b.setContentTitle(currentTitle)
         .setContentText(sub)
         .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
         .setOngoing(!isPaused)
         .setOnlyAlertOnce(true)
         .setVisibility(Notification.VISIBILITY_PUBLIC)
         .setContentIntent(contentPi)
         .addAction(android.R.drawable.ic_media_previous, "Prev", makeActionIntent(ACT_PREV, 101))
         .addAction(
                 isPaused ? android.R.drawable.ic_media_play : android.R.drawable.ic_media_pause,
                 isPaused ? "Resume" : "Pause",
                 makeActionIntent(isPaused ? ACT_RESUME : ACT_PAUSE, 102)
         )
         .addAction(android.R.drawable.ic_media_next, "Next", makeActionIntent(ACT_NEXT, 103))
         .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", makeActionIntent(ACT_STOP, 104));

        return b.build();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                    CHANNEL_ID,
                    "Law Studyes Audio Playback",
                    NotificationManager.IMPORTANCE_LOW
            );
            ch.setDescription("Keeps Indian Professor audio reading smoothly when phone is locked");
            ch.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null) nm.createNotificationChannel(ch);
        }
    }

    private void requestAudioFocus() {
        if (audioManager == null) return;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (focusRequest == null) {
                    focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                            .setAudioAttributes(new AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_MEDIA)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                    .build())
                            .setOnAudioFocusChangeListener(new AudioManager.OnAudioFocusChangeListener() {
                                @Override
                                public void onAudioFocusChange(int focusChange) {
                                    if (focusChange == AudioManager.AUDIOFOCUS_LOSS && isPlaying && !isPaused) {
                                        Intent p = new Intent(LsAudioForegroundService.this, LsAudioForegroundService.class);
                                        p.setAction(ACT_PAUSE);
                                        startService(p);
                                    }
                                }
                            })
                            .build();
                }
                audioManager.requestAudioFocus(focusRequest);
            } else {
                audioManager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);
            }
        } catch (Exception ignored) {}
    }

    private void abandonAudioFocus() {
        if (audioManager == null) return;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && focusRequest != null) {
                audioManager.abandonAudioFocusRequest(focusRequest);
            }
        } catch (Exception ignored) {}
    }

    private synchronized void acquireWakeLock() {
        try {
            if (wakeLock == null) {
                PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
                if (pm != null) {
                    wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LawStudyes::ForegroundAudioWakeLock");
                    wakeLock.setReferenceCounted(false);
                }
            }
            if (wakeLock != null && !wakeLock.isHeld()) {
                wakeLock.acquire(4 * 60 * 60 * 1000L);
            }
        } catch (Exception ignored) {}
    }

    private synchronized void releaseWakeLock() {
        try {
            if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        } catch (Exception ignored) {}
    }

    private void notifyJsBridge() {
        MainActivity.pushAudioStateToWeb(getSnapshotJson());
    }

    @Override
    public void onDestroy() {
        speakGeneration++;
        isPlaying = false;
        isPaused = false;
        if (tts != null) {
            try { tts.stop(); tts.shutdown(); } catch (Exception ignored) {}
            tts = null;
        }
        abandonAudioFocus();
        releaseWakeLock();
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
"@

$svcPath = Join-Path $pkgDir "LsAudioForegroundService.java"
[System.IO.File]::WriteAllText($svcPath, $svcJava, $u)
Write-Host "[PASS] Installed $svcPath" -ForegroundColor Green

Write-Host "`n=== 3. Wiring MainActivity.java to Native Foreground Audio Service ===" -ForegroundColor Cyan
$mainJava = @"
package $pkgName;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
import android.speech.tts.Voice;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import com.getcapacitor.BridgeActivity;
import org.json.JSONArray;
import org.json.JSONObject;
import java.lang.ref.WeakReference;
import java.util.Locale;
import java.util.Set;

public class MainActivity extends BridgeActivity {
    private static WeakReference<MainActivity> activeRef = new WeakReference<>(null);
    private TextToSpeech voiceProbeTts;
    private volatile boolean probeReady = false;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        activeRef = new WeakReference<>(this);

        if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 3250);
            }
        }

        voiceProbeTts = new TextToSpeech(getApplicationContext(), new TextToSpeech.OnInitListener() {
            @Override
            public void onInit(int status) {
                probeReady = (status == TextToSpeech.SUCCESS);
            }
        });

        try {
            if (getBridge() != null && getBridge().getWebView() != null) {
                getBridge().getWebView().addJavascriptInterface(new NativeAudioBridge(), "LSNativeTtsService");
            }
        } catch (Exception ignored) {}
    }

    @Override
    public void onResume() {
        super.onResume();
        activeRef = new WeakReference<>(this);
        pushAudioStateToWeb(LsAudioForegroundService.getSnapshotJson());
    }

    @Override
    public void onDestroy() {
        if (voiceProbeTts != null) {
            try { voiceProbeTts.shutdown(); } catch (Exception ignored) {}
            voiceProbeTts = null;
        }
        super.onDestroy();
    }

    public static void pushAudioStateToWeb(final String jsonState) {
        final MainActivity act = activeRef.get();
        if (act == null || act.isFinishing()) return;
        act.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    if (act.getBridge() != null && act.getBridge().getWebView() != null) {
                        WebView wv = act.getBridge().getWebView();
                        String safe = jsonState.replace("\\", "\\\\").replace("'", "\\'");
                        wv.evaluateJavascript("window.__lsOnNativeAudioState && window.__lsOnNativeAudioState('" + safe + "');", null);
                    }
                } catch (Exception ignored) {}
            }
        });
    }

    private void dispatchSvc(Intent i, boolean asForeground) {
        try {
            if (asForeground && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(i);
            } else {
                startService(i);
            }
        } catch (Exception ignored) {}
    }

    private class NativeAudioBridge {
        @JavascriptInterface
        public boolean isAvailable() { return true; }

        @JavascriptInterface
        public void playQueue(String queueJson, String lang, float rate, String voiceName, int startIndex, boolean repeat) {
            Intent i = new Intent(MainActivity.this, LsAudioForegroundService.class);
            i.setAction(LsAudioForegroundService.ACT_PLAY_QUEUE);
            i.putExtra("queueJson", queueJson);
            i.putExtra("lang", lang);
            i.putExtra("rate", rate);
            i.putExtra("voiceName", voiceName);
            i.putExtra("startIndex", startIndex);
            i.putExtra("repeat", repeat);
            dispatchSvc(i, true);
        }

        @JavascriptInterface
        public void pause() {
            Intent i = new Intent(MainActivity.this, LsAudioForegroundService.class);
            i.setAction(LsAudioForegroundService.ACT_PAUSE);
            dispatchSvc(i, false);
        }

        @JavascriptInterface
        public void resume() {
            Intent i = new Intent(MainActivity.this, LsAudioForegroundService.class);
            i.setAction(LsAudioForegroundService.ACT_RESUME);
            dispatchSvc(i, true);
        }

        @JavascriptInterface
        public void stop() {
            Intent i = new Intent(MainActivity.this, LsAudioForegroundService.class);
            i.setAction(LsAudioForegroundService.ACT_STOP);
            dispatchSvc(i, false);
        }

        @JavascriptInterface
        public void next() {
            Intent i = new Intent(MainActivity.this, LsAudioForegroundService.class);
            i.setAction(LsAudioForegroundService.ACT_NEXT);
            dispatchSvc(i, false);
        }

        @JavascriptInterface
        public void prev() {
            Intent i = new Intent(MainActivity.this, LsAudioForegroundService.class);
            i.setAction(LsAudioForegroundService.ACT_PREV);
            dispatchSvc(i, false);
        }

        @JavascriptInterface
        public void jumpTo(int idx) {
            Intent i = new Intent(MainActivity.this, LsAudioForegroundService.class);
            i.setAction(LsAudioForegroundService.ACT_JUMP);
            i.putExtra("index", idx);
            dispatchSvc(i, false);
        }

        @JavascriptInterface
        public void setSpeed(float rate) {
            Intent i = new Intent(MainActivity.this, LsAudioForegroundService.class);
            i.setAction(LsAudioForegroundService.ACT_SET_SPEED);
            i.putExtra("rate", rate);
            dispatchSvc(i, false);
        }

        @JavascriptInterface
        public void setVoice(String voiceName) {
            Intent i = new Intent(MainActivity.this, LsAudioForegroundService.class);
            i.setAction(LsAudioForegroundService.ACT_SET_VOICE);
            i.putExtra("voiceName", voiceName);
            dispatchSvc(i, false);
        }

        @JavascriptInterface
        public String getState() {
            return LsAudioForegroundService.getSnapshotJson();
        }

        @JavascriptInterface
        public String getVoicesForLang(String bcp47) {
            JSONArray out = new JSONArray();
            if (!probeReady || voiceProbeTts == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
                return out.toString();
            }
            try {
                Locale target = Locale.forLanguageTag(bcp47 != null ? bcp47 : "en-IN");
                String langCode = target.getLanguage().toLowerCase(Locale.ROOT);
                Set<Voice> vs = voiceProbeTts.getVoices();
                if (vs != null) {
                    for (Voice v : vs) {
                        if (v == null || v.getLocale() == null) continue;
                        if (!langCode.equals(v.getLocale().getLanguage().toLowerCase(Locale.ROOT))) continue;
                        JSONObject o = new JSONObject();
                        o.put("name", v.getName());
                        o.put("lang", v.getLocale().toLanguageTag());
                        o.put("localService", !v.isNetworkConnectionRequired());
                        out.put(o);
                    }
                }
            } catch (Exception ignored) {}
            return out.toString();
        }
    }
}
"@

[System.IO.File]::WriteAllText($mainAct.FullName, $mainJava, $u)
Write-Host "[PASS] MainActivity.java wired to LSNativeTtsService." -ForegroundColor Green

Write-Host "`n=== 4. Updating www/js/modules/ls-audio-engine.js to Route Android APK Playback Through Foreground Service ===" -ForegroundColor Cyan
$engineJs = @'
(function () {
  "use strict";
  if (window.__lsCleanAudioV325) return;
  window.__lsCleanAudioV325 = true;

  var K_SPD = "ls_aud_spd_325", K_TCH = "ls_aud_tch_325", K_REP = "ls_aud_rep_325", K_VC = "ls_aud_vc_325_";
  var AUDIO_CACHE = "ls-prof-audio-v1", CDN = "https://law-studyes.vercel.app";

  var manifest = null, htmlAudio = null, webVoices = [];
  var token = 0, playing = false, paused = false, studioMp3 = false;
  var scope = "topic", teachMode = true, repeat = false, speed = 0.98, sleepId = null;
  var queue = [], curIdx = 0, curTopicId = "", curTitle = "", curCaption = "", curStepIdx = -1, curVoiceLbl = "Auto Best Indian Voice";

  function nativeSvc() {
    try { return (window.LSNativeTtsService && typeof window.LSNativeTtsService.playQueue === "function") ? window.LSNativeTtsService : null; }
    catch (e) { return null; }
  }

  function loadPrefs() {
    try {
      var sp = parseFloat(localStorage.getItem(K_SPD) || "0.98");
      if (isFinite(sp) && sp >= 0.6 && sp <= 1.8) speed = sp;
      teachMode = localStorage.getItem(K_TCH) !== "0";
      repeat = localStorage.getItem(K_REP) === "1";
    } catch (e) {}
  }

  function langNow() {
    try { var l = (typeof state !== "undefined" && state && state.lang) ? String(state.lang).toLowerCase() : "en"; return (l === "te" || l === "hi") ? l : "en"; }
    catch (e) { return "en"; }
  }
  function bcp47(l) { l = String(l || langNow()).toLowerCase(); return l === "te" ? "te-IN" : (l === "hi" ? "hi-IN" : "en-IN"); }
  function getSavedVc(l) { try { return localStorage.getItem(K_VC + l) || "auto"; } catch (e) { return "auto"; } }
  function setSavedVc(l, k) { try { localStorage.setItem(K_VC + l, String(k || "auto")); } catch (e) {} }

  function cleanSpeech(raw, lang) {
    var s = String(raw || "");
    if (!s) return "";
    s = s.replace(/<[^>]+>/g, " ").replace(/https?:\/\/\S+/gi, " ").replace(/[\*\#\_`~>\[\]]+/g, " ");
    s = s.replace(/\s*\|\s*/g, ". ").replace(/[\u2022\u25aa\u25ba\u25b8\u2756\u25cf\u25cb\u25c6\u25c7\u2713\u2714\u2192\u21d2\u2014\u2013]+/g, ", ");
    if (lang === "en") {
      s = s.replace(/\bsallent\b/gi, "salient")
           .replace(/\bSecs?\.\s*/gi, "Section ").replace(/\bArts?\.\s*/gi, "Article ")
           .replace(/\bu\/s\b/gi, "under Section").replace(/\bw\.e\.f\./gi, "with effect from")
           .replace(/\bi\.e\./gi, "that is").replace(/\be\.g\./gi, "for example")
           .replace(/\betc\./gi, "and so on").replace(/\bvs?\.\s+/gi, " versus ")
           .replace(/\bIPC\b/g, "I P C").replace(/\bCrPC\b/g, "C R P C").replace(/\bCPC\b/g, "C P C")
           .replace(/\bBNS\b/g, "B N S").replace(/\bBNSS\b/g, "B N S S").replace(/\bBSA\b/g, "B S A")
           .replace(/\bAIR\b/g, "A I R").replace(/\bSCC\b/g, "S C C").replace(/\bPIL\b/g, "P I L").replace(/\bFIR\b/g, "F I R");
    }
    return s.replace(/\s*([,\.;:\?!\u0964])\s*/g, "$1 ").replace(/\.{2,}/g, ".").replace(/\s+/g, " ").trim();
  }

  function splitFluent(text, maxLen) {
    var lim = maxLen || 185, s = String(text || "").trim();
    if (!s) return [];
    if (s.length <= lim) return [s];
    var parts = s.match(/[^\.\?!\u0964]+[\.\?!\u0964]*/g) || [s], out = [];
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i].trim();
      if (!p) continue;
      if (p.length <= lim) { out.push(p); continue; }
      var cls = p.match(/[^,;:]+[,;:]*/g) || [p], buf = "";
      for (var j = 0; j < cls.length; j++) {
        var c = cls[j].trim();
        if (!c) continue;
        if ((buf + " " + c).trim().length <= lim) { buf = (buf ? buf + " " : "") + c; }
        else {
          if (buf) out.push(buf);
          if (c.length <= lim) { buf = c; }
          else {
            var ws = c.split(/\s+/), wb = "";
            for (var k = 0; k < ws.length; k++) {
              if ((wb + " " + ws[k]).trim().length <= lim) wb = (wb ? wb + " " : "") + ws[k];
              else { if (wb) out.push(wb); wb = ws[k]; }
            }
            buf = wb;
          }
        }
      }
      if (buf) out.push(buf);
    }
    return out.filter(function (x) { return x && x.length > 1; });
  }

  function metaSafe(tid) { try { return typeof findTopicMeta === "function" ? findTopicMeta(tid) : null; } catch (e) { return null; } }

  function buildTopicQueue(tid, lang, asProf) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return [];
    var ld = rec[lang] || rec.en; if (!ld) return [];
    var m = metaSafe(tid), title = (m && m.topic && m.topic.title) ? m.topic.title : String(tid).replace(/-/g, " ");
    var ct = cleanSpeech(title, lang), m1 = cleanSpeech(ld.inOneMinute, lang), pr = cleanSpeech(ld.legalProvision, lang), mn = cleanSpeech(ld.meaning, lang);
    var pts = Array.isArray(ld.keyPoints) ? ld.keyPoints.map(function (x) { return cleanSpeech(typeof x === "string" ? x : (x && (x.point || x.text || x.summary)), lang); }).filter(Boolean) : [];
    var cs = Array.isArray(ld.caseLaws) ? ld.caseLaws.slice(0, 3).map(function (c) {
      if (typeof c === "string") return cleanSpeech(c, lang);
      if (!c) return "";
      var n = cleanSpeech(c.name || c.title, lang), p = cleanSpeech(c.principle || c.summary, lang);
      return (n && p) ? (n + ". " + p) : (n || p);
    }).filter(Boolean) : [];

    var blks = [];
    if (lang === "te") {
      if (asProf) {
        blks.push({ step: 0, text: "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d. \u0c08\u0c30\u0c4b\u0c1c\u0c41 \u0c2e\u0c28\u0c02 " + ct + " \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c38\u0c41\u0c32\u0c2d\u0c02\u0c17\u0c3e \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c1a\u0c47\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02." });
        if (m1) blks.push({ step: 1, text: "\u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b \u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c35\u0c3f\u0c37\u0c2f\u0c02 \u0c24\u0c46\u0c32\u0c41\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02. " + m1 });
        if (pr) blks.push({ step: 2, text: "\u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d\u200c\u0c32\u0c4b \u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c30\u0c3e\u0c2f\u0c3e\u0c32\u0c4d\u0c38\u0c3f\u0c28 \u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28 \u0c07\u0c26\u0c3f. " + pr });
        if (mn) blks.push({ step: 3, text: "\u0c07\u0c2a\u0c4d\u0c2a\u0c41\u0c21\u0c41 \u0c26\u0c40\u0c28\u0c3f \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c38\u0c4d\u0c2a\u0c37\u0c4d\u0c1f\u0c02\u0c17\u0c3e \u0c1a\u0c42\u0c26\u0c4d\u0c26\u0c3e\u0c02. " + mn });
        if (pts.length) {
          blks.push({ step: 4, text: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41 \u0c12\u0c15\u0c4d\u0c15\u0c4a\u0c15\u0c4d\u0c15\u0c1f\u0c3f\u0c17\u0c3e \u0c17\u0c2e\u0c28\u0c3f\u0c02\u0c1a\u0c02\u0c21\u0c3f." });
          pts.forEach(function (p, i) { blks.push({ step: 4, text: "\u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d " + (i + 1) + ". " + p }); });
        }
        if (cs.length) blks.push({ step: 5, text: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41 \u0c32\u0c3e \u0c17\u0c41\u0c30\u0c4d\u0c24\u0c41\u0c2a\u0c46\u0c1f\u0c4d\u0c1f\u0c41\u0c15\u0c4b\u0c02\u0c21\u0c3f. " + cs.join(". ") });
      } else {
        blks.push({ step: 0, text: ct }); if (m1) blks.push({ step: 1, text: m1 }); if (pr) blks.push({ step: 2, text: pr });
        if (mn) blks.push({ step: 3, text: mn }); pts.forEach(function (p) { blks.push({ step: 4, text: p }); }); cs.forEach(function (c) { blks.push({ step: 5, text: c }); });
      }
    } else if (lang === "hi") {
      if (asProf) {
        blks.push({ step: 0, text: "\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938\u0964 \u0906\u091c \u0939\u092e " + ct + " \u0915\u094b \u0906\u0938\u093e\u0928 \u0914\u0930 \u0938\u094d\u092a\u0937\u094d\u091f \u092d\u093e\u0937\u093e \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964" });
        if (m1) blks.push({ step: 1, text: "\u0938\u092c\u0938\u0947 \u092a\u0939\u0932\u0947 \u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902 \u0907\u0938\u0915\u093e \u092e\u0941\u0916\u094d\u092f \u0938\u093e\u0930 \u0938\u092e\u091d\u093f\u090f\u0964 " + m1 });
        if (pr) blks.push({ step: 2, text: "\u090f\u0917\u094d\u091c\u093e\u092e \u092e\u0947\u0902 \u0938\u092c\u0938\u0947 \u092a\u0939\u0932\u0947 \u092f\u0939 \u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928 \u0932\u093f\u0916\u093f\u090f\u0964 " + pr });
        if (mn) blks.push({ step: 3, text: "\u0905\u092c \u0907\u0938\u0915\u093e \u0938\u0930\u0932 \u0905\u0930\u094d\u0925 \u0938\u092e\u091d\u0924\u0947 \u0939\u0948\u0902\u0964 " + mn });
        if (pts.length) {
          blks.push({ step: 4, text: "\u0905\u092c \u090f\u0915 \u090f\u0915 \u0915\u0930\u0915\u0947 \u092e\u0941\u0916\u094d\u092f \u092a\u0949\u0907\u0902\u091f\u094d\u0938 \u0927\u094d\u092f\u093e\u0928 \u0938\u0947 \u0938\u0941\u0928\u093f\u090f\u0964" });
          pts.forEach(function (p, i) { blks.push({ step: 4, text: "\u092a\u0949\u0907\u0902\u091f " + (i + 1) + "\u0964 " + p }); });
        }
        if (cs.length) blks.push({ step: 5, text: "\u0907\u0938 \u0935\u093f\u0937\u092f \u0915\u093e \u092a\u094d\u0930\u092e\u0941\u0916 \u0915\u0947\u0938 \u0932\u0949 \u092f\u093e\u0926 \u0930\u0916\u093f\u090f\u0964 " + cs.join("\u0964 ") });
      } else {
        blks.push({ step: 0, text: ct }); if (m1) blks.push({ step: 1, text: m1 }); if (pr) blks.push({ step: 2, text: pr });
        if (mn) blks.push({ step: 3, text: mn }); pts.forEach(function (p) { blks.push({ step: 4, text: p }); }); cs.forEach(function (c) { blks.push({ step: 5, text: c }); });
      }
    } else {
      if (asProf) {
        blks.push({ step: 0, text: "Hello students. Today let us clearly understand " + ct + "." });
        if (m1) blks.push({ step: 1, text: "First, here is the core idea in plain words. " + m1 });
        if (pr) blks.push({ step: 2, text: "For your exam answer, start with this exact legal provision. " + pr });
        if (mn) blks.push({ step: 3, text: "Let us look at what this means. " + mn });
        if (pts.length) {
          blks.push({ step: 4, text: "Now listen carefully to the key scoring points." });
          pts.forEach(function (p, i) { blks.push({ step: 4, text: "Point " + (i + 1) + ". " + p }); });
        }
        if (cs.length) blks.push({ step: 5, text: "Be sure to quote this landmark case law in your answer. " + cs.join(". ") });
      } else {
        blks.push({ step: 0, text: ct }); if (m1) blks.push({ step: 1, text: m1 }); if (pr) blks.push({ step: 2, text: pr });
        if (mn) blks.push({ step: 3, text: mn }); pts.forEach(function (p) { blks.push({ step: 4, text: p }); }); cs.forEach(function (c) { blks.push({ step: 5, text: c }); });
      }
    }

    var out = [];
    for (var b = 0; b < blks.length; b++) {
      var chs = splitFluent(blks[b].text, 185);
      for (var s = 0; s < chs.length; s++) out.push({ topicId: tid, topicTitle: title, lang: lang, stepIdx: blks[b].step, text: chs[s] });
    }
    return out;
  }

  async function loadManifest() {
    if (manifest !== null) return manifest;
    manifest = {};
    try { var r = await fetch("./audio/manifest.json", { cache: "no-store" }); if (r.ok) manifest = await r.json(); } catch (e) {}
    return manifest;
  }

  function curatedVoices(lang) {
    var bcp = bcp47(lang), svc = nativeSvc(), raw = [];
    if (svc && typeof svc.getVoicesForLang === "function") {
      try { raw = JSON.parse(svc.getVoicesForLang(bcp) || "[]"); } catch (e) { raw = []; }
    } else if ("speechSynthesis" in window) {
      raw = webVoices;
    }
    var tgt = bcp.toLowerCase(), pref = tgt.split("-")[0], all = [];
    for (var i = 0; i < raw.length; i++) {
      var v = raw[i], vl = String((v && v.lang) || "").toLowerCase().replace("_", "-");
      if (vl.indexOf("ar") === 0) continue;
      if (vl !== tgt && vl.indexOf(pref + "-") !== 0 && vl !== pref) continue;
      var rn = String((v && (v.name || v.voiceURI)) || ("Voice " + i));
      var sc = (vl === tgt ? 200 : 80) + (/network|neural|natural|wavenet|online/i.test(rn) ? 80 : 0) + (/google|neerja|prabhat|shruti|mohan|swara|madhur/i.test(rn) ? 50 : 0);
      var isNet = /network|neural|natural|wavenet|online/i.test(rn) || (v.localService === false);
      var isMale = /prabhat|mohan|madhur|ravi|hemant|male|\-e\-|\-d\-|en\-in\-x\-ene|te\-in\-x\-tem|hi\-in\-x\-hid/i.test(rn);
      var isFem = /neerja|shruti|swara|heera|kalpana|veena|lekha|female|en\-in\-x\-ena|en\-in\-x\-enc|te\-in\-x\-tef|hi\-in\-x\-hia/i.test(rn);
      all.push({ key: rn, voice: v, score: sc, isNet: isNet, isMale: isMale, isFem: isFem });
    }
    all.sort(function (a, b) { return b.score - a.score; });

    var picked = [], used = {};
    function add(it, lbl) { if (!it || used[it.key]) return; used[it.key] = true; picked.push({ key: it.key, voice: it.voice, name: lbl }); }
    add(all.filter(function (x) { return x.isFem; })[0] || all[0], "Indian Female (Clear)");
    add(all.filter(function (x) { return x.isMale && !used[x.key]; })[0], "Indian Male (Clear)");
    add(all.filter(function (x) { return x.isNet && !used[x.key]; })[0], "Indian HD Online Voice");
    add(all.filter(function (x) { return !x.isNet && !used[x.key]; })[0], "Indian Offline Voice");
    for (var k = 0; k < all.length && picked.length < 3; k++) add(all[k], "Indian Voice " + (picked.length + 1));
    return picked;
  }

  function removeDeadDropdowns() {
    var host = document.getElementById("lsPwVoiceHost");
    if (host) host.querySelectorAll("select").forEach(function (s) { if (s.id !== "audioVoiceSelect") s.remove(); });
    var modal = document.getElementById("lsPlayerWindowModal");
    if (modal) modal.querySelectorAll("select").forEach(function (s) { if (s.id !== "audioVoiceSelect" && s.id !== "audioSpeedSelect" && s.id !== "sleepTimerSelect") s.remove(); });
  }

  function updateHint() {
    var h = document.getElementById("lsPwVoiceActiveHint");
    if (h) h.textContent = curVoiceLbl + " (" + speed.toFixed(2).replace(/\.00$/, "") + "x)";
  }

  function populateVoices() {
    removeDeadDropdowns();
    var sel = document.getElementById("audioVoiceSelect");
    if (!sel) return;
    var lang = langNow(), bcp = bcp47(lang), tid = (typeof state !== "undefined" && state.activeTopicId) ? state.activeTopicId : curTopicId;
    var list = curatedVoices(lang), saved = getSavedVc(lang), opts = [];
    if (manifest && manifest[lang] && manifest[lang][tid]) opts.push({ v: "studio-mp3", l: "HD Studio Human Voice (MP3)" });
    opts.push({ v: "auto", l: "Auto Best Indian Voice (" + bcp + ")" });
    for (var i = 0; i < list.length; i++) opts.push({ v: list[i].key, l: list[i].name });
    sel.innerHTML = "";
    var hit = false;
    opts.forEach(function (o) {
      var op = document.createElement("option"); op.value = o.v; op.textContent = o.l;
      if (o.v === saved) { op.selected = true; hit = true; }
      sel.appendChild(op);
    });
    if (!hit && sel.options.length) sel.selectedIndex = 0;
    var found = list.filter(function (x) { return x.key === saved; })[0];
    curVoiceLbl = saved === "studio-mp3" ? "HD Studio Human Voice (MP3)" : (found ? found.name : "Auto Best Indian Voice");
    updateHint();
  }

  function stopHardware() {
    if (htmlAudio) { try { htmlAudio.pause(); htmlAudio.currentTime = 0; } catch (e) {} htmlAudio = null; }
    var svc = nativeSvc();
    if (svc) { try { svc.stop(); } catch (e) {} }
    if ("speechSynthesis" in window) { try { window.speechSynthesis.cancel(); } catch (e) {} }
  }

  function stop() {
    token++; playing = false; paused = false; studioMp3 = false;
    if (sleepId) { clearTimeout(sleepId); sleepId = null; }
    stopHardware(); emitState();
  }

  async function tryMp3(tid, lang, tk) {
    await loadManifest();
    var rel = (manifest && manifest[lang] && manifest[lang][tid]) ? manifest[lang][tid] : null;
    if (!rel) return false;
    var urls = [rel, CDN + "/" + rel.replace(/^\.\//, "")];
    for (var i = 0; i < urls.length; i++) {
      try {
        var u = urls[i], playUrl = u;
        if ("caches" in window) {
          var c = await caches.open(AUDIO_CACHE), hit = await c.match(u);
          if (hit) playUrl = URL.createObjectURL(await hit.blob());
          else {
            var resp = await fetch(u); if (!resp.ok) continue;
            try { c.put(u, resp.clone()); } catch (e) {}
            playUrl = URL.createObjectURL(await resp.blob());
          }
        }
        if (tk !== token) return true;
        htmlAudio = new Audio(playUrl);
        htmlAudio.playbackRate = speed;
        htmlAudio.ontimeupdate = function () {
          if (tk !== token || !htmlAudio || !htmlAudio.duration) return;
          var b = document.getElementById("audioProgressBar");
          if (b) b.style.width = Math.min(100, Math.round((htmlAudio.currentTime / htmlAudio.duration) * 100)) + "%";
        };
        htmlAudio.onended = function () {
          if (tk !== token) return;
          if (repeat) { htmlAudio.currentTime = 0; htmlAudio.play().catch(function () {}); return; }
          playing = false; paused = false; studioMp3 = false; emitState();
        };
        await htmlAudio.play();
        playing = true; paused = false; studioMp3 = true;
        curVoiceLbl = "HD Studio Human Voice (MP3)"; updateHint(); emitState();
        return true;
      } catch (e) {}
    }
    return false;
  }

  async function runWebQueue(idx) {
    var tk = ++token; stopHardware();
    if (!queue.length) { playing = false; paused = false; emitState(); return; }
    curIdx = Math.max(0, Math.min(idx, queue.length - 1));
    var lang = queue[curIdx].lang, saved = getSavedVc(lang);
    var list = curatedVoices(lang);
    var chosen = list.filter(function (x) { return x.key === saved; })[0] || list[0] || null;
    curVoiceLbl = chosen ? chosen.name : ("System " + bcp47(lang));
    updateHint();
    playing = true; paused = false; studioMp3 = false;

    for (var i = curIdx; i < queue.length; i++) {
      if (tk !== token) return;
      curIdx = i; curTopicId = queue[i].topicId; curTitle = queue[i].topicTitle; curCaption = queue[i].text; curStepIdx = queue[i].stepIdx;
      emitState();
      await new Promise(function (resolve) {
        var finFlag = false; function fin() { if (!finFlag) { finFlag = true; resolve(); } }
        try {
          var u = new SpeechSynthesisUtterance(queue[i].text);
          u.lang = bcp47(queue[i].lang); u.rate = speed; u.pitch = 1.0;
          if (chosen && chosen.voice) u.voice = chosen.voice;
          u.onend = fin; u.onerror = fin;
          window.speechSynthesis.speak(u);
          setTimeout(fin, Math.max(9000, Math.round((queue[i].text.length * 145) / Math.max(0.6, speed))));
        } catch (e) { fin(); }
      });
      if (tk !== token) return;
      await new Promise(function (r) { setTimeout(r, 200); });
    }
    if (tk === token) {
      if (repeat && scope === "topic") { runWebQueue(0); return; }
      playing = false; paused = false; emitState();
    }
  }

  async function startQueue(startIdx) {
    if (!queue.length) return;
    var tk = ++token;
    stopHardware();
    curIdx = Math.max(0, Math.min(startIdx || 0, queue.length - 1));
    var first = queue[curIdx], lang = first.lang, saved = getSavedVc(lang);

    if (scope === "topic" && curIdx === 0 && saved === "studio-mp3") {
      if (await tryMp3(first.topicId, lang, tk)) return;
    }

    var svc = nativeSvc();
    if (svc) {
      playing = true; paused = false; studioMp3 = false;
      curTopicId = first.topicId; curTitle = first.topicTitle; curCaption = first.text; curStepIdx = first.stepIdx;
      var vName = (saved && saved !== "auto" && saved !== "studio-mp3") ? saved : "";
      svc.playQueue(JSON.stringify(queue), bcp47(lang), speed, vName, curIdx, repeat);
      emitState();
      return;
    }

    runWebQueue(curIdx);
  }

  window.__lsOnNativeAudioState = function (jsonStr) {
    try {
      var s = JSON.parse(jsonStr || "{}");
      playing = !!s.playing;
      paused = !!s.paused;
      if (typeof s.index === "number") curIdx = s.index;
      if (s.title) curTitle = s.title;
      if (s.caption !== undefined) curCaption = s.caption;
      if (s.topicId) curTopicId = s.topicId;
      if (typeof s.stepIdx === "number") curStepIdx = s.stepIdx;
      emitState();
    } catch (e) {}
  };

  function playTopic(tid, forceProf) {
    var id = tid || (typeof state !== "undefined" && state.activeTopicId) || curTopicId;
    if (!id) { if (typeof showToast === "function") showToast("Open any topic first to listen."); return; }
    if (typeof forceProf === "boolean") { teachMode = forceProf; try { localStorage.setItem(K_TCH, teachMode ? "1" : "0"); } catch (e) {} }
    populateVoices();
    var items = buildTopicQueue(id, langNow(), teachMode);
    if (!items.length) return;
    scope = "topic"; queue = items; curIdx = 0; curTopicId = id; curTitle = items[0].topicTitle;
    startQueue(0);
  }

  function playUnit(tid) {
    var id = tid || (typeof state !== "undefined" && state.activeTopicId) || curTopicId;
    if (!id) return;
    var m = metaSafe(id);
    if (!m || !m.unit || !Array.isArray(m.unit.topics) || !m.unit.topics.length) { playTopic(id); return; }
    populateVoices();
    var all = [], lang = langNow();
    m.unit.topics.forEach(function (t) { if (t && t.id) all = all.concat(buildTopicQueue(t.id, lang, teachMode)); });
    if (!all.length) return;
    scope = "unit"; queue = all; curIdx = 0; curTopicId = all[0].topicId; curTitle = all[0].topicTitle;
    startQueue(0);
  }

  function pause() {
    if (!playing || paused) return;
    paused = true;
    var svc = nativeSvc();
    if (studioMp3 && htmlAudio) { try { htmlAudio.pause(); } catch (e) {} }
    else if (svc) { svc.pause(); }
    else { token++; stopHardware(); }
    emitState();
  }

  function resume() {
    if (!playing || !paused) return;
    paused = false;
    var svc = nativeSvc();
    if (studioMp3 && htmlAudio) { htmlAudio.playbackRate = speed; htmlAudio.play().catch(function () {}); emitState(); }
    else if (svc) { svc.resume(); emitState(); }
    else runWebQueue(curIdx);
  }

  function togglePlay() { if (playing && !paused) pause(); else if (playing && paused) resume(); else playTopic(); }
  function prev() {
    if (studioMp3 && htmlAudio) { htmlAudio.currentTime = Math.max(0, htmlAudio.currentTime - 10); return; }
    var svc = nativeSvc(); if (svc && playing) { svc.prev(); return; }
    if (queue.length) startQueue(Math.max(0, curIdx - 1));
  }
  function next() {
    if (studioMp3 && htmlAudio && htmlAudio.duration) { htmlAudio.currentTime = Math.min(htmlAudio.duration - 0.5, htmlAudio.currentTime + 10); return; }
    var svc = nativeSvc(); if (svc && playing) { svc.next(); return; }
    if (queue.length) startQueue(Math.min(queue.length - 1, curIdx + 1));
  }

  function setSpeed(val) {
    var r = parseFloat(val); if (!isFinite(r) || r < 0.6 || r > 1.8) return;
    speed = r; try { localStorage.setItem(K_SPD, String(speed)); } catch (e) {}
    updateHint();
    var svc = nativeSvc();
    if (playing && !paused) {
      if (studioMp3 && htmlAudio) htmlAudio.playbackRate = speed;
      else if (svc) svc.setSpeed(speed);
      else runWebQueue(curIdx);
    }
    emitState();
  }

  function toggleTeach() {
    teachMode = !teachMode; try { localStorage.setItem(K_TCH, teachMode ? "1" : "0"); } catch (e) {}
    if (typeof showToast === "function") showToast(teachMode ? "Indian Professor Style ON" : "Direct Notes Reading ON");
    if (playing && !paused) { if (scope === "unit") playUnit(curTopicId); else playTopic(curTopicId); } else emitState();
  }

  function toggleRepeat() {
    repeat = !repeat; try { localStorage.setItem(K_REP, repeat ? "1" : "0"); } catch (e) {}
    if (typeof showToast === "function") showToast(repeat ? "Loop Topic ON" : "Loop Topic OFF");
    emitState();
  }

  function setSleep(mins) {
    if (sleepId) { clearTimeout(sleepId); sleepId = null; }
    var m = parseInt(mins, 10) || 0;
    if (m > 0) {
      sleepId = setTimeout(function () { stop(); if (typeof showToast === "function") showToast("Sleep timer ended audio."); }, m * 60000);
      if (typeof showToast === "function") showToast("Sleep timer: " + m + " min");
    }
  }

  function testVoice() {
    var lang = langNow();
    var txt = lang === "te"
      ? "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d. \u0c07\u0c26\u0c3f \u0c32\u0c3e \u0c38\u0c4d\u0c1f\u0c21\u0c40\u0c38\u0c4d \u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c35\u0c3e\u0c2f\u0c3f\u0c38\u0c4d."
      : (lang === "hi"
        ? "\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938\u0964 \u092f\u0939 \u0932\u0949 \u0938\u094d\u091f\u0921\u0940\u091c\u093c \u0915\u0940 \u0939\u093f\u0902\u0926\u0940 \u0906\u0935\u093e\u091c\u093c \u0939\u0948\u0964"
        : "Hello students. Testing your selected Law Studyes voice.");
    if (typeof showToast === "function") showToast("Testing: " + curVoiceLbl);
    queue = [{ topicId: curTopicId || "test", topicTitle: "Voice Test", lang: lang, stepIdx: 0, text: txt }];
    scope = "topic";
    startQueue(0);
  }

  function getState() {
    var tot = queue.length || 0, pct = tot ? Math.round(((curIdx + 1) / tot) * 100) : 0;
    return {
      playing: playing, isPlaying: playing && !paused, paused: paused, topicId: curTopicId,
      title: curTitle || "Select a Topic to Listen", topicTitle: curTitle || "Select a Topic to Listen",
      caption: studioMp3 ? "Playing HD Studio Human Voice (MP3)" : curCaption,
      currentText: studioMp3 ? "Playing HD Studio Human Voice (MP3)" : curCaption,
      stepIdx: curStepIdx, index: curIdx, currentIndex: curIdx, total: tot, progress: pct, percent: pct,
      scope: scope, teachingMode: teachMode, repeat: repeat, speed: speed, lang: langNow(), voiceName: curVoiceLbl, studioMp3: studioMp3
    };
  }

  function emitState() {
    var st = getState(), el;
    if ((el = document.getElementById("audioCurrentTitle"))) el.textContent = st.title;
    if ((el = document.getElementById("audioModeBadge"))) el.textContent = st.studioMp3 ? "HD Studio MP3" : (st.teachingMode ? "Indian Professor" : "Direct Notes");
    if ((el = document.getElementById("audioQueueCounter"))) el.textContent = st.total ? ((st.index + 1) + " / " + st.total) : "Ready";
    if ((el = document.getElementById("liveCaptionStrip"))) { el.textContent = st.caption || "Tap Play to start Audio"; el.classList.remove("hidden"); }
    if ((el = document.getElementById("audioProgressBar")) && !st.studioMp3) el.style.width = st.percent + "%";
    if ((el = document.getElementById("audioPlayPauseBtn"))) { el.textContent = (st.playing && !st.paused) ? "Pause" : (st.paused ? "Resume" : "Play"); }
    if ((el = document.getElementById("teachingModeBtn"))) { el.textContent = st.teachingMode ? "Professor Mode: ON" : "Direct Notes: ON"; el.classList.toggle("active", st.teachingMode); }
    if ((el = document.getElementById("repeatTopicBtn"))) { el.textContent = st.repeat ? "Loop: ON" : "Loop: OFF"; el.classList.toggle("active", st.repeat); }
    if ((el = document.getElementById("lsMiniTitle"))) el.textContent = st.title;
    if ((el = document.getElementById("lsMiniSub"))) el.textContent = (st.playing && !st.paused) ? (st.voiceName + " - " + st.percent + "%") : (st.paused ? "Paused" : "Tap to open Audio Player");
    if ((el = document.getElementById("lsMiniPulse"))) el.style.display = (st.playing && !st.paused) ? "block" : "none";
    try { window.dispatchEvent(new CustomEvent("ls:audio-state", { detail: st })); } catch (e) {}
  }

  function cleanClone(id) {
    var el = document.getElementById(id);
    if (!el || el.__lsClean325) return el;
    var c = el.cloneNode(true); c.__lsClean325 = true;
    if (el.parentNode) el.parentNode.replaceChild(c, el);
    return c;
  }

  function bindControls() {
    removeDeadDropdowns();
    var b;
    if ((b = cleanClone("audioPlayPauseBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", togglePlay); }
    if ((b = cleanClone("audioPrevBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", prev); }
    if ((b = cleanClone("audioNextBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", next); }
    if ((b = cleanClone("audioStopBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", stop); }
    if ((b = cleanClone("teachingModeBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", toggleTeach); }
    if ((b = cleanClone("repeatTopicBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", toggleRepeat); }
    if ((b = cleanClone("sleepTimerSelect")) && !b.__w) { b.__w = true; b.addEventListener("change", function () { setSleep(b.value); }); }
    if ((b = cleanClone("audioSpeedSelect")) && !b.__w) {
      b.__w = true;
      b.innerHTML = '<option value="0.8">0.8x (Slow)</option><option value="0.98">1.0x (Natural)</option><option value="1.15">1.15x (Brisk)</option><option value="1.3">1.3x (Revision)</option>';
      b.value = String(speed); if (b.selectedIndex === -1) b.value = "0.98";
      b.addEventListener("change", function () { setSpeed(b.value); });
    }
    var vcSel = cleanClone("audioVoiceSelect");
    if (vcSel && !vcSel.__w) {
      vcSel.__w = true;
      vcSel.addEventListener("change", function () {
        var l = langNow(); setSavedVc(l, vcSel.value);
        populateVoices();
        if (typeof showToast === "function") showToast("Voice: " + curVoiceLbl);
        var svc = nativeSvc();
        if (playing && !paused) {
          if (vcSel.value === "studio-mp3") startQueue(0);
          else if (svc) svc.setVoice(vcSel.value === "auto" ? "" : vcSel.value);
          else runWebQueue(curIdx);
        }
        emitState();
      });
    }
    var vcHost = document.getElementById("lsPwVoiceHost");
    if (vcHost) {
      var oldR = document.getElementById("lsPwVoiceActionRow");
      if (oldR && !oldR.__v325) oldR.remove();
      if (!document.getElementById("lsPwVoiceActionRow")) {
        var row = document.createElement("div"); row.id = "lsPwVoiceActionRow"; row.__v325 = true;
        row.style.cssText = "display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:6px;";
        row.innerHTML = '<span id="lsPwVoiceActiveHint" style="font-size:11px;font-weight:700;color:#7B1E2B;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"></span>' +
          '<button type="button" id="lsPwTestVoiceBtn" style="padding:5px 11px;border-radius:8px;border:1px solid #7B1E2B;background:#7B1E2B;color:#FFF;font-size:11px;font-weight:800;cursor:pointer;flex-shrink:0;">Test Voice</button>';
        vcHost.appendChild(row);
        row.querySelector("#lsPwTestVoiceBtn").addEventListener("click", testVoice);
      }
    }
    populateVoices(); emitState();
  }

  window.LSAudioEngine = {
    playTopic: playTopic, playUnit: playUnit, play: togglePlay, pause: pause, resume: resume, togglePlay: togglePlay,
    stop: stop, stopHardware: stopHardware, prev: prev, next: next, jumpTo: startQueue, setSpeed: setSpeed,
    toggleTeachingMode: toggleTeach, toggleRepeat: toggleRepeat, setSleepTimer: setSleep,
    testVoice: testVoice, refreshVoices: populateVoices, emitState: emitState, getState: getState
  };

  function boot() {
    loadPrefs();
    try { if ("speechSynthesis" in window) webVoices = window.speechSynthesis.getVoices() || []; } catch (e) {}
    loadManifest().then(bindControls);
  }
  if ("speechSynthesis" in window && "onvoiceschanged" in window.speechSynthesis) {
    window.speechSynthesis.onvoiceschanged = function () { webVoices = window.speechSynthesis.getVoices() || []; populateVoices(); };
  }
  window.addEventListener("ls:lang-changed", function () { stop(); populateVoices(); });
  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(boot, 250); setTimeout(bindControls, 900); setTimeout(bindControls, 1800);
    if (typeof window.renderReadingPane === "function" && !window.__lsAudHook325) {
      window.__lsAudHook325 = true;
      var orig = window.renderReadingPane;
      window.renderReadingPane = function () { var r = orig.apply(this, arguments); setTimeout(populateVoices, 60); return r; };
    }
    if (typeof MutationObserver !== "undefined" && document.body) {
      new MutationObserver(removeDeadDropdowns).observe(document.body, { childList: true, subtree: true });
    }
  });
})();
'@

$enginePath = Join-Path $modDir "ls-audio-engine.js"
[System.IO.File]::WriteAllText($enginePath, $engineJs, $u)
node --check $enginePath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in ls-audio-engine.js!" }
Write-Host "[PASS] www/js/modules/ls-audio-engine.js updated & verified (0 errors)." -ForegroundColor Green

if (-not $SkipApkBuild) {
  Write-Host "`n=== 5. Building Signed APK v$Version (with True Android Foreground TTS Service) + Updating download.html & Pushing OTA ===" -ForegroundColor Cyan
  & (Join-Path $root "Upgrade4-Bind-SmokeTest-Deploy-v3.2.0.ps1") -Version $Version -VersionCode $VersionCode -SkipWindowsExe
}