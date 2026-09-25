package dev.ontime.qa.ontimed04probe

import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ontime.d04.qa")
            .setMethodCallHandler { call, result ->
                if (call.method != "ordinarySQLiteRejects") { result.notImplemented(); return@setMethodCallHandler }
                val path = call.arguments as? String
                if (path == null || !path.startsWith(filesDir.parentFile!!.absolutePath)) {
                    result.error("scope", "Only own QA sandbox", null); return@setMethodCallHandler
                }
                try {
                    val memory = SQLiteDatabase.create(null)
                    val isOrdinary = memory.rawQuery("PRAGMA cipher_version", null).use { !it.moveToFirst() }
                    val isWorking = memory.rawQuery("SELECT sqlite_version()", null).use { it.moveToFirst() && it.getString(0).isNotBlank() }
                    memory.close()
                    var rejected = false
                    try {
                        SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                            db.rawQuery("SELECT note FROM users", null).use { it.moveToFirst() }
                        }
                    } catch (error: SQLiteException) {
                        rejected = true
                    }
                    result.success(isOrdinary && isWorking && rejected)
                } catch (error: Exception) {
                    result.error("probe", error.javaClass.simpleName, null)
                }
            }
    }
}
