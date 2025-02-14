package pink.poche.potunes;

import android.content.Context;
import android.content.Intent;
import android.util.Log;
import android.view.KeyEvent;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;

public class PoTunesMediaButtonReceiver extends android.content.BroadcastReceiver {
  private static final String TAG = "PoTunes";

  @Override
  public void onReceive(Context context, Intent intent) {
    String action = intent.getAction();
    Log.e(TAG, "🎵 PoTunesMediaButtonReceiver received action: " + action);
    Log.e(TAG, "🎵 PoTunesMediaButtonReceiver received intent: " + intent.toString());
    Log.e(TAG, "🎵 PoTunesMediaButtonReceiver received extras: " + intent.getExtras());

    if (action != null) {
      // 创建一个新的 Intent 发送到 AudioService
      Intent serviceIntent = new Intent(context, MainActivity.class);
      serviceIntent.setAction(action);
      serviceIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

      switch (action) {
        case "com.ryanheise.audioservice.NOTIFICATION_PLAY":
          Log.e(TAG, "🎵 Play button clicked");
          serviceIntent.putExtra("action", "play");
          break;
        case "com.ryanheise.audioservice.NOTIFICATION_PAUSE":
          Log.e(TAG, "🎵 Pause button clicked");
          serviceIntent.putExtra("action", "pause");
          break;
        case "com.ryanheise.audioservice.NOTIFICATION_NEXT":
          Log.e(TAG, "🎵 Next button clicked");
          serviceIntent.putExtra("action", "next");
          break;
        case "com.ryanheise.audioservice.NOTIFICATION_PREV":
          Log.e(TAG, "🎵 Previous button clicked");
          serviceIntent.putExtra("action", "previous");
          break;
        case Intent.ACTION_MEDIA_BUTTON:
          KeyEvent keyEvent = intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
          if (keyEvent != null && keyEvent.getAction() == KeyEvent.ACTION_DOWN) {
            int keyCode = keyEvent.getKeyCode();
            Log.e(TAG, "🎵 Media Button KeyCode: " + keyCode);

            switch (keyCode) {
              case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
                serviceIntent.putExtra("action", "play");
                break;
              case KeyEvent.KEYCODE_MEDIA_NEXT:
                serviceIntent.putExtra("action", "next");
                break;
              case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
                serviceIntent.putExtra("action", "previous");
                break;
            }
          }
          break;
      }

      // 启动 MainActivity 来处理事件
      context.startActivity(serviceIntent);
    }
  }
}