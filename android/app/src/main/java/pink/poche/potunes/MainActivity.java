package pink.poche.potunes;

import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;
import com.ryanheise.audioservice.AudioServiceActivity;

public class MainActivity extends AudioServiceActivity {
  private static final String TAG = "PoTunes";

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    Log.e(TAG, "🚀 MainActivity: onCreate STARTED");
    super.onCreate(savedInstanceState);
    Log.e(TAG, "🚀 MainActivity: onCreate COMPLETED");

    // 显示 Toast 消息
    runOnUiThread(() -> {
      Toast.makeText(getApplicationContext(),
          "PoTunes Started! 🎵",
          Toast.LENGTH_LONG).show();
    });
  }

  @Override
  protected void onResume() {
    super.onResume();
    Log.e(TAG, "🔄 MainActivity: onResume");
  }

  @Override
  protected void onPause() {
    super.onPause();
    Log.e(TAG, "⏸️ MainActivity: onPause");
  }

  @Override
  protected void onDestroy() {
    Log.e(TAG, "💫 MainActivity: onDestroy");
    super.onDestroy();
  }
}