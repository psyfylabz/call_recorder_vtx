package com.example.call_recorder_vtx

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.*
import android.widget.ImageView
import android.widget.Toast
import androidx.core.app.NotificationCompat

class OverlayBubbleService : Service() {

    companion object {
        const val ACTION_START = "start_overlay"
        const val ACTION_STOP = "stop_overlay"
        private const val CHANNEL_ID = "overlay_channel"
        var isRunning = false
    }

    private lateinit var windowManager: WindowManager
    private var bubbleView: View? = null
    private var isRecording = false

    private val prefs: SharedPreferences by lazy {
        getSharedPreferences("bubble_prefs", MODE_PRIVATE)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                startForegroundServiceProper()
                showBubble()
            }
            ACTION_STOP -> removeBubble()
            else -> {
                startForegroundServiceProper()
                showBubble()
            }
        }
        return START_STICKY
    }

    private fun startForegroundServiceProper() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Overlay Bubble",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Call Recorder VTX")
            .setContentText("Bubble overlay running")
            .setSmallIcon(R.drawable.ic_mic_idle)
            .setOngoing(true)
            .build()

        // Android 10+ zahteva tip; koristimo mediaPlayback (u manifestu i permission su dodati)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(1, notification)
        }
    }

    private fun showBubble() {
        if (isRunning) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val inflater = LayoutInflater.from(this)
        bubbleView = inflater.inflate(R.layout.overlay_bubble, null)

        val bubbleIcon = bubbleView!!.findViewById<ImageView>(R.id.bubbleIcon)
        bubbleIcon.setImageResource(R.drawable.ic_mic_idle)

        // poslednja pozicija
        val lastX = prefs.getInt("last_x", 200)
        val lastY = prefs.getInt("last_y", 400)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = lastX
        params.y = lastY

        // Drag + Tap
        bubbleIcon.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var touchX = 0f
            private var touchY = 0f
            private var moved = false

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        touchX = event.rawX
                        touchY = event.rawY
                        moved = false
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - touchX).toInt()
                        val dy = (event.rawY - touchY).toInt()
                        if (kotlin.math.abs(dx) > 10 || kotlin.math.abs(dy) > 10) {
                            moved = true
                            params.x = initialX + dx
                            params.y = initialY + dy
                            windowManager.updateViewLayout(bubbleView, params)
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!moved) {
                            isRecording = !isRecording
                            if (isRecording) {
                                bubbleIcon.setImageResource(R.drawable.ic_mic_recording)
                                // Toast može biti tih kad je app u pozadini – to je normalno
                                Toast.makeText(this@OverlayBubbleService, "Recording started", Toast.LENGTH_SHORT).show()
                            } else {
                                bubbleIcon.setImageResource(R.drawable.ic_mic_idle)
                                Toast.makeText(this@OverlayBubbleService, "Recording stopped", Toast.LENGTH_SHORT).show()
                            }
                        } else {
                            prefs.edit()
                                .putInt("last_x", params.x)
                                .putInt("last_y", params.y)
                                .apply()
                        }
                        return true
                    }
                }
                return false
            }
        })

        windowManager.addView(bubbleView, params)
        isRunning = true
    }

    private fun removeBubble() {
        if (isRunning && bubbleView != null) {
            windowManager.removeView(bubbleView)
            bubbleView = null
            isRunning = false
        }
        stopForeground(true)
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
