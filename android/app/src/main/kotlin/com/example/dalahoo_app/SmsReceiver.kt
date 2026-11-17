package com.example.dalahoo_app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telephony.SmsManager
import android.telephony.SmsMessage
import android.util.Log

class SmsReceiver : BroadcastReceiver() {

    private fun diag(context: Context, msg: String) {
        // فقط لاگ داخلی؛ Toast تشخیصی برای کاربر نمایش داده نمی‌شود
        Log.d("SmsReceiver", msg)
    }

    override fun onReceive(context: Context, intent: Intent) {

        diag(context, "receiver fired: ${intent.action}")

        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return

        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )

        val isEnabled = context.getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
            .getBoolean("is_enabled", true)
        diag(context, "enabled=$isEnabled")
        if (!isEnabled) return

        val cfg = RemoteConfig.load(context)

        val bundle: Bundle = intent.extras ?: return
        val pdus = bundle.get("pdus") as? Array<*>
        if (pdus == null) {
            diag(context, "no pdus in intent")
            return
        }
        val format = bundle.getString("format")

        // پیامک‌های بلند چند بخشی‌اند: همه‌ی بخش‌ها رو کنار هم می‌ذاریم تا متن کامل باشه
        val messages = pdus.mapNotNull { pdu ->
            (pdu as? ByteArray)?.let {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    SmsMessage.createFromPdu(it, format)
                } else {
                    SmsMessage.createFromPdu(it)
                }
            }
        }
        if (messages.isEmpty()) return

        val sender = messages[0].originatingAddress ?: ""
        val messageBody = messages.joinToString("") { it.messageBody ?: "" }
        diag(context, "pdus=${pdus.size} len=${messageBody.length}")

        val normalizedSender = RemoteConfig.normalize(sender)
        val isAllowedSender = cfg.senders.any { source -> normalizedSender == source }
        diag(context, "from=$sender norm=$normalizedSender allowed=$isAllowedSender")

        if (!isAllowedSender) {
            diag(context, "skipped: sender not in list")
            return
        }

        try {
            val appPrefs = context.getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
            var simSlot = appPrefs.getInt("selectedSim", -1)
            if (simSlot == -1) {
                simSlot = prefs.getInt("selectedSim", -1)
            }
            if (simSlot == -1) {
                simSlot = prefs.getInt("flutter.selectedSim", 1)
            }
            if (simSlot < 1) simSlot = 1

            val smsManager = resolveSmsManager(context, simSlot)
            diag(context, "slot=$simSlot subId=${SimHelper.subscriptionIdForSlot(context, simSlot)}")

            val driverName = prefs.getString("flutter.driver_name", "") ?: ""
            val displayName = if (driverName.isNotBlank()) driverName else "راننده"

            // نام راننده همیشه اول پیام میاد، بعد متن کامل
            val finalMessage = "$displayName:\n$messageBody"

            var sentOk = false
            for (dest in cfg.destinations) {
                try {
                    val parts = smsManager.divideMessage(finalMessage)
                    val sentIntents = ArrayList<PendingIntent>()
                    for ((idx, part) in parts.withIndex()) {
                        sentIntents.add(makeSentIntent(context, dest, part, simSlot, idx))
                    }
                    smsManager.sendMultipartTextMessage(dest, null, parts, sentIntents, null)
                    Log.d("SmsReceiver", "Sent to $dest")
                    diag(context, "sent OK to $dest")
                    sentOk = true
                } catch (e: Exception) {
                    Log.e("SmsReceiver", "Failed to send to $dest: $e")
                    diag(context, "FAIL $dest: ${e.message}")
                }
            }

            if (sentOk) {
                saveToHistory(
                    context,
                    sender = sender,
                    body = messageBody,
                    driverName = displayName,
                    destinations = cfg.destinations.joinToString(",")
                )
            }
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Send failed: $e")
            diag(context, "send error: ${e.message}")
        }
    }

    /**
     * انتخاب SmsManager سازگار با اندرویدهای قدیمی و جدید
     */
    private fun resolveSmsManager(context: Context, simSlot: Int): SmsManager {
        val subId = SimHelper.subscriptionIdForSlot(context, simSlot)
        return if (subId != null) {
            SmsManager.getSmsManagerForSubscriptionId(subId)
        } else {
            SmsManager.getDefault()
        }
    }

    private fun makeSentIntent(context: Context, dest: String, text: String, slot: Int, idx: Int): PendingIntent {
        val intent = Intent(context, SmsSentReceiver::class.java).apply {
            putExtra("dest", dest)
            putExtra("text", text)
            putExtra("slot", slot)
            putExtra("fallback", false)
        }
        return PendingIntent.getBroadcast(
            context,
            System.nanoTime().toInt() + idx,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * ذخیره تاریخچه ارسال با JSON واقعی (نسخه قبلی با پارس دستی خراب میشد)
     */
    private fun saveToHistory(
        context: Context,
        sender: String,
        body: String,
        driverName: String,
        destinations: String
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val existing = prefs.getString("flutter.forward_history", "[]") ?: "[]"
            val old = try { org.json.JSONArray(existing) } catch (e: Exception) { org.json.JSONArray() }

            val item = org.json.JSONObject().apply {
                put("time", System.currentTimeMillis())
                put("sender", sender)
                put("body", body)
                put("driver", driverName)
                put("dest", destinations)
            }
            val newArr = org.json.JSONArray()
            newArr.put(item)
            for (i in 0 until minOf(old.length(), 499)) {
                newArr.put(old.get(i))
            }
            prefs.edit().putString("flutter.forward_history", newArr.toString()).apply()
            Log.d("SmsReceiver", "History saved. count=${newArr.length()}")
        } catch (e: Exception) {
            Log.e("SmsReceiver", "saveToHistory failed: $e")
        }
    }
}
