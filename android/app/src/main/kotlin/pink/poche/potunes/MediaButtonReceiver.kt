package pink.poche.potunes

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.KeyEvent

/**
 * 处理媒体按钮事件（耳机按钮、媒体中心按钮等）
 */
class MediaButtonReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "MediaButtonReceiver"
    }
    
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        val action = intent.action
        if (action != Intent.ACTION_MEDIA_BUTTON) return
        
        val keyEvent = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT) ?: return
        
        if (keyEvent.action != KeyEvent.ACTION_DOWN) return
        
        val keyCode = keyEvent.keyCode
        Log.d(TAG, "Media button pressed: $keyCode")
        
        val serviceIntent = Intent(context, MusicPlayerService::class.java)
        
        when (keyCode) {
            KeyEvent.KEYCODE_MEDIA_PLAY -> {
                serviceIntent.action = MusicPlayerService.ACTION_PLAY
                Log.d(TAG, "Play button pressed")
            }
            KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                serviceIntent.action = MusicPlayerService.ACTION_PAUSE
                Log.d(TAG, "Pause button pressed")
            }
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                // 切换播放/暂停
                serviceIntent.action = MusicPlayerService.ACTION_PLAY // 或 ACTION_PAUSE，取决于当前状态
                Log.d(TAG, "Play/Pause button pressed")
            }
            KeyEvent.KEYCODE_MEDIA_NEXT -> {
                serviceIntent.action = MusicPlayerService.ACTION_NEXT
                Log.d(TAG, "Next button pressed")
            }
            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> {
                serviceIntent.action = MusicPlayerService.ACTION_PREVIOUS
                Log.d(TAG, "Previous button pressed")
            }
            else -> return
        }
        
        context.startService(serviceIntent)
    }
}
