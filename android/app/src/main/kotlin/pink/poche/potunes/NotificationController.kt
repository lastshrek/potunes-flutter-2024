package pink.poche.potunes

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL

/**
 * 负责创建和更新媒体播放通知。
 * 
 * 特性：
 * - 创建低优先级通知频道，减少对用户的干扰
 * - 显示当前曲目信息（标题、艺术家、封面）
 * - 提供播放控制按钮（播放/暂停、上一首、下一首）
 * - 点击通知打开应用
 * 
 * 注意：MediaSession 由 just_audio_background 插件管理，本控制器不再依赖 MediaSession
 */
class NotificationController(private val context: Context) {
    
    companion object {
        private const val TAG = "NotificationController"
        const val CHANNEL_ID = "potunes_music_channel"
        const val NOTIFICATION_ID = 1
    }
    
    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
    /**
     * 创建通知频道（Android 8.0+ 必需）
     */
    fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "音乐播放",
                NotificationManager.IMPORTANCE_LOW // 低优先级，减少干扰
            ).apply {
                description = "保持音乐在后台播放"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }
    
    /**
     * 构建媒体通知
     */
    fun buildNotification(
        title: String,
        artist: String,
        isPlaying: Boolean,
        albumArt: Bitmap? = null,
        duration: Long = 0,
        position: Long = 0
    ): Notification {
        // 创建点击通知打开应用的 Intent
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        // 创建播放控制 Action
        val playPauseAction = createPlayPauseAction(isPlaying)
        val previousAction = createPreviousAction()
        val nextAction = createNextAction()
        
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle(title)
            .setContentText(artist)
            .setContentIntent(contentIntent)
            .setOngoing(true) // 用户无法滑动关闭
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            // 添加播放控制按钮
            .addAction(previousAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
        
        // 设置进度条（可拖动）
        if (duration > 0) {
            builder.setProgress(
                duration.toInt(),
                position.toInt(),
                false // false 表示确定的进度条，可以拖动
            )
        }
        
        // 设置封面图片
        if (albumArt != null) {
            builder.setLargeIcon(albumArt)
        }
        
        // 使用 BigTextStyle 替代 MediaStyle，因为 MediaSession 由 just_audio_background 管理
        builder.setStyle(
            NotificationCompat.BigTextStyle()
                .bigText(artist)
        )
        
        return builder.build()
    }
    
    /**
     * 更新通知
     */
    fun updateNotification(notification: Notification) {
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    /**
     * 取消通知
     */
    fun cancelNotification() {
        notificationManager.cancel(NOTIFICATION_ID)
    }
    
    /**
     * 创建播放/暂停 Action
     */
    private fun createPlayPauseAction(isPlaying: Boolean): NotificationCompat.Action {
        val intent = Intent(context, MusicPlayerService::class.java).apply {
            action = if (isPlaying) MusicPlayerService.ACTION_PAUSE else MusicPlayerService.ACTION_PLAY
        }
        val pendingIntent = PendingIntent.getService(
            context,
            if (isPlaying) 1 else 2,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val icon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val title = if (isPlaying) "暂停" else "播放"
        
        return NotificationCompat.Action.Builder(icon, title, pendingIntent).build()
    }
    
    /**
     * 创建上一首 Action
     */
    private fun createPreviousAction(): NotificationCompat.Action {
        val intent = Intent(context, MusicPlayerService::class.java).apply {
            action = MusicPlayerService.ACTION_PREVIOUS
        }
        val pendingIntent = PendingIntent.getService(
            context,
            3,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Action.Builder(
            android.R.drawable.ic_media_previous,
            "上一首",
            pendingIntent
        ).build()
    }
    
    /**
     * 创建下一首 Action
     */
    private fun createNextAction(): NotificationCompat.Action {
        val intent = Intent(context, MusicPlayerService::class.java).apply {
            action = MusicPlayerService.ACTION_NEXT
        }
        val pendingIntent = PendingIntent.getService(
            context,
            4,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Action.Builder(
            android.R.drawable.ic_media_next,
            "下一首",
            pendingIntent
        ).build()
    }
    
    /**
     * 从 URL 加载封面图片（协程方法）
     */
    suspend fun loadAlbumArt(url: String?): Bitmap? {
        if (url.isNullOrEmpty()) return null
        
        return withContext(Dispatchers.IO) {
            try {
                val connection = URL(url).openConnection()
                connection.connectTimeout = 5000
                connection.readTimeout = 5000
                val inputStream = connection.getInputStream()
                BitmapFactory.decodeStream(inputStream)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load album art from $url", e)
                null
            }
        }
    }
}
