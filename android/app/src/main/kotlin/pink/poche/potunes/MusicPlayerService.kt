package pink.poche.potunes

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.cancel

/**
 * 增强版音乐播放服务，提供稳定的后台播放支持。
 * 
 * 特性：
 * - MediaSession 集成：支持系统媒体控制（耳机按钮、锁屏控制）
 * - WakeLock 管理：防止 CPU 休眠
 * - 音频焦点管理：与其他音频应用协调
 * - 持久通知：显示播放控制和曲目信息
 * - 服务重启：START_STICKY 确保被杀死后自动重启
 */
class MusicPlayerService : Service() {
    
    companion object {
        private const val TAG = "MusicPlayerService"
        
        // Action 常量
        const val ACTION_PLAY = "pink.poche.potunes.ACTION_PLAY"
        const val ACTION_PAUSE = "pink.poche.potunes.ACTION_PAUSE"
        const val ACTION_NEXT = "pink.poche.potunes.ACTION_NEXT"
        const val ACTION_PREVIOUS = "pink.poche.potunes.ACTION_PREVIOUS"
        const val ACTION_STOP = "pink.poche.potunes.ACTION_STOP"
        const val ACTION_UPDATE = "pink.poche.potunes.ACTION_UPDATE"
        
        // Extra 常量
        const val EXTRA_TITLE = "title"
        const val EXTRA_ARTIST = "artist"
        const val EXTRA_COVER_URL = "coverUrl"
        const val EXTRA_DURATION = "duration"
        const val EXTRA_POSITION = "position"
        const val EXTRA_IS_PLAYING = "isPlaying"
    }
    
    // 核心组件
    private var mediaSession: MediaSessionCompat? = null
    private lateinit var wakeLockManager: WakeLockManager
    private lateinit var notificationController: NotificationController
    private var audioFocusRequest: AudioFocusRequest? = null
    private lateinit var audioManager: AudioManager
    
    // 协程作用域
    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())
    
    // 当前播放状态
    private var currentTitle: String = ""
    private var currentArtist: String = ""
    private var currentCoverUrl: String = ""
    private var currentDuration: Long = 0
    private var currentPosition: Long = 0
    private var isPlaying: Boolean = false
    private var currentAlbumArt: Bitmap? = null
    
    // Flutter MethodChannel
    private var methodChannel: MethodChannel? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate")
        
        // 初始化组件
        wakeLockManager = WakeLockManager(this)
        notificationController = NotificationController(this)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // 创建通知频道
        notificationController.createNotificationChannel()
        
        // 创建 MediaSession
        createMediaSession()
        
        // 启动前台服务
        startForegroundService()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_PLAY -> handlePlay()
            ACTION_PAUSE -> handlePause()
            ACTION_NEXT -> handleNext()
            ACTION_PREVIOUS -> handlePrevious()
            ACTION_STOP -> handleStop()
            ACTION_UPDATE -> handleUpdate(intent)
            else -> {
                // 默认启动，获取 WakeLock
                wakeLockManager.acquire()
            }
        }
        
        // 返回 START_STICKY 确保服务被杀死后自动重启
        return START_STICKY
    }
    
    override fun onDestroy() {
        Log.d(TAG, "Service onDestroy")
        
        // 释放资源
        abandonAudioFocus()
        wakeLockManager.cleanup()
        mediaSession?.release()
        serviceScope.cancel()
        
        super.onDestroy()
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    
    /**
     * 创建 MediaSession
     */
    private fun createMediaSession() {
        mediaSession = MediaSessionCompat(this, "PotunesToHole").apply {
            // 设置支持的操作
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            
            // 设置回调处理系统媒体控制
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    Log.d(TAG, "MediaSession onPlay")
                    handlePlay()
                }
                
                override fun onPause() {
                    Log.d(TAG, "MediaSession onPause")
                    handlePause()
                }
                
                override fun onSkipToNext() {
                    Log.d(TAG, "MediaSession onSkipToNext")
                    handleNext()
                }
                
                override fun onSkipToPrevious() {
                    Log.d(TAG, "MediaSession onSkipToPrevious")
                    handlePrevious()
                }
                
                override fun onStop() {
                    Log.d(TAG, "MediaSession onStop")
                    handleStop()
                }
                
                override fun onSeekTo(pos: Long) {
                    Log.d(TAG, "MediaSession onSeekTo: $pos")
                    sendToFlutter("seek", mapOf("position" to pos / 1000.0))
                }
                
                override fun onPlayFromMediaId(mediaId: String?, extras: Bundle?) {
                    Log.d(TAG, "MediaSession onPlayFromMediaId: $mediaId")
                    handlePlay()
                }
            })
            
            // 激活 MediaSession
            isActive = true
        }
        
        Log.d(TAG, "MediaSession created and activated")
    }
    
    /**
     * 启动前台服务
     */
    private fun startForegroundService() {
        val notification = notificationController.buildNotification(
            title = currentTitle.ifEmpty { "破破音乐" },
            artist = currentArtist.ifEmpty { "准备播放" },
            isPlaying = isPlaying,
            mediaSession = mediaSession,
            albumArt = currentAlbumArt,
            duration = currentDuration,
            position = currentPosition
        )
        startForeground(NotificationController.NOTIFICATION_ID, notification)
        Log.d(TAG, "Foreground service started")
    }
    
    /**
     * 更新通知
     */
    private fun updateNotification() {
        val notification = notificationController.buildNotification(
            title = currentTitle.ifEmpty { "破破音乐" },
            artist = currentArtist.ifEmpty { "准备播放" },
            isPlaying = isPlaying,
            mediaSession = mediaSession,
            albumArt = currentAlbumArt,
            duration = currentDuration,
            position = currentPosition
        )
        notificationController.updateNotification(notification)
    }
    
    /**
     * 更新 MediaSession 元数据
     */
    private fun updateMediaSessionMetadata() {
        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, currentDuration)
        
        if (currentAlbumArt != null) {
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, currentAlbumArt)
        }
        
        mediaSession?.setMetadata(metadataBuilder.build())
    }
    
    /**
     * 更新 MediaSession 播放状态
     */
    private fun updateMediaSessionPlaybackState() {
        val state = if (isPlaying) {
            PlaybackStateCompat.STATE_PLAYING
        } else {
            PlaybackStateCompat.STATE_PAUSED
        }
        
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO or
                PlaybackStateCompat.ACTION_STOP
            )
            .setState(state, currentPosition, 1.0f)
            .build()
        
        mediaSession?.setPlaybackState(playbackState)
    }
    
    /**
     * 请求音频焦点
     */
    private fun requestAudioFocus(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
            
            val result = audioManager.requestAudioFocus(audioFocusRequest!!)
            return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            val result = audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
            return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }
    
    /**
     * 放弃音频焦点
     */
    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let {
                audioManager.abandonAudioFocusRequest(it)
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(audioFocusChangeListener)
        }
    }
    
    /**
     * 音频焦点变化监听器
     */
    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                Log.d(TAG, "Audio focus gained")
                // 恢复播放
                sendToFlutter("play", null)
            }
            AudioManager.AUDIOFOCUS_LOSS -> {
                Log.d(TAG, "Audio focus lost permanently")
                // 永久丢失焦点，停止播放
                sendToFlutter("pause", null)
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                Log.d(TAG, "Audio focus lost temporarily")
                // 暂时丢失焦点，暂停播放
                sendToFlutter("pause", null)
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                Log.d(TAG, "Audio focus lost, can duck")
                // 可以降低音量继续播放，但我们选择暂停
                sendToFlutter("pause", null)
            }
        }
    }

    
    /**
     * 处理播放
     */
    private fun handlePlay() {
        if (requestAudioFocus()) {
            isPlaying = true
            wakeLockManager.acquire()
            updateMediaSessionPlaybackState()
            updateNotification()
            // 直接通知 Flutter，但不依赖于此
            sendToFlutter("play", null)
        }
    }
    
    /**
     * 处理暂停
     */
    private fun handlePause() {
        isPlaying = false
        updateMediaSessionPlaybackState()
        updateNotification()
        sendToFlutter("pause", null)
        // 暂停时不释放 WakeLock，保持服务活跃
    }
    
    /**
     * 处理下一首
     */
    private fun handleNext() {
        sendToFlutter("next", null)
    }
    
    /**
     * 处理上一首
     */
    private fun handlePrevious() {
        sendToFlutter("previous", null)
    }
    
    /**
     * 处理停止
     */
    private fun handleStop() {
        isPlaying = false
        abandonAudioFocus()
        wakeLockManager.release()
        mediaSession?.isActive = false
        stopForeground(true)
        stopSelf()
    }
    
    /**
     * 处理更新（从 Flutter 端接收曲目信息）
     */
    private fun handleUpdate(intent: Intent) {
        currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
        currentArtist = intent.getStringExtra(EXTRA_ARTIST) ?: currentArtist
        currentCoverUrl = intent.getStringExtra(EXTRA_COVER_URL) ?: currentCoverUrl
        currentDuration = intent.getLongExtra(EXTRA_DURATION, currentDuration)
        currentPosition = intent.getLongExtra(EXTRA_POSITION, currentPosition)
        isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, isPlaying)
        
        Log.d(TAG, "Update received: title=$currentTitle, artist=$currentArtist, isPlaying=$isPlaying")
        
        // 异步加载封面图片
        if (currentCoverUrl.isNotEmpty()) {
            serviceScope.launch {
                val newAlbumArt = notificationController.loadAlbumArt(currentCoverUrl)
                if (newAlbumArt != null) {
                    currentAlbumArt = newAlbumArt
                    updateMediaSessionMetadata()
                    updateNotification()
                }
            }
        }
        
        // 更新 MediaSession 和通知
        updateMediaSessionMetadata()
        updateMediaSessionPlaybackState()
        updateNotification()
        
        // 如果正在播放，确保持有 WakeLock
        if (isPlaying) {
            wakeLockManager.acquire()
        }
    }
    
    /**
     * 发送消息到 Flutter 端
     */
    private fun sendToFlutter(action: String, args: Map<String, Any>?) {
        try {
            // 通过广播发送到 MainActivity，由 MainActivity 转发到 Flutter
            val intent = Intent("pink.poche.potunes.CONTROL_EVENT").apply {
                putExtra("action", action)
                args?.forEach { (key, value) ->
                    when (value) {
                        is String -> putExtra(key, value)
                        is Int -> putExtra(key, value)
                        is Long -> putExtra(key, value)
                        is Double -> putExtra(key, value)
                        is Boolean -> putExtra(key, value)
                    }
                }
            }
            sendBroadcast(intent)
            Log.d(TAG, "Sent to Flutter: action=$action")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send to Flutter", e)
        }
    }
    
    /**
     * 公开方法：更新播放状态（供外部调用）
     */
    fun updatePlaybackState(
        title: String,
        artist: String,
        coverUrl: String,
        duration: Long,
        position: Long,
        playing: Boolean
    ) {
        currentTitle = title
        currentArtist = artist
        currentCoverUrl = coverUrl
        currentDuration = duration
        currentPosition = position
        isPlaying = playing
        
        updateMediaSessionMetadata()
        updateMediaSessionPlaybackState()
        updateNotification()
        
        if (playing) {
            wakeLockManager.acquire()
        }
    }
}
