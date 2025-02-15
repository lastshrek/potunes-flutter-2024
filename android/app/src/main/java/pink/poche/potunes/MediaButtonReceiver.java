package pink.poche.potunes;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;
import io.flutter.plugin.common.MethodChannel;

public class MediaButtonReceiver extends BroadcastReceiver {
  private static final String TAG = "MediaButtonReceiver";
  private static final String CHANNEL = "pink.poche.potunes/audio_control";

  @Override
  public void onReceive(Context context, Intent intent) {
    String action = intent.getAction();
    Log.d(TAG, "Received action: " + action);

    // 直接发送事件到 MainActivity
    Intent mainActivityIntent = new Intent(context, MainActivity.class);
    mainActivityIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    mainActivityIntent.setAction(action);
    context.startActivity(mainActivityIntent);
  }
}