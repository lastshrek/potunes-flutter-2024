package pink.poche.potunes

import android.content.Context
import android.os.PowerManager
import android.util.Log

/**
 * 管理 WakeLock 的获取和释放，确保音乐在后台播放时 CPU 保持活跃。
 * 
 * 特性：
 * - 幂等性：多次调用 acquire() 不会创建重复的 WakeLock
 * - 自动超时：3小时后自动释放，防止电量耗尽
 * - 安全释放：只有在持有时才释放
 */
class WakeLockManager(private val context: Context) {
    
    companion object {
        private const val TAG = "WakeLockManager"
        private const val WAKE_LOCK_TAG = "PotunesToHole::MusicWakeLock"
        private const val WAKE_LOCK_TIMEOUT = 3 * 60 * 60 * 1000L // 3小时
    }
    
    private var wakeLock: PowerManager.WakeLock? = null
    
    /**
     * 获取部分唤醒锁以保持 CPU 活跃。
     * 如果已经持有 WakeLock，则不会重复获取（幂等性）。
     */
    @Synchronized
    fun acquire() {
        try {
            // 幂等性检查：如果已经持有，直接返回
            if (wakeLock?.isHeld == true) {
                Log.v(TAG, "WakeLock already held, skipping acquire")
                return
            }
            
            // 创建 WakeLock（如果尚未创建）
            if (wakeLock == null) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    WAKE_LOCK_TAG
                ).apply {
                    setReferenceCounted(false) // 禁用引用计数，确保单次释放即可
                }
            }
            
            // 获取 WakeLock，设置超时时间
            wakeLock?.acquire(WAKE_LOCK_TIMEOUT)
            Log.d(TAG, "WakeLock acquired with ${WAKE_LOCK_TIMEOUT}ms timeout")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WakeLock", e)
        }
    }
    
    /**
     * 释放唤醒锁，允许设备进入休眠状态。
     * 只有在持有 WakeLock 时才会释放。
     */
    @Synchronized
    fun release() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "WakeLock released")
            } else {
                Log.d(TAG, "WakeLock not held, skipping release")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release WakeLock", e)
        }
    }
    
    /**
     * 检查 WakeLock 是否被持有。
     */
    fun isHeld(): Boolean {
        return wakeLock?.isHeld == true
    }
    
    /**
     * 清理资源，在服务销毁时调用。
     */
    @Synchronized
    fun cleanup() {
        release()
        wakeLock = null
        Log.d(TAG, "WakeLock cleaned up")
    }
}
