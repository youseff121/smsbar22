package com.example.dalahoo_app

import android.content.Context
import android.telephony.SubscriptionManager

object SimHelper {
    // slot: 1 یا 2 (شماره سیم‌کارت روی گوشی)
    fun subscriptionIdForSlot(context: Context, slot: Int): Int? {
        return try {
            val mgr = context.getSystemService(SubscriptionManager::class.java) ?: return null
            val subs = mgr.activeSubscriptionInfoList ?: return null
            subs.firstOrNull { it.simSlotIndex == slot - 1 }?.subscriptionId
        } catch (e: SecurityException) {
            null
        }
    }
}
