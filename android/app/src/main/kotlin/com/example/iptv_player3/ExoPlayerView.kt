package com.example.iptv_player3

import android.content.Context
import android.view.View
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.audio.AudioCapabilities
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class ExoPlayerView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val playerView = PlayerView(context)
    private val channel = MethodChannel(messenger, "com.wallyt.iptv/exoplayer_$viewId")
    private var player: ExoPlayer? = null

    init {
        playerView.useController = false
        playerView.keepScreenOn = true

        val audioAttr = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
            .build()

        // Enable AC3/EAC3 passthrough — FireStick hardware Dolby decoder
        val audioSink = DefaultAudioSink.Builder(context)
            .setAudioCapabilities(AudioCapabilities.getCapabilities(context))
            .setEnableFloatOutput(false)
            .setEnableAudioTrackPlaybackParams(true)
            .build()

        val renderersFactory = DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
            .setEnableDecoderFallback(true)

        player = ExoPlayer.Builder(context, renderersFactory)
            .setAudioAttributes(audioAttr, true)
            .build()
            .also { exo ->
                playerView.player = exo
                exo.repeatMode = Player.REPEAT_MODE_OFF
                exo.playWhenReady = true
                exo.addListener(object : Player.Listener {
                    override fun onPlaybackStateChanged(state: Int) {
                        val map = mapOf(
                            "state" to when (state) {
                                Player.STATE_BUFFERING -> "buffering"
                                Player.STATE_READY     -> "ready"
                                Player.STATE_ENDED     -> "ended"
                                else                   -> "idle"
                            }
                        )
                        channel.invokeMethod("onState", map)
                    }
                    override fun onIsPlayingChanged(isPlaying: Boolean) {
                        channel.invokeMethod("onPlaying", mapOf("playing" to isPlaying))
                    }
                })
            }

        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val exo = player ?: run { result.error("NO_PLAYER", "player null", null); return }
        when (call.method) {
            "load" -> {
                val url = call.argument<String>("url") ?: run { result.error("NO_URL","",null); return }
                exo.stop()
                exo.clearMediaItems()
                exo.setMediaItem(MediaItem.fromUri(url))
                exo.prepare()
                exo.playWhenReady = true
                result.success(null)
            }
            "play"  -> { exo.play();  result.success(null) }
            "pause" -> { exo.pause(); result.success(null) }
            "seekTo" -> {
                val ms = call.argument<Int>("ms") ?: 0
                exo.seekTo(ms.toLong())
                result.success(null)
            }
            "getPosition" -> result.success(exo.currentPosition)
            "getDuration"  -> result.success(exo.duration)
            "isPlaying"    -> result.success(exo.isPlaying)
            "dispose" -> {
                exo.stop()
                exo.release()
                player = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun getView(): View = playerView

    override fun dispose() {
        player?.stop()
        player?.release()
        player = null
        channel.setMethodCallHandler(null)
    }
}
