package com.example.audacity_player

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.audacity_player/storage_permission"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isExternalStorageManager" -> {
                    result.success(checkStoragePermission())
                }
                "requestManageExternalStorage" -> {
                    openManageStorageSettings()
                    result.success(true)
                }
                "getPublicStoragePaths" -> {
                    result.success(resolveDownloadPaths())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            val readPerm = ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.READ_EXTERNAL_STORAGE
            )
            readPerm == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun openManageStorageSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (e: Exception) {
                val fallbackIntent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                startActivity(fallbackIntent)
            }
        } else {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }

    private fun resolveDownloadPaths(): List<String> {
        val paths = mutableListOf<String>()

        // 1. 标准主 Download 目录
        try {
            val standardDownload = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (standardDownload != null) {
                paths.add(standardDownload.absolutePath)
            }
        } catch (_: Exception) {}

        // 2. 主外部存储根目录与子 Download 目录
        try {
            val externalStorage = Environment.getExternalStorageDirectory()
            if (externalStorage != null) {
                val downloadSub = File(externalStorage, "Download")
                if (!paths.contains(downloadSub.absolutePath)) {
                    paths.add(downloadSub.absolutePath)
                }
            }
        } catch (_: Exception) {}

        // 3. 扫描外置 SD 卡或多存储卷
        try {
            val sm = getSystemService(Context.STORAGE_SERVICE) as? StorageManager
            if (sm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                for (volume in sm.storageVolumes) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        val dir = volume.directory
                        if (dir != null) {
                            val volDownload = File(dir, "Download")
                            if (!paths.contains(volDownload.absolutePath)) {
                                paths.add(volDownload.absolutePath)
                            }
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        return paths.distinct()
    }
}
