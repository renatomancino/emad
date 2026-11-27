package it.unisa.cenato.cenato

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Canale `it.unisa.cenato/fotocamera` (RNF_IN_3, UC_GP_3 flusso 1.1): dice se
// il permesso della fotocamera c'è già e apre le impostazioni dell'app.
// La richiesta del permesso la fa mobile_scanner all'avvio della fotocamera.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "it.unisa.cenato/fotocamera")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "permessoConcesso" -> result.success(
                        checkSelfPermission(Manifest.permission.CAMERA) ==
                            PackageManager.PERMISSION_GRANTED
                    )
                    "apriImpostazioni" -> {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null)
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
