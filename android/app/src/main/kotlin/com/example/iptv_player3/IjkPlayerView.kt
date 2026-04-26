package com.example.iptv_player3

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import tv.danmaku.ijk.media.player.IjkMediaPlayer
import tv.danmaku.ijk.media.player.IMediaPlayer

class IjkPlayerView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.wallyt.iptv/exoplayer_$viewId")
    private val container = FrameLayout(context)
    private var player: IjkMediaPlayer? = null
    private var surfaceView: android.view.SurfaceView? = null

    init {
        IjkMediaPlayer.loadLibrariesOnce(null)
        IjkMediaPlayer.native_profileBegin("libijkplayer.so")
        channel.setMethodCallHandler(this)
    }

    private fun buildPlayer(): IjkMediaPlayer {
        val ijkPlayer = IjkMediaPlayer()
        // Enable software decode for AC3/EAC3
        ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", 0)
        ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", 1)
        ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "reconnect", 5)
        ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration", 2000000)
        ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "probesize", 2000000)
        ijkPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "dns_cache_clear", 1)

        ijkPlayer.setOnPreparedListener {
            channel.invokeMethod("onState", mapOf("state" to "ready"))
            ijkPlayer.start()
        }
        ijkPlayer.setOnInfoListener { _, what, _ ->
            when (what) {
                IMediaPlayer.MEDIA_INFO_BUFFERING_START ->
                    channel.invokeMethod("onState", mapOf("state" to "buffering"))
                IMediaPlayer.MEDIA_INFO_BUFFERING_END ->
                    channel.invokeMethod("onState", mapOf("state" to "ready"))
            }
            true
        }
        ijkPlayer.setOnVideoSizeChangedListener { _, _, _, _, _ ->
            channel.invokeMethod("onPlaying", mapOf("playing" to true))
        }
        ijkPlayer.setOnErrorListener { _, _, _ ->
            channel.invokeMethod("onState", mapOf("state" to "idle"))
            true
        }
        return ijkPlayer
    }

    private fun attachSurface(ijkPlayer: IjkMediaPlayer) {
        container.removeAllViews()
        val sv = android.view.SurfaceView(context)
        surfaceView = sv
        container.addView(sv, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
        sv.holder.addCallback(object : android.view.SurfaceHolder.Callback {
            override fun surfaceCreated(holder: android.view.SurfaceHolder) {
                ijkPlayer.setDisplay(holder)
            }
            override fun surfaceChanged(holder: android.view.SurfaceHolder, f: Int, w: Int, h: Int) {}
            override fun surfaceDestroyed(holder: android.view.SurfaceHolder) {
                ijkPlayer.setDisplay(null)
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> {
                val url = call.argument<String>("url") ?: run {
                    result.error("NO_URL", "", null); return
                }
                player?.release()
                val ijkPlayer = buildPlayer()
                attachSurface(ijkPlayer)
                player = ijkPlayer
                try {
                    ijkPlayer.dataSource = url
                    ijkPlayer.prepareAsync()
                    channel.invokeMethod("onState", mapOf("state" to "buffering"))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("LOAD_ERR", e.message, null)
                }
            }
            "play" -> { player?.start(); result.success(null) }
            "pause" -> { player?.pause(); result.success(null) }
            "seekTo" -> {
                val ms = call.argument<Int>("ms") ?: 0
                player?.seekTo(ms.toLong())
                result.success(null)
            }
            "getPosition" -> result.success(player?.currentPosition ?: 0L)
            "getDuration"  -> result.success(player?.duration ?: 0L)
            "isPlaying"    -> result.success(player?.isPlaying ?: false)
            "dispose" -> {
                player?.release()
                player = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        player?.release()
        player = null
        IjkMediaPlayer.native_profileEnd()
        channel.setMethodCallHandler(null)
    }
}
