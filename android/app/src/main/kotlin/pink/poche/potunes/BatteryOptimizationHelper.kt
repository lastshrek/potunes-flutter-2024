package pink.poche.potunes

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * 处理电池优化豁免请求。
 * 
 * 当应用被添加到电池优化白名单后，系统不会限制其后台服务执行，
 * 从而确保音乐播放不会被系统杀死。
 */
object BatteryOptimizationHelper {
    
    private const val TAG = "BatteryOptimization"
    
    /**
     * 检查应用是否已被豁免电池优化。
     * 
     * @param context 上下文
     * @return true 如果应用已在白名单中，false 否则
     */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val isIgnoring = powerManager.isIgnoringBatteryOptimizations(context.packageName)
            Log.d(TAG, "Battery optimization ignored: $isIgnoring")
            return isIgnoring
        }
        // Android 6.0 以下不需要此权限
        return true
    }
    
    /**
     * 请求用户将应用添加到电池优化白名单。
     * 
     * 这会打开系统设置页面，让用户手动授权。
     * 
     * @param context 上下文
     * @return true 如果成功打开设置页面，false 如果失败
     */
    fun requestIgnoreBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // 如果已经在白名单中，无需再次请求
            if (isIgnoringBatteryOptimizations(context)) {
                Log.d(TAG, "Already ignoring battery optimizations")
                return true
            }
            
            return try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                Log.d(TAG, "Requested battery optimization exemption")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to request battery optimization exemption", e)
                // 尝试打开电池优化设置页面
                openBatteryOptimizationSettings(context)
            }
        }
        return true
    }
    
    /**
     * 打开电池优化设置页面（备用方案）。
     * 
     * 如果直接请求豁免失败，可以引导用户手动设置。
     * 
     * @param context 上下文
     * @return true 如果成功打开设置页面，false 如果失败
     */
    fun openBatteryOptimizationSettings(context: Context): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.d(TAG, "Opened battery optimization settings")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open battery optimization settings", e)
            false
        }
    }
    
    /**
     * 检查是否需要请求电池优化豁免。
     * 
     * @param context 上下文
     * @return true 如果需要请求，false 如果不需要
     */
    fun shouldRequestBatteryOptimization(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }
        return !isIgnoringBatteryOptimizations(context)
    }
}
