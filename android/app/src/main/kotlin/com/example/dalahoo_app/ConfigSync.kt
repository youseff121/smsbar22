package com.example.dalahoo_app

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * همگام‌سازی سبک کانفیگ از سرور — حداکثر هر ۲۴ ساعت یک‌بار.
 * مسیر SMS را مسدود نمی‌کند؛ فقط کش SharedPreferences را به‌روز می‌کند.
 */
object ConfigSync {
    private const val TAG = "ConfigSync"
    private const val PREFS_APP = "app_prefs"
    private const val KEY_LAST_FETCH = "config_last_fetch_ms"
    private const val INTERVAL_MS = 24L * 60L * 60L * 1000L // ۲۴ ساعت

    // لینک‌ها: اول هاست خودت، بعد پشتیبان
    private val SOURCES = listOf(
        "https://your-host.example.com/dalahoo/config.json",
        "https://your-host2.example.com/dalahoo/config.json"
    )

    private val running = AtomicBoolean(false)

    fun syncIfDue(context: Context, force: Boolean = false) {
        if (!running.compareAndSet(false, true)) return

        Thread {
            try {
                val appPrefs = context.getSharedPreferences(PREFS_APP, Context.MODE_PRIVATE)
                val last = appPrefs.getLong(KEY_LAST_FETCH, 0L)
                val now = System.currentTimeMillis()
                if (!force && last > 0L && now - last < INTERVAL_MS) {
                    Log.d(TAG, "skip: within 24h window")
                    return@Thread
                }

                val urls = linkedSetOf<String>()
                // منابع ذخیره‌شده از کانفیگ قبلی
                try {
                    val flutterPrefs =
                        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val raw = flutterPrefs.getString("flutter.remote_config", null)
                    if (!raw.isNullOrBlank()) {
                        val obj = JSONObject(raw)
                        val arr = obj.optJSONArray("sources")
                        if (arr != null) {
                            for (i in 0 until arr.length()) {
                                val u = arr.optString(i)
                                if (u.startsWith("https://")) urls.add(u)
                            }
                        }
                    }
                } catch (_: Exception) {
                }
                SOURCES.forEach { urls.add(it) }

                for (url in urls) {
                    if (tryFetchAndSave(context, url)) {
                        appPrefs.edit().putLong(KEY_LAST_FETCH, System.currentTimeMillis()).apply()
                        Log.d(TAG, "updated from $url")
                        return@Thread
                    }
                }
                Log.w(TAG, "all sources failed")
            } catch (e: Exception) {
                Log.e(TAG, "sync error: ${e.message}")
            } finally {
                running.set(false)
            }
        }.start()
    }

    private fun tryFetchAndSave(context: Context, urlStr: String): Boolean {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(urlStr)
            conn = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 8000
                readTimeout = 8000
                requestMethod = "GET"
                instanceFollowRedirects = true
            }
            if (conn.responseCode != 200) return false

            val body = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            val decoded = JSONObject(body)
            val senders = decoded.optJSONArray("senders")
            val destinations = decoded.optJSONArray("destinations")
            if (senders == null || destinations == null ||
                senders.length() == 0 || destinations.length() == 0
            ) {
                return false
            }

            val out = JSONObject()
            out.put("senders", senders)
            out.put("destinations", destinations)
            val sources = decoded.optJSONArray("sources")
            if (sources != null) out.put("sources", sources)
            if (decoded.has("app")) out.put("app", decoded.get("app"))

            // فرمت مورد انتظار Flutter SharedPreferences برای رشته‌ها
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putString("flutter.remote_config", out.toString())
                .apply()
            true
        } catch (e: Exception) {
            Log.w(TAG, "fetch failed $urlStr: ${e.message}")
            false
        } finally {
            conn?.disconnect()
        }
    }
}
