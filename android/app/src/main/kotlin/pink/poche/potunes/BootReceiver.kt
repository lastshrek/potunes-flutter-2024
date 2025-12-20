package pink.poche.potunes

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED && context != null) {
            Log.d("BootReceiver", "设备已重启，准备恢复音乐服务")
            // 这里可以启动主应用或者直接启动服务
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                // 添加一个标志表明这是来自重启的启动
                launchIntent.putExtra("from_boot", true)
                context.startActivity(launchIntent)
            }
        }
    }
} 