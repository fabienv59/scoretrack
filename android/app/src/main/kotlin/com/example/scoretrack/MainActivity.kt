package com.example.scoretrack

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Active l'affichage bord à bord : l'app s'étend sous les barres système.
        // Obligatoire sous Android 15 (API 35) pour éviter l'avertissement Google Play.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}
