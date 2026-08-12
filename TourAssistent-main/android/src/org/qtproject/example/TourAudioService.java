package org.qtproject.example;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.IBinder;
import java.net.HttpURLConnection;
import java.net.URL;

import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicBoolean;

import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;
import android.support.v4.media.MediaMetadataCompat;
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
    private static final ArrayList<String> playlistTitles = new ArrayList<>();
    private static final ArrayList<String> playlistCovers = new ArrayList<>();
    private static String playlistTourName = "";
    private static int currentIndex = 0;

    // Cache da capa da notificação (carregada em thread de fundo — nunca na
    // thread principal do Service, ver contracts/audio-bridge-contract.md).
    private static Bitmap cachedCoverBitmap = null;
    private static int cachedCoverIndex = -1;
    private static volatile int loadingCoverIndex = -1;

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
                            // Alimenta também a bola de progresso da notificação:
                            // o sistema desenha-a a partir do PlaybackState, não
                            // da notificação em si (ver research.md §6.3).
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

    public static void setServicePlaylist(Context context, String[] urls, String[] titles,
                                           String[] covers, String tourName, int index) {
        playlist.clear();
        playlistTitles.clear();
        playlistCovers.clear();
        playlistTourName = tourName != null ? tourName : "";
        cachedCoverBitmap = null;
        cachedCoverIndex = -1;
        loadingCoverIndex = -1;

        // NOTA: ao contrário da versão anterior, URLs vazias (passos sem
        // áudio, FR-009b) são preservadas na lista em vez de filtradas —
        // removê-las desalinhava currentIndex de tudo o resto (titles,
        // covers, e o índice usado pela app/QML sobre a mesma sequência).
        if (urls != null) {
            for (String url : urls) {
                playlist.add(url != null ? url : "");
            }
        }
        if (titles != null) {
            for (String title : titles) {
                playlistTitles.add(title != null ? title : "");
            }
        }
        if (covers != null) {
            for (String cover : covers) {
                playlistCovers.add(cover != null ? cover : "");
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

                // FR-004a: um seek durante a pausa retoma automaticamente a
                // reprodução na nova posição, em vez de ficar parado.
                if (!player.isPlaying() && sInstance != null) {
                    player.start();
                    sInstance.updateForegroundNotification(true);
                    sInstance.progressHandler.removeCallbacks(sInstance.progressRunnable);
                    sInstance.progressHandler.post(sInstance.progressRunnable);
                }
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
                if (nextUrl == null || nextUrl.isEmpty()) {
                    // FR-009b: passo sem áudio associado — fica em silêncio
                    // nesse passo, sem parar o serviço/notificação.
                    silenceCurrentStep();
                } else {
                    playAudio(nextUrl);
                }
                try {
                    nativeTrackChanged(currentIndex, nextUrl != null ? nextUrl : "");
                } catch (Exception ignored) {
                }
            }

        } else if (ACTION_PREVIOUS.equals(action)) {
            if (!playlist.isEmpty() && currentIndex > 0) {
                currentIndex--;
                String prevUrl = playlist.get(currentIndex);
                currentUrl = prevUrl;
                if (prevUrl == null || prevUrl.isEmpty()) {
                    silenceCurrentStep();
                } else {
                    playAudio(prevUrl);
                }
                try {
                    nativeTrackChanged(currentIndex, prevUrl != null ? prevUrl : "");
                } catch (Exception ignored) {
                }
            }
        }
    }

    // FR-009b: usado por ACTION_NEXT/ACTION_PREVIOUS quando o passo de
    // destino não tem áudio — pausa a reprodução atual (sem libertar o
    // MediaPlayer nem chamar ACTION_STOP) e atualiza a notificação para o
    // novo passo, mantendo o serviço em segundo plano vivo.
    private void silenceCurrentStep() {
        progressHandler.removeCallbacks(progressRunnable);
        if (player != null) {
            try {
                if (player.isPlaying()) {
                    player.pause();
                }
            } catch (Exception ignored) {
            }
        }
        updateForegroundNotification(false);
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
        // A ordem importa: os metadados (duração/capa/título) têm de estar
        // publicados para o sistema saber desenhar a bola de progresso.
        updateMediaMetadata();
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

        // Tocar no corpo da notificação reabre/traz a app para primeiro
        // plano (em vez de não fazer nada, como acontecia antes).
        Intent contentIntent = new Intent(this, MuseumActivity.class);
        contentIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
        PendingIntent pContent = PendingIntent.getActivity(this, 4, contentIntent, pendingIntentFlag);

        // FR-010/FR-011/FR-012: título do passo atual + nome da tour, em vez
        // de texto fixo — mesmo conteúdo do mini-player em modo lista da app.
        String title = safeGet(playlistTitles, currentIndex, "Museum Mate");
        String tourNameText = (playlistTourName != null && !playlistTourName.isEmpty())
                ? playlistTourName
                : "Museum Mate";

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(tourNameText)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setOngoing(isPlaying)
                .setOnlyAlertOnce(true)
                .setContentIntent(pContent)
                .addAction(android.R.drawable.ic_media_previous, "Anterior", pPrev)
                .addAction(actionIcon, actionText, pPlayPause)
                .addAction(android.R.drawable.ic_media_next, "Próximo", pNext)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Parar", pStop)
                .setStyle(new androidx.media.app.NotificationCompat.MediaStyle()
                        .setShowActionsInCompactView(0, 1, 2)
                        .setMediaSession(mediaSession.getSessionToken()));

        // NOTA: a barra/bola de progresso NÃO é definida aqui. O sistema
        // desenha-a sozinho a partir da MediaSession (duração via
        // setMetadata + posição via PlaybackState), e é a única forma de a
        // obter arrastável — setProgress() é ignorado com MediaStyle, e
        // vistas personalizadas são ignoradas em Android 13+ (research.md §6.3).
        if (cachedCoverBitmap != null && cachedCoverIndex == currentIndex) {
            builder.setLargeIcon(cachedCoverBitmap);
        } else {
            requestCoverLoad(safeGet(playlistCovers, currentIndex, ""), currentIndex);
        }

        return builder.build();
    }

    // Publica na MediaSession os metadados que o Android precisa para
    // desenhar a bola/barra de progresso arrastável na notificação:
    // METADATA_KEY_DURATION é o requisito obrigatório (sem ele o sistema
    // nunca mostra scrubber nenhum), e ALBUM_ART/TITLE/ARTIST alimentam o
    // layout de media do sistema em Android 13+ (research.md §6.3).
    private void updateMediaMetadata() {
        if (mediaSession == null) {
            return;
        }

        long duration = 0;
        if (player != null) {
            try {
                int d = player.getDuration();
                if (d > 0) {
                    duration = d;
                }
            } catch (Exception ignored) {
                // Ainda não preparado — fica 0 e é republicado no onPrepared.
            }
        }

        String tourNameText = (playlistTourName != null && !playlistTourName.isEmpty())
                ? playlistTourName
                : "Museum Mate";

        MediaMetadataCompat.Builder metadata = new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE,
                        safeGet(playlistTitles, currentIndex, "Museum Mate"))
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, tourNameText)
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, tourNameText)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration);

        if (cachedCoverBitmap != null && cachedCoverIndex == currentIndex) {
            metadata.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, cachedCoverBitmap);
        }

        try {
            mediaSession.setMetadata(metadata.build());
        } catch (Exception ignored) {
        }
    }

    private static String safeGet(ArrayList<String> list, int index, String fallback) {
        if (index < 0 || index >= list.size()) {
            return fallback;
        }
        String value = list.get(index);
        return (value == null || value.isEmpty()) ? fallback : value;
    }

    // FR-010: carrega a capa do passo atual numa thread de fundo — nunca na
    // thread principal do Service (research.md §4) — preferindo sempre um
    // caminho de ficheiro local já cacheado antes de qualquer pedido de rede.
    // Falha a carregar não impede o resto da notificação de atualizar.
    private void requestCoverLoad(final String coverPath, final int forIndex) {
        if (coverPath == null || coverPath.isEmpty() || forIndex == loadingCoverIndex) {
            return;
        }
        loadingCoverIndex = forIndex;

        new Thread(() -> {
            Bitmap bitmap = null;
            try {
                if (coverPath.startsWith("http://") || coverPath.startsWith("https://")) {
                    HttpURLConnection connection = (HttpURLConnection) new URL(coverPath).openConnection();
                    connection.setConnectTimeout(5000);
                    connection.setReadTimeout(5000);
                    bitmap = BitmapFactory.decodeStream(connection.getInputStream());
                } else {
                    // FileHelper::getLocalMediaFolder (C++) devolve caminhos
                    // locais como URI "file:///..." (QUrl::fromLocalFile), não
                    // um caminho de sistema de ficheiros simples — decodeFile
                    // não entende o prefixo "file://" e falha silenciosamente
                    // se não for removido primeiro.
                    String filePath = coverPath.startsWith("file://")
                            ? Uri.parse(coverPath).getPath()
                            : coverPath;
                    bitmap = BitmapFactory.decodeFile(filePath);
                }
            } catch (Exception ignored) {
            }

            final Bitmap result = bitmap;
            progressHandler.post(() -> {
                loadingCoverIndex = -1;
                if (result != null && forIndex == currentIndex && !sCleanupDone.get()) {
                    cachedCoverBitmap = result;
                    cachedCoverIndex = forIndex;
                    updateForegroundNotification(player != null && player.isPlaying());
                }
            });
        }).start();
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