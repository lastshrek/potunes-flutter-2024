package pink.poche.potunes

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "pink.poche.potunes/audio_control"
        
        // 静态引用，确保即使 Activity 被销毁也能接收事件
        private var instance: MainActivity? = null
    }
    
    private var methodChannel: MethodChannel? = null
    private var isReceiverRegistered = false
    
    // 广播接收器，接收来自 MusicPlayerService 的控制事件
    private val controlEventReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.getStringExtra("action") ?: return
            Log.d(TAG, "Received control event: $action")
            
            // 转发到 Flutter
            if (methodChannel != null) {
                methodChannel?.invokeMethod("controlCenterEvent", mapOf("action" to action))
            } else {
                Log.w(TAG, "methodChannel is null, cannot forward event: $action")
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        
        // 注册广播接收器
        registerBroadcastReceiver()
        
        // 检查并请求电池优化豁免
        checkAndRequestBatteryOptimization()
    }
    
    private fun registerBroadcastReceiver() {
        if (!isReceiverRegistered) {
            try {
                val filter = IntentFilter("pink.poche.potunes.CONTROL_EVENT")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(controlEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    registerReceiver(controlEventReceiver, filter)
                }
                isReceiverRegistered = true
                Log.d(TAG, "Broadcast receiver registered")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to register broadcast receiver", e)
            }
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startMusicPlayerService()
                    result.success(null)
                }
                "stopService" -> {
                    stopMusicPlayerService()
                    result.success(null)
                }
                "updateNowPlaying" -> {
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    val coverUrl = call.argument<String>("coverUrl") ?: ""
                    val duration = call.argument<Double>("duration")?.toLong() ?: 0L
                    val currentTime = call.argument<Double>("currentTime")?.toLong() ?: 0L
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    
                    // duration 和 currentTime 已经是毫秒，直接使用
                    updateMusicPlayerService(title, artist, coverUrl, duration, currentTime, isPlaying)
                    result.success(null)
                }
                "requestBatteryOptimization" -> {
                    val success = BatteryOptimizationHelper.requestIgnoreBatteryOptimizations(this)
                    result.success(success)
                }
                "checkBatteryOptimization" -> {
                    val isIgnoring = BatteryOptimizationHelper.isIgnoringBatteryOptimizations(this)
                    result.success(isIgnoring)
                }
                "startAudioService" -> {
                    startMusicPlayerService()
                    result.success(true)
                }
                "stopAudioService" -> {
                    stopMusicPlayerService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        Log.d(TAG, "Flutter engine configured, methodChannel ready")
    }
    
    /**
     * 启动音乐播放服务
     */
    private fun startMusicPlayerService() {
        val intent = Intent(this, MusicPlayerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d(TAG, "MusicPlayerService started")
    }
    
    /**
     * 停止音乐播放服务
     */
    private fun stopMusicPlayerService() {
        val intent = Intent(this, MusicPlayerService::class.java).apply {
            action = MusicPlayerService.ACTION_STOP
        }
        startService(intent)
        Log.d(TAG, "MusicPlayerService stop requested")
    }
    
    /**
     * 更新音乐播放服务的曲目信息
     */
    private fun updateMusicPlayerService(
        title: String,
        artist: String,
        coverUrl: String,
        duration: Long,
        position: Long,
        isPlaying: Boolean
    ) {
        val intent = Intent(this, MusicPlayerService::class.java).apply {
            action = MusicPlayerService.ACTION_UPDATE
            putExtra(MusicPlayerService.EXTRA_TITLE, title)
            putExtra(MusicPlayerService.EXTRA_ARTIST, artist)
            putExtra(MusicPlayerService.EXTRA_COVER_URL, coverUrl)
            putExtra(MusicPlayerService.EXTRA_DURATION, duration)
            putExtra(MusicPlayerService.EXTRA_POSITION, position)
            putExtra(MusicPlayerService.EXTRA_IS_PLAYING, isPlaying)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        
        Log.d(TAG, "MusicPlayerService updated: title=$title, isPlaying=$isPlaying")
    }
    
    /**
     * 检查并请求电池优化豁免
     */
    private fun checkAndRequestBatteryOptimization() {
        if (BatteryOptimizationHelper.shouldRequestBatteryOptimization(this)) {
            // 延迟请求，避免在启动时立即弹出对话框
            window.decorView.postDelayed({
                BatteryOptimizationHelper.requestIgnoreBatteryOptimizations(this)
            }, 3000)
        }
    }
    
    override fun onDestroy() {
        try {
            if (isReceiverRegistered) {
                unregisterReceiver(controlEventReceiver)
                isReceiverRegistered = false
                Log.d(TAG, "Broadcast receiver unregistered")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister receiver", e)
        }
        
        if (instance == this) {
            instance = null
        }
        
        super.onDestroy()
    }
}
