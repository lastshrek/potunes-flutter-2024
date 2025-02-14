package pink.poche.potunes;

import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;
import com.ryanheise.audioservice.AudioServiceActivity;
import android.content.Intent;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.embedding.engine.FlutterEngine;
import androidx.annotation.NonNull;
import java.util.HashMap;
import java.util.Map;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.IntentFilter;
import android.view.KeyEvent;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.support.v4.media.session.MediaSessionCompat;

public class MainActivity extends AudioServiceActivity {
  private static final String TAG = "PoTunes";
  private static final String CHANNEL = "pink.poche.potunes/audio_control";
  private MethodChannel channel;
  private BroadcastReceiver mediaButtonReceiver;
  private MediaSessionCompat mediaSession;

  // 修改常量定义
  private static final String ACTION_PLAY = "com.ryanheise.audioservice.NOTIFICATION_PLAY";
  private static final String ACTION_PAUSE = "com.ryanheise.audioservice.NOTIFICATION_PAUSE";
  private static final String ACTION_NEXT = "com.ryanheise.audioservice.NOTIFICATION_NEXT";
  private static final String ACTION_PREV = "com.ryanheise.audioservice.NOTIFICATION_PREV";
  private static final String ACTION_CLICK = "com.ryanheise.audioservice.NOTIFICATION_CLICK";
  private static final String ACTION_STOP = "com.ryanheise.audioservice.NOTIFICATION_STOP";
  private static final String ACTION_SEEK = "com.ryanheise.audioservice.NOTIFICATION_SEEK";
  private static final String ACTION_PREPARE = "com.ryanheise.audioservice.NOTIFICATION_PREPARE";
  private static final String ACTION_READY = "com.ryanheise.audioservice.NOTIFICATION_READY";
  private static final String ACTION_COMPLETE = "com.ryanheise.audioservice.NOTIFICATION_COMPLETE";

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);

    channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler((call, result) -> {
      if (call.method.equals("updateNowPlaying")) {
        try {
          String title = call.argument("title");
          String artist = call.argument("artist");
          Double duration = call.argument("duration");
          Double currentTime = call.argument("currentTime");
          Boolean isPlaying = call.argument("isPlaying");
          String coverUrl = call.argument("coverUrl");

          // 更新 MediaSession 的元数据
          MediaMetadataCompat.Builder metadataBuilder = new MediaMetadataCompat.Builder()
              .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
              .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
              .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration != null ? duration.longValue() : 0L);

          if (coverUrl != null) {
            metadataBuilder.putString(MediaMetadataCompat.METADATA_KEY_ART_URI, coverUrl);
          }

          mediaSession.setMetadata(metadataBuilder.build());

          // 更新播放状态
          PlaybackStateCompat.Builder stateBuilder = new PlaybackStateCompat.Builder()
              .setActions(PlaybackStateCompat.ACTION_PLAY |
                  PlaybackStateCompat.ACTION_PAUSE |
                  PlaybackStateCompat.ACTION_SKIP_TO_NEXT |
                  PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS)
              .setState(isPlaying ? PlaybackStateCompat.STATE_PLAYING : PlaybackStateCompat.STATE_PAUSED,
                  currentTime != null ? currentTime.longValue() : 0L,
                  1.0f);

          mediaSession.setPlaybackState(stateBuilder.build());

          result.success(null);
        } catch (Exception e) {
          Log.e(TAG, "❌ Error updating now playing: " + e.getMessage());
          result.error("UPDATE_ERROR", e.getMessage(), null);
        }
      } else {
        result.notImplemented();
      }
    });
  }

  @Override
  public boolean dispatchKeyEvent(KeyEvent event) {
    Log.e(TAG, "🎵 dispatchKeyEvent: " + event.toString());
    if (Intent.ACTION_MEDIA_BUTTON.equals(event.getAction())) {
      if (event.getAction() == KeyEvent.ACTION_DOWN) {
        int keyCode = event.getKeyCode();
        Log.e(TAG, "🎵 Media Button KeyCode: " + keyCode);

        switch (keyCode) {
          case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
            sendControlEvent("play");
            return true;
          case KeyEvent.KEYCODE_MEDIA_NEXT:
            sendControlEvent("next");
            return true;
          case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
            sendControlEvent("previous");
            return true;
        }
      }
    }
    return super.dispatchKeyEvent(event);
  }

  @Override
  protected void onNewIntent(Intent intent) {
    super.onNewIntent(intent);
    Log.e(TAG, "🎵 onNewIntent: " + intent.toString());
    Log.e(TAG, "�� onNewIntent extras: " + (intent.getExtras() != null ? intent.getExtras().toString() : "null"));

    String action = intent.getAction();
    Log.e(TAG, "🎵 onNewIntent action: " + action);

    if (action != null) {
      String controlAction = null;
      switch (action) {
        case "com.ryanheise.audioservice.NOTIFICATION_PLAY":
          Log.e(TAG, "🎵 Play button clicked");
          controlAction = "play";
          break;
        case "com.ryanheise.audioservice.NOTIFICATION_PAUSE":
          Log.e(TAG, "🎵 Pause button clicked");
          controlAction = "pause";
          break;
        case "com.ryanheise.audioservice.NOTIFICATION_NEXT":
          Log.e(TAG, "🎵 Next button clicked");
          controlAction = "next";
          break;
        case "com.ryanheise.audioservice.NOTIFICATION_PREV":
          Log.e(TAG, "🎵 Previous button clicked");
          controlAction = "previous";
          break;
        case "com.ryanheise.audioservice.NOTIFICATION_CLICK":
          Log.e(TAG, "🎵 Notification clicked");
          break;
        case Intent.ACTION_MEDIA_BUTTON:
          KeyEvent keyEvent = intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
          if (keyEvent != null && keyEvent.getAction() == KeyEvent.ACTION_DOWN) {
            int keyCode = keyEvent.getKeyCode();
            Log.e(TAG, "🎵 Media Button KeyCode: " + keyCode);

            switch (keyCode) {
              case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
                controlAction = "play";
                break;
              case KeyEvent.KEYCODE_MEDIA_NEXT:
                controlAction = "next";
                break;
              case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
                controlAction = "previous";
                break;
            }
          }
          break;
      }

      if (controlAction != null) {
        sendControlEvent(controlAction);
      }
    }
  }

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    Log.e(TAG, "🚀 MainActivity: onCreate STARTED");
    super.onCreate(savedInstanceState);
    Log.e(TAG, "🚀 MainActivity: onCreate COMPLETED");

    // 创建 MediaSession
    mediaSession = new MediaSessionCompat(this, "PoTunes");
    mediaSession.setCallback(new MediaSessionCompat.Callback() {
      @Override
      public void onPlay() {
        Log.e(TAG, "🎵 MediaSession onPlay");
        sendControlEvent("play");
      }

      @Override
      public void onPause() {
        Log.e(TAG, "🎵 MediaSession onPause");
        sendControlEvent("pause");
      }

      @Override
      public void onSkipToNext() {
        Log.e(TAG, "🎵 MediaSession onSkipToNext");
        sendControlEvent("next");
      }

      @Override
      public void onSkipToPrevious() {
        Log.e(TAG, "🎵 MediaSession onSkipToPrevious");
        sendControlEvent("previous");
      }

      @Override
      public boolean onMediaButtonEvent(Intent mediaButtonEvent) {
        Log.e(TAG, "🎵 MediaSession onMediaButtonEvent: " + mediaButtonEvent.toString());
        KeyEvent keyEvent = mediaButtonEvent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
        if (keyEvent != null && keyEvent.getAction() == KeyEvent.ACTION_DOWN) {
          int keyCode = keyEvent.getKeyCode();
          Log.e(TAG, "🎵 Media Button KeyCode: " + keyCode);

          switch (keyCode) {
            case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
              sendControlEvent("play");
              return true;
            case KeyEvent.KEYCODE_MEDIA_NEXT:
              sendControlEvent("next");
              return true;
            case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
              sendControlEvent("previous");
              return true;
          }
        }
        return super.onMediaButtonEvent(mediaButtonEvent);
      }
    });
    mediaSession.setActive(true);

    // 处理启动时的 intent
    if (getIntent() != null) {
      onNewIntent(getIntent());
    }

    runOnUiThread(() -> {
      Toast.makeText(getApplicationContext(),
          "PoTunes Started! 🎵",
          Toast.LENGTH_LONG).show();
    });
  }

  private void sendControlEvent(String action) {
    if (channel != null) {
      Log.e(TAG, "🎵 Sending control event: " + action);
      Map<String, Object> arguments = new HashMap<>();
      arguments.put("action", action);

      runOnUiThread(() -> {
        channel.invokeMethod("controlCenterEvent", arguments);
      });
    } else {
      Log.e(TAG, "❌ Channel is null");
    }
  }

  @Override
  protected void onDestroy() {
    Log.e(TAG, "💫 MainActivity: onDestroy");
    if (mediaButtonReceiver != null) {
      // 使用全局广播注销接收器
      unregisterReceiver(mediaButtonReceiver);
    }
    if (mediaSession != null) {
      mediaSession.release();
    }
    super.onDestroy();
  }
}