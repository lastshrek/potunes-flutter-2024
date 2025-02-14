package pink.poche.potunes;

import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;
import com.ryanheise.audioservice.AudioServiceActivity;
import android.content.Intent;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.embedding.engine.FlutterEngine;
import androidx.annotation.NonNull;
import java.util.HashMap;
import java.util.Map;
import android.view.KeyEvent;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.support.v4.media.session.MediaSessionCompat;

public class MainActivity extends AudioServiceActivity {
  private static final String TAG = "PoTunes";
  private static final String CHANNEL = "pink.poche.potunes/audio_control";
  private MethodChannel channel;
  private MediaSessionCompat mediaSession;

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
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    // 创建 MediaSession
    mediaSession = new MediaSessionCompat(this, "PoTunes");
    mediaSession.setCallback(new MediaSessionCompat.Callback() {
      @Override
      public void onPlay() {
        sendControlEvent("play");
      }

      @Override
      public void onPause() {
        sendControlEvent("pause");
      }

      @Override
      public void onSkipToNext() {
        sendControlEvent("next");
      }

      @Override
      public void onSkipToPrevious() {
        sendControlEvent("previous");
      }
    });
    mediaSession.setActive(true);
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

  @Override
  protected void onDestroy() {
    if (mediaSession != null) {
      mediaSession.release();
    }
    super.onDestroy();
  }
}