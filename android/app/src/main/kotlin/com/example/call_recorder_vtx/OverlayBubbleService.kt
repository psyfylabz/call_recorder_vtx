package com.example.call_recorder_vtx

import android.app.*
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.*
import android.widget.ImageView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import java.io.File

class OverlayBubbleService : Service() {

    companion object {
        const val ACTION_START = "start_overlay"
        const val ACTION_STOP = "stop_overlay"
        const val ACTION_TOGGLE_RECORD = "toggle_record"
        private const val CHANNEL_ID = "overlay_channel"
        var isRunning = false
    }

    private lateinit var windowManager: WindowManager
    private var bubbleView: View? = null
    private var isRecording = false
    private var currentContact: String = "Unknown" // 👈 trenutno aktivni kontakt/broj

    private val prefs: SharedPreferences by lazy {
        getSharedPreferences("bubble_prefs", MODE_PRIVATE)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                startForegroundServiceProper("Bubble overlay running")
                showBubble()
                scheduleLastCallCheck()
            }
            ACTION_STOP -> removeBubble()
            ACTION_TOGGLE_RECORD -> toggleRecording()
            else -> {
                startForegroundServiceProper("Bubble overlay running")
                showBubble()
                scheduleLastCallCheck()
            }
        }
        return START_STICKY
    }

    private fun startForegroundServiceProper(text: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Overlay Bubble",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC  // 👈 forsiraj vidljivost na lock screenu
            }
            manager.createNotificationChannel(channel)
        }

        val toggleIntent = Intent(this, OverlayBubbleService::class.java).apply {
            action = ACTION_TOGGLE_RECORD
        }
        val togglePending = PendingIntent.getService(
            this, 0, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val mainIntent = Intent(this, MainActivity::class.java)
        val mainPending = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Call Recorder VTX")
            .setContentText(text)
            .setSmallIcon(if (isRecording) R.drawable.ic_mic_recording else R.drawable.ic_mic_idle)
            .setOngoing(true)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .addAction(
                if (isRecording) R.drawable.ic_mic_idle else R.drawable.ic_mic_recording,
                if (isRecording) "Stop" else "Start",
                togglePending
            )
            .setContentIntent(mainPending)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

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

    private fun updateNotification() {
        val manager = getSystemService(NotificationManager::class.java)

        val toggleIntent = Intent(this, OverlayBubbleService::class.java).apply {
            action = ACTION_TOGGLE_RECORD
        }
        val togglePending = PendingIntent.getService(
            this, 0, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val mainIntent = Intent(this, MainActivity::class.java)
        val mainPending = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val statusText = if (isRecording) {
            "Recording call with $currentContact"
        } else {
            "Active call with $currentContact"
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Call Recorder VTX")
            .setContentText(statusText)
            .setSmallIcon(if (isRecording) R.drawable.ic_mic_recording else R.drawable.ic_mic_idle)
            .setOngoing(true)
            .setStyle(NotificationCompat.BigTextStyle().bigText(statusText))
            .addAction(
                if (isRecording) R.drawable.ic_mic_idle else R.drawable.ic_mic_recording,
                if (isRecording) "Stop" else "Start",
                togglePending
            )
            .setContentIntent(mainPending)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        manager.notify(1, notification)
    }

    private fun toggleRecording() {
        isRecording = !isRecording
        val bubbleIcon = bubbleView?.findViewById<ImageView>(R.id.bubbleIcon)
        if (isRecording) {
            bubbleIcon?.setImageResource(R.drawable.ic_mic_recording)
            Toast.makeText(this, "Recording started", Toast.LENGTH_SHORT).show()
        } else {
            bubbleIcon?.setImageResource(R.drawable.ic_mic_idle)
            Toast.makeText(this, "Recording stopped", Toast.LENGTH_SHORT).show()
        }
        updateNotification()
    }

    private fun scheduleLastCallCheck() {
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                val recDir = File("/storage/emulated/0/Recordings/Call")
                if (recDir.exists() && recDir.isDirectory) {
                    val lastFile = recDir.listFiles()?.maxByOrNull { it.lastModified() }
                    if (lastFile != null) {
                        var name = lastFile.nameWithoutExtension
                        if (name.startsWith("Call recording ")) {
                            name = name.removePrefix("Call recording ").trim()
                        }
                        val parts = name.split("_")
                        if (parts.isNotEmpty()) {
                            currentContact = parts[0] // broj ili ime
                            updateNotification()
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, 3000)
    }

    private fun showBubble() {
        if (isRunning) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val inflater = LayoutInflater.from(this)
        bubbleView = inflater.inflate(R.layout.overlay_bubble, null)

        val bubbleIcon = bubbleView!!.findViewById<ImageView>(R.id.bubbleIcon)
        bubbleIcon.setImageResource(R.drawable.ic_mic_idle)

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
                            toggleRecording()
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
