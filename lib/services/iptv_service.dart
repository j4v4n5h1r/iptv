import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

class IptvService {
  VideoPlayerController? _controller;

  Future<void> initializePlayer(String url, BuildContext context) async {
    _controller = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/video.mp4'));

    await _controller!.initialize();
    _controller!.play();
  }

  VideoPlayerController? get controller => _controller;

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
