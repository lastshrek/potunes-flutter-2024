package pink.poche.potunes;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;

public class MediaButtonReceiver extends BroadcastReceiver {
  private static final String TAG = "MediaButtonReceiver";

  @Override
  public void onReceive(Context context, Intent intent) {
    String action = intent.getAction();
    Log.d(TAG, "Received action: " + action);

    // 获取 MediaController
    MediaControllerCompat controller = MainActivity.getAppMediaController();
    if (controller == null) {
      Log.e(TAG, "MediaController is null");
      return;
    }

    // 直接使用 MediaController 发送命令
    MediaControllerCompat.TransportControls controls = controller.getTransportControls();
    if (controls != null) {
      switch (action) {
        case "ACTION_PLAY":
          controls.play();
          break;
        case "ACTION_PAUSE":
          controls.pause();
          break;
        case "ACTION_NEXT":
          controls.skipToNext();
          break;
        case "ACTION_PREVIOUS":
          controls.skipToPrevious();
          break;
        default:
          Log.d(TAG, "Unknown action: " + action);
          break;
      }
    } else {
      Log.e(TAG, "TransportControls is null");

      // 如果 TransportControls 不可用，回退到通过 Activity 发送
      Intent mainActivityIntent = new Intent(context, MainActivity.class);
      mainActivityIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
      mainActivityIntent.setAction(action);
      context.startActivity(mainActivityIntent);
    }
  }
}