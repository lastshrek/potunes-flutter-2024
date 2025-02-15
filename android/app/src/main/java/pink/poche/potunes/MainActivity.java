package pink.poche.potunes;

import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;
import android.content.Intent;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.embedding.engine.FlutterEngine;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import java.util.HashMap;
import java.util.Map;
import android.view.KeyEvent;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import java.net.URL;
import java.net.HttpURLConnection;
import java.io.InputStream;
import android.os.AsyncTask;
import android.util.LruCache;
import android.graphics.Bitmap.CompressFormat;
import android.graphics.Matrix;
import java.io.ByteArrayOutputStream;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.os.Build;
import androidx.core.app.NotificationCompat;
import android.support.v4.media.session.MediaControllerCompat;
import androidx.media.app.NotificationCompat.MediaStyle;
import androidx.core.app.ComponentActivity;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterFragmentActivity {
  private static final String TAG = "PoTunes";
  private static final String CHANNEL = "pink.poche.potunes/audio_control";
  private static final String CHANNEL_ID = "pink.poche.potunes.media_channel";
  private static final int NOTIFICATION_ID = 1;
  private MethodChannel channel;
  private MediaSessionCompat mediaSession;
  private String currentCoverUrl;
  private LruCache<String, Bitmap> bitmapCache;
  private AsyncTask<String, Void, Bitmap> currentTask;
  private MediaMetadataCompat.Builder currentMetadataBuilder;
  private Bitmap currentBitmap;
  private NotificationManager notificationManager;
  private static MediaControllerCompat mediaController;

  // 修改方法名
  public static MediaControllerCompat getAppMediaController() {
    return mediaController;
  }

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    // 初始化图片缓存
    final int maxMemory = (int) (Runtime.getRuntime().maxMemory() / 1024);
    final int cacheSize = maxMemory / 8;
    bitmapCache = new LruCache<String, Bitmap>(cacheSize) {
      @Override
      protected int sizeOf(String key, Bitmap bitmap) {
        return bitmap.getByteCount() / 1024;
      }
    };

    channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler((call, result) -> {
      if (call.method.equals("updateNowPlaying")) {
        try {
          String title = call.argument("title");
          String artist = call.argument("artist");
          Double duration = call.argument("duration");
          Double currentTime = call.argument("currentTime");
          Boolean isPlayingArg = call.argument("isPlaying");
          String coverUrl = call.argument("coverUrl");

          // 创建新的 MetadataBuilder
          currentMetadataBuilder = new MediaMetadataCompat.Builder()
              .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title != null ? title : "")
              .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist != null ? artist : "")
              .putLong(MediaMetadataCompat.METADATA_KEY_DURATION,
                  duration != null ? duration.longValue() * 1000 : 0L);

          // 更新播放状态
          boolean isPlaying = (isPlayingArg != null && isPlayingArg);
          PlaybackStateCompat.Builder stateBuilder = new PlaybackStateCompat.Builder()
              .setActions(
                  PlaybackStateCompat.ACTION_PLAY |
                      PlaybackStateCompat.ACTION_PAUSE |
                      PlaybackStateCompat.ACTION_PLAY_PAUSE |
                      PlaybackStateCompat.ACTION_SKIP_TO_NEXT |
                      PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS |
                      PlaybackStateCompat.ACTION_SEEK_TO)
              .setState(
                  isPlaying ? PlaybackStateCompat.STATE_PLAYING : PlaybackStateCompat.STATE_PAUSED,
                  currentTime != null ? (long) (currentTime * 1000) : 0L,
                  1.0f);

          PlaybackStateCompat playbackState = stateBuilder.build();
          mediaSession.setPlaybackState(playbackState);

          // 更新封面逻辑
          if (coverUrl != null && !coverUrl.isEmpty()) {
            // 如果 URL 改变或强制更新
            if (!coverUrl.equals(currentCoverUrl) || currentBitmap == null) {
              currentCoverUrl = coverUrl;

              if (currentTask != null) {
                currentTask.cancel(true);
              }

              Bitmap cachedBitmap = bitmapCache.get(coverUrl);
              if (cachedBitmap != null) {
                currentBitmap = cachedBitmap;
                updateMetadataWithBitmap(currentMetadataBuilder, cachedBitmap, coverUrl);
              } else {
                currentTask = new AlbumArtLoader(coverUrl, currentMetadataBuilder);
                currentTask.execute(coverUrl);
              }
            } else if (currentBitmap != null) {
              // URL 相同但需要更新元数据
              currentMetadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, currentBitmap)
                  .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, currentBitmap);
              mediaSession.setMetadata(currentMetadataBuilder.build());
              updateNotification(currentMetadataBuilder.build(), playbackState);
            }
          } else {
            // 如果没有封面 URL，清除当前封面
            currentBitmap = null;
            currentCoverUrl = null;
            mediaSession.setMetadata(currentMetadataBuilder.build());
            updateNotification(currentMetadataBuilder.build(), playbackState);
          }

          result.success(null);
        } catch (Exception e) {
          Log.e(TAG, "Error updating now playing: " + e.getMessage());
          result.error("UPDATE_ERROR", e.getMessage(), null);
        }
      } else {
        result.notImplemented();
      }
    });
  }

  private void updateMetadataWithBitmap(MediaMetadataCompat.Builder builder, Bitmap bitmap, String url) {
    try {
      // 调整图片大小
      Bitmap scaledBitmap = scaleBitmap(bitmap, 512);
      currentBitmap = scaledBitmap;

      // 创建新的 Builder 并复制所有现有元数据
      MediaMetadataCompat currentMetadata = mediaSession.getController().getMetadata();
      MediaMetadataCompat.Builder newBuilder = new MediaMetadataCompat.Builder();

      if (currentMetadata != null) {
        newBuilder = new MediaMetadataCompat.Builder(currentMetadata);
      }

      // 添加所有文本元数据
      newBuilder.putString(MediaMetadataCompat.METADATA_KEY_TITLE,
          builder.build().getString(MediaMetadataCompat.METADATA_KEY_TITLE))
          .putString(MediaMetadataCompat.METADATA_KEY_ARTIST,
              builder.build().getString(MediaMetadataCompat.METADATA_KEY_ARTIST))
          .putLong(MediaMetadataCompat.METADATA_KEY_DURATION,
              builder.build().getLong(MediaMetadataCompat.METADATA_KEY_DURATION));

      // 添加图片
      newBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, scaledBitmap)
          .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, scaledBitmap)
          .putString(MediaMetadataCompat.METADATA_KEY_ART_URI, url)
          .putString(MediaMetadataCompat.METADATA_KEY_ALBUM_ART_URI, url)
          .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON_URI, url);

      // 设置元数据
      MediaMetadataCompat metadata = newBuilder.build();
      mediaSession.setMetadata(metadata);

      // 更新通知
      updateNotification(metadata, mediaSession.getController().getPlaybackState());

      // 保持图片引用
      if (bitmapCache != null) {
        bitmapCache.put(url, scaledBitmap);
      }
    } catch (Exception e) {
      Log.e(TAG, "Error updating metadata with bitmap: " + e.getMessage());
    }
  }

  private Bitmap scaleBitmap(Bitmap bitmap, int maxSize) {
    int width = bitmap.getWidth();
    int height = bitmap.getHeight();

    float scale = Math.min((float) maxSize / width, (float) maxSize / height);

    // 如果图片已经小于最大尺寸，直接返回
    if (scale >= 1) {
      return bitmap;
    }

    Matrix matrix = new Matrix();
    matrix.postScale(scale, scale);

    Bitmap scaledBitmap = Bitmap.createBitmap(bitmap, 0, 0, width, height, matrix, true);

    return scaledBitmap;
  }

  private class AlbumArtLoader extends AsyncTask<String, Void, Bitmap> {
    private final String url;
    private final MediaMetadataCompat.Builder metadataBuilder;

    AlbumArtLoader(String url, MediaMetadataCompat.Builder builder) {
      this.url = url;
      this.metadataBuilder = builder;
    }

    @Override
    protected Bitmap doInBackground(String... urls) {
      try {
        URL imageUrl = new URL(urls[0]);
        HttpURLConnection connection = (HttpURLConnection) imageUrl.openConnection();
        connection.setDoInput(true);
        connection.setConnectTimeout(5000);
        connection.setReadTimeout(5000);
        connection.connect();

        InputStream input = connection.getInputStream();
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inPreferredConfig = Bitmap.Config.ARGB_8888;
        options.inScaled = false;

        Bitmap bitmap = BitmapFactory.decodeStream(input, null, options);
        input.close();
        connection.disconnect();

        return bitmap;
      } catch (Exception e) {
        Log.e(TAG, "Error loading album art: " + e.getMessage());
        return null;
      }
    }

    @Override
    protected void onPostExecute(Bitmap bitmap) {
      if (bitmap != null && url.equals(currentCoverUrl)) {
        updateMetadataWithBitmap(metadataBuilder, bitmap, url);
      }
    }
  }

  @Override
  protected void onCreate(@Nullable Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    // 创建通知渠道
    createNotificationChannel();
    notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

    // 创建 MediaSession
    mediaSession = new MediaSessionCompat(this, "PoTunes");

    // 设置初始 PlaybackState
    PlaybackStateCompat.Builder stateBuilder = new PlaybackStateCompat.Builder()
        .setState(PlaybackStateCompat.STATE_PAUSED, 0L, 1.0f)
        .setActions(
            PlaybackStateCompat.ACTION_PLAY |
                PlaybackStateCompat.ACTION_PAUSE |
                PlaybackStateCompat.ACTION_PLAY_PAUSE |
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT |
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS |
                PlaybackStateCompat.ACTION_SEEK_TO);

    mediaSession.setPlaybackState(stateBuilder.build());

    // 设置回调
    mediaSession.setCallback(new MediaSessionCompat.Callback() {
      @Override
      public void onPlay() {
        Log.d(TAG, "onPlay called");
        sendControlEvent("play");
        updatePlaybackState(true);
      }

      @Override
      public void onPause() {
        Log.d(TAG, "onPause called");
        sendControlEvent("pause");
        updatePlaybackState(false);
      }

      @Override
      public void onSkipToNext() {
        Log.d(TAG, "onSkipToNext called");
        sendControlEvent("next");
      }

      @Override
      public void onSkipToPrevious() {
        Log.d(TAG, "onSkipToPrevious called");
        sendControlEvent("previous");
      }

      @Override
      public void onSeekTo(long position) {
        Log.d(TAG, "onSeekTo called: " + position);
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("action", "seek");
        arguments.put("position", position / 1000.0);
        runOnUiThread(() -> {
          channel.invokeMethod("controlCenterEvent", arguments);
        });
      }
    });

    // 设置标志
    mediaSession.setFlags(
        MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS |
            MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS);

    mediaSession.setActive(true);

    // 设置 MediaController
    mediaController = new MediaControllerCompat(this, mediaSession);
    MediaControllerCompat.setMediaController(this, mediaController);

    // 处理从 MediaButtonReceiver 接收到的 Intent
    handleIntent(getIntent());
  }

  @Override
  protected void onNewIntent(Intent intent) {
    super.onNewIntent(intent);
    handleIntent(intent);
  }

  private void handleIntent(Intent intent) {
    if (intent != null && intent.getAction() != null) {
      String action = intent.getAction();
      switch (action) {
        case "ACTION_PLAY":
          sendControlEvent("play");
          break;
        case "ACTION_PAUSE":
          sendControlEvent("pause");
          break;
        case "ACTION_NEXT":
          sendControlEvent("next");
          break;
        case "ACTION_PREVIOUS":
          sendControlEvent("previous");
          break;
      }
    }
  }

  private void sendControlEvent(String action) {
    if (channel != null) {
      Map<String, Object> arguments = new HashMap<>();
      arguments.put("action", action);
      runOnUiThread(() -> {
        channel.invokeMethod("controlCenterEvent", arguments);
      });
    }
  }

  private void createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      NotificationChannel channel = new NotificationChannel(
          CHANNEL_ID,
          "Media Playback",
          NotificationManager.IMPORTANCE_LOW);
      channel.setDescription("Media playback controls");
      channel.setShowBadge(false);
      NotificationManager notificationManager = getSystemService(NotificationManager.class);
      notificationManager.createNotificationChannel(channel);
    }
  }

  private void updateNotification(MediaMetadataCompat metadata, PlaybackStateCompat state) {
    if (metadata == null || state == null)
      return;

    // 创建 PendingIntent 用于点击通知时打开应用
    Intent intent = new Intent(this, MainActivity.class);
    intent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
    int flags = PendingIntent.FLAG_UPDATE_CURRENT;
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      flags |= PendingIntent.FLAG_IMMUTABLE;
    }
    PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent, flags);

    // 获取当前播放状态
    boolean isPlaying = state.getState() == PlaybackStateCompat.STATE_PLAYING;

    // 创建媒体控制按钮的 PendingIntent
    Intent playPauseIntent = new Intent(this, pink.poche.potunes.MediaButtonReceiver.class)
        .setAction(isPlaying ? "ACTION_PAUSE" : "ACTION_PLAY")
        .setPackage(getPackageName());
    PendingIntent playPausePendingIntent = PendingIntent.getBroadcast(this, 0,
        playPauseIntent, flags);

    Intent previousIntent = new Intent(this, pink.poche.potunes.MediaButtonReceiver.class)
        .setAction("ACTION_PREVIOUS")
        .setPackage(getPackageName());
    PendingIntent previousPendingIntent = PendingIntent.getBroadcast(this, 0,
        previousIntent, flags);

    Intent nextIntent = new Intent(this, pink.poche.potunes.MediaButtonReceiver.class)
        .setAction("ACTION_NEXT")
        .setPackage(getPackageName());
    PendingIntent nextPendingIntent = PendingIntent.getBroadcast(this, 0,
        nextIntent, flags);

    // 构建通知
    NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(R.mipmap.ic_launcher)
        .setContentTitle(metadata.getString(MediaMetadataCompat.METADATA_KEY_TITLE))
        .setContentText(metadata.getString(MediaMetadataCompat.METADATA_KEY_ARTIST))
        .setLargeIcon(metadata.getBitmap(MediaMetadataCompat.METADATA_KEY_ART))
        .setContentIntent(pendingIntent)
        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        .setOnlyAlertOnce(true)
        .setShowWhen(false)
        .setOngoing(isPlaying)
        .setAutoCancel(!isPlaying);

    // 添加媒体控制按钮
    builder.addAction(new NotificationCompat.Action(
        R.drawable.ic_previous, "Previous", previousPendingIntent));

    builder.addAction(new NotificationCompat.Action(
        isPlaying ? R.drawable.ic_pause : R.drawable.ic_play,
        isPlaying ? "Pause" : "Play",
        playPausePendingIntent));

    builder.addAction(new NotificationCompat.Action(
        R.drawable.ic_next, "Next", nextPendingIntent));

    // 设置媒体样式
    MediaStyle mediaStyle = new MediaStyle()
        .setMediaSession(mediaSession.getSessionToken())
        .setShowActionsInCompactView(0, 1, 2);
    builder.setStyle(mediaStyle);

    // 更新通知
    notificationManager.notify(NOTIFICATION_ID, builder.build());
  }

  @Override
  protected void onDestroy() {
    notificationManager.cancel(NOTIFICATION_ID);
    if (currentTask != null) {
      currentTask.cancel(true);
    }
    if (mediaSession != null) {
      mediaSession.release();
    }
    if (bitmapCache != null) {
      bitmapCache.evictAll();
    }
    if (currentBitmap != null) {
      currentBitmap.recycle();
      currentBitmap = null;
    }
    mediaController = null;
    super.onDestroy();
  }

  // 添加更新播放状态的辅助方法
  private void updatePlaybackState(boolean isPlaying) {
    PlaybackStateCompat.Builder stateBuilder = new PlaybackStateCompat.Builder()
        .setActions(
            PlaybackStateCompat.ACTION_PLAY |
                PlaybackStateCompat.ACTION_PAUSE |
                PlaybackStateCompat.ACTION_PLAY_PAUSE |
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT |
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS |
                PlaybackStateCompat.ACTION_SEEK_TO)
        .setState(
            isPlaying ? PlaybackStateCompat.STATE_PLAYING : PlaybackStateCompat.STATE_PAUSED,
            mediaSession.getController().getPlaybackState().getPosition(),
            1.0f);
    mediaSession.setPlaybackState(stateBuilder.build());

    // 更新通知
    if (currentMetadataBuilder != null) {
      updateNotification(currentMetadataBuilder.build(), stateBuilder.build());
    }
  }
}