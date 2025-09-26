package com.example.call_recorder_vtx

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log

class PhoneStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("bubble_prefs", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("service_enabled", true)

        if (!enabled) {
            Log.d("PhoneStateReceiver", "Service disabled by toggle, ignoring call state")
            return
        }

        val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
        Log.d("PhoneStateReceiver", "Phone state changed: $stateStr")

        when (stateStr) {
            TelephonyManager.EXTRA_STATE_RINGING,
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                Log.d("PhoneStateReceiver", "Call active → starting bubble")
                val i = Intent(context, OverlayBubbleService::class.java)
                i.action = OverlayBubbleService.ACTION_START
                context.startForegroundService(i)
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                Log.d("PhoneStateReceiver", "Call ended → stopping bubble")
                val i = Intent(context, OverlayBubbleService::class.java)
                i.action = OverlayBubbleService.ACTION_STOP
                context.startForegroundService(i)
            }
        }
    }
}
