package org.qtproject.example;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.IBinder;

import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicBoolean;

import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;

public class TourAudioService extends Service {

    private static final String CHANNEL_ID = "museum_audio";
    private static final String EXTRA_AUDIO_URL = "audio_url";

    private static final String ACTION_PAUSE = "org.qtproject.example.ACTION_PAUSE";
    private static final String ACTION_PLAY = "org.qtproject.example.ACTION_PLAY";
    private static final String ACTION_STOP = "org.qtproject.example.ACTION_STOP";
    private static final String ACTION_NEXT = "org.qtproject.example.ACTION_NEXT";
    private static final String ACTION_PREVIOUS = "org.qtproject.example.ACTION_PREVIOUS";

    private static MediaPlayer player;
    private static volatile boolean sIsShuttingDown = false;
    private static final AtomicBoolean sCleanupDone = new AtomicBoolean(false);

    private String currentUrl = "";
    private MediaSessionCompat mediaSession;

    private static TourAudioService sInstance = null;
    private static final ArrayList<String> playlist = new ArrayList<>();
    private static int currentIndex = 0;

    private final android.os.Handler progressHandler =
            new android.os.Handler(android.os.Looper.getMainLooper());

            private final Runnable progressRunnable = new Runnable() {
                @Override
                public void run() {
                    if (sCleanupDone.get()) {
                        return;
                    }

                    if (player != null && player.isPlaying()) {
                        try {
                            int pos = player.getCurrentPosition();
                            int dur = player.getDuration();
                            nativePositionChanged(pos, dur);
                            updatePlaybackState(true);
                        } catch (Exception ignored) {
                        }
                        // ALTERAÇÃO AQUI: De 1000 para 250 para a bola deslizar suavemente
                        progressHandler.postDelayed(this, 250);
                    }
                }
            };;;

    private native void nativeTrackChanged(int index, String url);
    private native void nativePositionChanged(int position, int duration);

    public static void setServicePlaylist(Context context, String[] urls, int index) {
        playlist.clear();

        if (urls != null) {
            for (String url : urls) {
                if (url != null && !url.isEmpty()) {
                    playlist.add(url);
                }
            }
        }

        if (playlist.isEmpty()) {
            currentIndex = 0;
        } else {
            currentIndex = Math.max(0, Math.min(index, playlist.size() - 1));
        }
    }

    public static void seekToPosition(int msec) {
        if (player != null) {
            try {
                player.seekTo(msec);
            } catch (Exception ignored) {
            }
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {
        super.onCreate();

        sInstance = this;
        sIsShuttingDown = false;
        sCleanupDone.set(false);

        mediaSession = new MediaSessionCompat(this, "MuseumAudioSession");
        mediaSession.setActive(true);
        mediaSession.setCallback(new MediaSessionCompat.Callback() {
            @Override
            public void onPlay() {
                handleAction(ACTION_PLAY);
            }

            @Override
            public void onPause() {
                handleAction(ACTION_PAUSE);
            }

            @Override
            public void onSkipToNext() {
                handleAction(ACTION_NEXT);
            }

            @Override
            public void onSkipToPrevious() {
                handleAction(ACTION_PREVIOUS);
            }

            @Override
            public void onSeekTo(long pos) {
                seekToPosition((int) pos);
                updatePlaybackState(player != null && player.isPlaying());
            }
        });
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        createChannel();

        if (intent != null && intent.getAction() != null) {
            handleAction(intent.getAction());
            return START_NOT_STICKY;
        }

        String url = intent != null ? intent.getStringExtra(EXTRA_AUDIO_URL) : null;

        if (player != null) {
            updateForegroundNotification(player.isPlaying());
        }

        if (url != null && !url.isEmpty()) {
            currentUrl = url;
            playAudio(url);
        }

        return START_NOT_STICKY;
    }

@Override
public void onTaskRemoved(Intent rootIntent) {
    android.util.Log.e("TourAudioService", ">>> SWIPE DETETADO: Encerramento controlado e limpo.");

    try {
        if (player != null) {
            player.release();
            player = null;
        }
        if (mediaSession != null) {
            mediaSession.release();
            mediaSession = null;
        }
        cleanupPlayback();
        stopSelf();
    } catch (Exception ignored) {}

    super.onTaskRemoved(rootIntent);

    // CORREÇÃO: Removido o System.exit(0) para permitir que o ciclo de
    // destruição nativa do Qt termine sem ser interrompido abruptamente.
}

    public static boolean isShuttingDown() {
        return sIsShuttingDown;
    }

    public static void stopServiceExplicitly() {
        if (sInstance != null) {
            sInstance.handleAction(ACTION_STOP);
        }
    }

    private void handleAction(String action) {
        if (ACTION_PAUSE.equals(action)) {
            if (player != null && player.isPlaying()) {
                try {
                    player.pause();
                } catch (Exception ignored) {
                }
                updateForegroundNotification(false);
            }

        } else if (ACTION_PLAY.equals(action)) {
            if (player != null && !player.isPlaying()) {
                try {
                    player.start();
                } catch (Exception ignored) {
                }
                updateForegroundNotification(true);
                progressHandler.removeCallbacks(progressRunnable);
                progressHandler.post(progressRunnable);
            }

        } else if (ACTION_STOP.equals(action)) {
            cleanupPlayback();
            stopSelf();

        } else if (ACTION_NEXT.equals(action)) {
            if (!playlist.isEmpty() && currentIndex < playlist.size() - 1) {
                currentIndex++;
                String nextUrl = playlist.get(currentIndex);
                currentUrl = nextUrl;
                playAudio(nextUrl);
                try {
                    nativeTrackChanged(currentIndex, nextUrl);
                } catch (Exception ignored) {
                }
            }

        } else if (ACTION_PREVIOUS.equals(action)) {
            if (!playlist.isEmpty() && currentIndex > 0) {
                currentIndex--;
                String prevUrl = playlist.get(currentIndex);
                currentUrl = prevUrl;
                playAudio(prevUrl);
                try {
                    nativeTrackChanged(currentIndex, prevUrl);
                } catch (Exception ignored) {
                }
            }
        }
    }

    private void cleanupPlayback() {
        if (!sCleanupDone.compareAndSet(false, true)) {
            return;
        }

        progressHandler.removeCallbacksAndMessages(null);

        if (player != null) {
            try {
                if (player.isPlaying()) {
                    player.stop();
                }
            } catch (Exception ignored) {
            }

            try {
                player.release();
            } catch (Exception ignored) {
            }

            player = null;
        }

        if (mediaSession != null) {
            try {
                mediaSession.setActive(false);
                mediaSession.release();
            } catch (Exception ignored) {
            }
            mediaSession = null;
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE);
            } else {
                stopForeground(true);
            }
        } catch (Exception ignored) {
        }

        try {
            NotificationManager manager =
                    (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (manager != null) {
                manager.cancel(1);
            }
        } catch (Exception ignored) {
        }

        sInstance = null;
    }

    private void playAudio(String url) {
        sCleanupDone.set(false);

        try {
            if (player != null) {
                try {
                    player.stop();
                } catch (Exception ignored) {
                }
                try {
                    player.release();
                } catch (Exception ignored) {
                }
                player = null;
            }

            player = new MediaPlayer();
            player.setDataSource(url);
            player.setAudioStreamType(android.media.AudioManager.STREAM_MUSIC);

            player.setOnPreparedListener(mp -> {
                if (sCleanupDone.get()) {
                    return;
                }

                try {
                    mp.start();
                } catch (Exception ignored) {
                }

                updateForegroundNotification(true);
                progressHandler.removeCallbacks(progressRunnable);
                progressHandler.post(progressRunnable);
            });

            player.setOnCompletionListener(mp -> {
                if (sCleanupDone.get()) {
                    return;
                }

                if (!playlist.isEmpty() && currentIndex < playlist.size() - 1) {
                    handleAction(ACTION_NEXT);
                } else {
                    handleAction(ACTION_STOP);
                }
            });

            player.setOnErrorListener((mp, what, extra) -> {
                handleAction(ACTION_STOP);
                return true;
            });

            player.prepareAsync();

        } catch (Exception e) {
            e.printStackTrace();
            handleAction(ACTION_STOP);
        }
    }

    private void updateForegroundNotification(boolean isPlaying) {
        if (sCleanupDone.get()) {
            return;
        }

        Notification notification = createNotification(isPlaying);
        updatePlaybackState(isPlaying);

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                        1,
                        notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                );
            } else {
                startForeground(1, notification);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void updatePlaybackState(boolean isPlaying) {
        if (mediaSession == null) {
            return;
        }

        long actions = PlaybackStateCompat.ACTION_PLAY |
                PlaybackStateCompat.ACTION_PAUSE |
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT |
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS |
                PlaybackStateCompat.ACTION_SEEK_TO |
                PlaybackStateCompat.ACTION_STOP;

        int state = isPlaying ? PlaybackStateCompat.STATE_PLAYING : PlaybackStateCompat.STATE_PAUSED;
        long position = (player != null) ? player.getCurrentPosition() : 0;
        float speed = isPlaying ? 1.0f : 0.0f;

        PlaybackStateCompat playbackState = new PlaybackStateCompat.Builder()
                .setActions(actions)
                .setState(state, position, speed)
                .build();

        mediaSession.setPlaybackState(playbackState);
    }

    private Notification createNotification(boolean isPlaying) {
        int pendingIntentFlag = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                : PendingIntent.FLAG_UPDATE_CURRENT;

        Intent stopIntent = new Intent(this, TourAudioService.class).setAction(ACTION_STOP);
        PendingIntent pStop = PendingIntent.getService(this, 0, stopIntent, pendingIntentFlag);

        Intent nextIntent = new Intent(this, TourAudioService.class).setAction(ACTION_NEXT);
        PendingIntent pNext = PendingIntent.getService(this, 1, nextIntent, pendingIntentFlag);

        Intent prevIntent = new Intent(this, TourAudioService.class).setAction(ACTION_PREVIOUS);
        PendingIntent pPrev = PendingIntent.getService(this, 2, prevIntent, pendingIntentFlag);

        Intent playPauseIntent = new Intent(this, TourAudioService.class);
        PendingIntent pPlayPause;
        String actionText;
        int actionIcon;

        if (isPlaying) {
            playPauseIntent.setAction(ACTION_PAUSE);
            actionText = "Pausar";
            actionIcon = android.R.drawable.ic_media_pause;
        } else {
            playPauseIntent.setAction(ACTION_PLAY);
            actionText = "Reproduzir";
            actionIcon = android.R.drawable.ic_media_play;
        }

        pPlayPause = PendingIntent.getService(this, 3, playPauseIntent, pendingIntentFlag);

        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Museum Mate")
                .setContentText(isPlaying ? "Audio Tour ativo" : "Áudio em pausa")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setOngoing(isPlaying)
                .setOnlyAlertOnce(true)
                .addAction(android.R.drawable.ic_media_previous, "Anterior", pPrev)
                .addAction(actionIcon, actionText, pPlayPause)
                .addAction(android.R.drawable.ic_media_next, "Próximo", pNext)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Parar", pStop)
                .setStyle(new androidx.media.app.NotificationCompat.MediaStyle()
                        .setShowActionsInCompactView(0, 1, 2)
                        .setMediaSession(mediaSession.getSessionToken()))
                .build();
    }

    private void createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "Museum Audio",
                    NotificationManager.IMPORTANCE_LOW
            );

            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    public static void startService(Context context, String url) {
        if (context == null || url == null || url.isEmpty()) {
            return;
        }

        Intent intent = new Intent(context, TourAudioService.class);
        intent.putExtra(EXTRA_AUDIO_URL, url);
        ContextCompat.startForegroundService(context, intent);
    }

    public static void stopService(Context context) {
        stopServiceExplicitly();

        if (context != null) {
            try {
                context.stopService(new Intent(context, TourAudioService.class));
            } catch (Exception ignored) {
            }
        }
    }

public static void pauseAudio(Context context) {
        if (sInstance != null) {
            sInstance.handleAction(ACTION_PAUSE);
        }
    }

    public static void resumeAudio(Context context) {
        if (sInstance != null) {
            sInstance.handleAction(ACTION_PLAY);
        }
    }

@Override
public void onDestroy() {
    android.util.Log.e("MUSEUM", "SERVICE DESTROY");

    cleanupPlayback();

    super.onDestroy();
}
}