package com.example.medication_reminder

import android.os.Bundle
import androidx.annotation.Keep
import io.flutter.embedding.android.FlutterActivity

@Keep
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Explicitly reference raw notification sound & launcher icon so R8/AAPT2
        // resource shrinker never strips them in release APK builds.
        val keepSoundRes = R.raw.reminder_sound
        val keepIconRes = R.mipmap.ic_launcher
        if (keepSoundRes == 0 || keepIconRes == 0) {
            println("Keep resources active")
        }
    }
}
