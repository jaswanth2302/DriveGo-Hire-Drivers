import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A production-ready background video widget with lifecycle management.
///
/// Features:
/// - Autoplay with seamless looping
/// - Muted playback
/// - Full screen coverage (BoxFit.cover)
/// - Lifecycle-aware (pauses when app goes to background)
/// - Memory-safe disposal
/// - Optional dark overlay for text readability
class VideoBackground extends StatefulWidget {
  /// Path to the video asset (e.g., 'assets/video.mp4')
  final String assetPath;

  /// Overlay opacity (0.0 - 1.0). Recommended: 0.3 - 0.5
  final double overlayOpacity;

  /// Overlay color. Default is black.
  final Color overlayColor;

  /// Child widget to display on top of the video
  final Widget? child;

  /// Callback when video is initialized
  final VoidCallback? onInitialized;

  const VideoBackground({
    super.key,
    required this.assetPath,
    this.overlayOpacity = 0.4,
    this.overlayColor = Colors.black,
    this.child,
    this.onInitialized,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      debugPrint('VideoBackground: Loading asset ${widget.assetPath}');
      _controller = VideoPlayerController.asset(widget.assetPath);

      await _controller.initialize();
      debugPrint('VideoBackground: Video initialized successfully');

      // Configure for background video
      _controller.setLooping(true);
      _controller.setVolume(0.0); // Muted
      _controller.play();

      if (mounted) {
        setState(() => _isInitialized = true);
        widget.onInitialized?.call();
      }
    } catch (e, stackTrace) {
      debugPrint('VideoBackground Error: $e');
      debugPrint('VideoBackground StackTrace: $stackTrace');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle lifecycle changes for battery optimization
    if (!_isInitialized) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller.pause();
        break;
      case AppLifecycleState.resumed:
        _controller.play();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Layer
        if (_isInitialized && !_hasError)
          _buildVideoLayer()
        else
          _buildPlaceholder(),

        // Dark Overlay for text readability
        Container(
          color: widget.overlayColor.withOpacity(widget.overlayOpacity),
        ),

        // Foreground Content
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _buildVideoLayer() {
    // Calculate aspect ratio for BoxFit.cover effect
    final videoAspect = _controller.value.aspectRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Simulate BoxFit.cover by scaling the video
        final screenAspect = constraints.maxWidth / constraints.maxHeight;

        double scale;
        if (videoAspect > screenAspect) {
          // Video is wider - scale by height
          scale = constraints.maxHeight / (constraints.maxWidth / videoAspect);
        } else {
          // Video is taller - scale by width
          scale = constraints.maxWidth / (constraints.maxHeight * videoAspect);
        }

        return ClipRect(
          child: Transform.scale(
            scale: scale.clamp(1.0, 3.0), // Clamp to prevent excessive scaling
            child: Center(
              child: AspectRatio(
                aspectRatio: videoAspect,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    // Gradient placeholder while video loads or on error
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.overlayColor,
            widget.overlayColor.withOpacity(0.8),
            Colors.grey.shade900,
          ],
        ),
      ),
    );
  }
}

/// A simplified version that just plays video without overlay
/// Use when you need more control over the overlay separately
class VideoBackgroundSimple extends StatefulWidget {
  final String assetPath;
  final BoxFit fit;

  const VideoBackgroundSimple({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoBackgroundSimple> createState() => _VideoBackgroundSimpleState();
}

class _VideoBackgroundSimpleState extends State<VideoBackgroundSimple>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.asset(widget.assetPath);
    await _controller?.initialize();
    _controller?.setLooping(true);
    _controller?.setVolume(0);
    _controller?.play();
    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const SizedBox.expand();
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
