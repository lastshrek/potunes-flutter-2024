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
import android.os.Bundle
import android.os.Parcelable
import android.os.Parcel
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.MediaBrowserServiceCompat
import androidx.media.session.MediaButtonReceiver
import io.flutter.embedding.engine.FlutterEngine
import java.net.URL

class MediaPlaybackService : MediaBrowserServiceCompat() {
    private lateinit var mediaSession: MediaSessionCompat
    private lateinit var notificationManager: NotificationManager
    private val channelId = "music_playback_channel"
    private val notificationId = 1

    companion object {
        private const val FLUID_NOTIFICATION_CHANNEL = "fluid_notification_channel"
    }

    override fun onCreate() {
        super.onCreate()

        mediaSession = MediaSessionCompat(this, "PoTunes").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or 
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS or
                MediaSessionCompat.FLAG_HANDLES_QUEUE_COMMANDS
            )
            
            setPlaybackState(PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_NONE, 0, 1.0f)
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackStateCompat.ACTION_PLAY_FROM_MEDIA_ID or
                    PlaybackStateCompat.ACTION_PLAY_FROM_SEARCH or
                    PlaybackStateCompat.ACTION_SKIP_TO_QUEUE_ITEM or
                    PlaybackStateCompat.ACTION_SET_REPEAT_MODE or
                    PlaybackStateCompat.ACTION_SET_SHUFFLE_MODE
                )
                .build()
            )
        }

        sessionToken = mediaSession.sessionToken

        // 创建通知渠道
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Music Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows music playback controls"
            }
            notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }

        // 创建流体云通知渠道
        createFluidNotificationChannel()
    }

    override fun onGetRoot(
        clientPackageName: String,
        clientUid: Int,
        rootHints: Bundle?
    ): BrowserRoot? {
        return BrowserRoot("root", null)
    }

    override fun onLoadChildren(
        parentId: String,
        result: Result<List<MediaBrowserCompat.MediaItem>>
    ) {
        result.sendResult(emptyList())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        MediaButtonReceiver.handleIntent(mediaSession, intent)
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onDestroy() {
        mediaSession.release()
        super.onDestroy()
    }

    fun updateNotification(
        context: Context,
        title: String,
        artist: String,
        coverUrl: String,
        isPlaying: Boolean
    ) {
        // 加载封面图片
        val bitmap = try {
            val url = URL(coverUrl)
            BitmapFactory.decodeStream(url.openConnection().getInputStream())
        } catch (e: Exception) {
            null
        }

        // 更新 MediaSession 元数据
        mediaSession.setMetadata(MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap)
            .build())

        // 创建通知
        val notification = createNotification(context, title, artist, bitmap, isPlaying)
        notificationManager.notify(notificationId, notification)
    }

    // 添加波形数据的包装类
    class WaveformData(val data: ByteArray) : Parcelable {
        constructor(parcel: Parcel) : this(parcel.createByteArray() ?: ByteArray(0))

        override fun writeToParcel(parcel: Parcel, flags: Int) {
            parcel.writeByteArray(data)
        }

        override fun describeContents(): Int {
            return 0
        }

        companion object CREATOR : Parcelable.Creator<WaveformData> {
            override fun createFromParcel(parcel: Parcel): WaveformData {
                return WaveformData(parcel)
            }

            override fun newArray(size: Int): Array<WaveformData?> {
                return arrayOfNulls(size)
            }
        }
    }

    private fun createNotification(
        context: Context,
        title: String,
        artist: String,
        albumArt: Bitmap?,
        isPlaying: Boolean
    ): Notification {
        // 创建 PendingIntent
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 创建流体云样式的通知
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setLargeIcon(albumArt)
            .setContentTitle(title)
            .setContentText(artist)
            .setContentIntent(contentIntent)
            .setStyle(androidx.media.app.NotificationCompat.MediaStyle()
                .setMediaSession(mediaSession.sessionToken)
                .setShowActionsInCompactView(0, 1, 2))
            // 添加流体云相关配置
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // ColorOS 流体云特定配置
            .addExtras(Bundle().apply {
                putBoolean("android.fluid.notification", true)
                putString("android.fluid.style", "music")
                // 添加歌词支持
                putString("android.fluid.lyrics", getCurrentLyrics())
                // 修改波形数据的包装方式
                getAudioWaveform()?.let { waveform ->
                    putParcelable("android.fluid.waveform", WaveformData(waveform))
                }
            })
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .addAction(R.drawable.ic_previous, "Previous",
                MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS))
            .addAction(if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play,
                if (isPlaying) "Pause" else "Play",
                MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                    if (isPlaying) PlaybackStateCompat.ACTION_PAUSE
                    else PlaybackStateCompat.ACTION_PLAY))
            .addAction(R.drawable.ic_next, "Next",
                MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT))
            .setOngoing(isPlaying)
            .build()

        return notification
    }

    // 获取当前歌词
    private fun getCurrentLyrics(): String {
        // 实现获取当前歌词的逻辑
        return ""
    }

    // 获取音频波形数据
    private fun getAudioWaveform(): ByteArray? {
        try {
            // 实现获取音频波形数据的逻辑
            // 这通常需要对音频数据进行实时分析
            return null
        } catch (e: Exception) {
            return null
        }
    }

    // 创建流体云通知渠道
    private fun createFluidNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val fluidChannel = NotificationChannel(
                FLUID_NOTIFICATION_CHANNEL,
                "Music Fluid Notification",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows fluid music controls"
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(fluidChannel)
        }
    }
} 