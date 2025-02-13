package pink.poche.potunes

import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class PoTunesApplication : FlutterApplication() {
    companion object {
        const val CHANNEL = "pink.poche.potunes.audio_control"
        const val TAG = "PoTunes"
        var methodChannel: MethodChannel? = null
        
        fun logInfo(message: String) {
            System.out.println("$TAG: $message")
            Log.i(TAG, message)
        }
    }

    override fun onCreate() {
        super.onCreate()
        logInfo("====== PoTunesApplication: onCreate ======")
    }
} 