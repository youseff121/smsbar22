package com.example.dalahoo_app

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager
import android.util.Log

// اگه ارسال با سیم‌کارت انتخابی شکست خورد، متن رو به تکه‌های کوچک‌تر می‌شکنه و با سیم‌کارت دیگه می‌فرسته
class SmsSentReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (resultCode == Activity.RESULT_OK) return
        try {
            Log.e("SmsSent", "send failed, code=$resultCode")
        } catch (e: Exception) {
            Log.e("SmsSent", "toast failed: $e")
        }

        if (intent.getBooleanExtra("fallback", false)) {
            Log.e("SmsSent", "fallback also failed: $resultCode")
            return
        }

        val dest = intent.getStringExtra("dest") ?: return
        val text = intent.getStringExtra("text") ?: return
        val slot = intent.getIntExtra("slot", 1)

        val otherSlot = if (slot == 1) 2 else 1
        val subId = SimHelper.subscriptionIdForSlot(context, otherSlot)
        if (subId == null) {
            Log.e("SmsSent", "no second sim for fallback")
            return
        }
        val smsManager = SmsManager.getSmsManagerForSubscriptionId(subId)

        val chunks = text.chunked(70)
        for (chunk in chunks) {
            val fb = Intent(context, SmsSentReceiver::class.java).apply {
                putExtra("fallback", true)
            }
            val pi = PendingIntent.getBroadcast(
                context,
                System.nanoTime().toInt(),
                fb,
                PendingIntent.FLAG_IMMUTABLE
            )
            smsManager.sendTextMessage(dest, null, chunk, pi, null)
        }
        Log.d("SmsSent", "fallback sent ${chunks.size} chunk(s) via sim $otherSlot")
    }
}
