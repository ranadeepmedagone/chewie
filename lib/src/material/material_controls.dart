import 'dart:async';

// import 'package:chewie/src/helpers/utils.dart';
// import 'package:chewie/src/material/models/option_item.dart';
// import 'package:chewie/src/material/widgets/options_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../src/center_play_button.dart';
import '../../src/chewie_player.dart';
import '../../src/chewie_progress_colors.dart';
import '../../src/material/material_progress_bar.dart';
import '../../src/models/subtitle_model.dart';
import '../../src/notifiers/index.dart';

// import 'widgets/playback_speed_dialog.dart';

class MaterialControls extends StatefulWidget {
  const MaterialControls({
    Key? key,
    this.onClose,
  }) : super(key: key);

  final VoidCallback? onClose;

  @override
  State<StatefulWidget> createState() {
    return _MaterialControlsState();
  }
}

class _MaterialControlsState extends State<MaterialControls>
    with SingleTickerProviderStateMixin {
  late PlayerNotifier notifier;
  late VideoPlayerValue _latestValue;
  Timer? _hideTimer;
  Timer? _initTimer;
  late var _subtitlesPosition = const Duration();
  bool _subtitleOn = false;
  Timer? _showAfterExpandCollapseTimer;
  bool _dragging = false;
  bool _displayTapped = false;

  // final originalBarHeight = 48.0 * 1.25;
  final barHeight = 48.0 * 1.5;
  final marginSize = 5.0;

  late VideoPlayerController controller;
  ChewieController? _chewieController;
  // We know that _chewieController is set in didChangeDependencies
  ChewieController get chewieController => _chewieController!;

  @override
  void initState() {
    super.initState();
    // print("Init stateeeeee");
    notifier = Provider.of<PlayerNotifier>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
            context,
            chewieController.videoPlayerController.value.errorDescription!,
          ) ??
          const Center(
            child: Icon(
              Icons.error,
              color: Colors.white,
              size: 42,
            ),
          );
    }

    return GestureDetector(
      onTap: () => _cancelAndRestartTimer(),
      child: AbsorbPointer(
        absorbing: notifier.hideStuff,
        child: Stack(
          children: [
            if (_latestValue.isBuffering)
              Center(
                child: _buildIconbutton(
                  onTap: () {},
                  icon: null,
                  alwayShow: true,
                  iconWidget: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              )
            else
              _buildHitArea(),
            Column(
              children: [
                _buildTopBar(),
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    // if (_subtitleOn)
                    //   Transform.translate(
                    //     offset: Offset(0.0, notifier.hideStuff ? barHeight * 0.8 : 0.0),
                    //     child: _buildSubtitles(context, chewieController.subtitle!),
                    //   ),
                    _buildBottomBar(context),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _chewieController;
    _chewieController = ChewieController.of(context);
    controller = chewieController.videoPlayerController;

    if (_oldController != chewieController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildTopBar() {
    final isFinished = _latestValue.position >= _latestValue.duration;
    final showFullscreen = chewieController.allowFullScreen &&
        (!chewieController.fullScreenByDefault ||
            (chewieController.fullScreenByDefault && !chewieController.isFirstPlay)) &&
        !isFinished;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
      child: Row(
        children: [
          if (widget.onClose != null && !chewieController.isFirstPlay)
            _buildIconbutton(
              onTap: closePlayer,
              showWhenFinshedPlayingVideo: true,
              icon: Icons.close,
              padding: const EdgeInsets.all(4),
              constraints: BoxConstraints(
                maxHeight: 36,
                maxWidth: 36,
              ),
              iconSize: 24,
            ),
          if (showFullscreen) const Spacer(),
          if (showFullscreen)
            _buildIconbutton(
              padding: const EdgeInsets.all(4),
              constraints: BoxConstraints(
                maxHeight: 36,
                maxWidth: 36,
              ),
              iconSize: 24,
              // padding: EdgeInsets.zero,
              icon: chewieController.isFullScreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              onTap: () {
                chewieController.isFullScreen
                    ? chewieController.exitFullScreen()
                    : chewieController.enterFullScreen();
              },
            )
          // _buildSubtitleToggle(),
          // if (chewieController.showOptions) _buildOptionsButton(),
        ],
      ),
    );
  }

  // Widget _buildOptionsButton() {
  //   final options = <OptionItem>[
  //     OptionItem(
  //       onTap: () async {
  //         Navigator.pop(context);
  //         _onSpeedButtonTap();
  //       },
  //       iconData: Icons.speed,
  //       title: chewieController.optionsTranslation?.playbackSpeedButtonText ?? 'Playback speed',
  //     )
  //   ];

  //   if (chewieController.subtitle != null && chewieController.subtitle!.isNotEmpty) {
  //     options.add(
  //       OptionItem(
  //         onTap: () {
  //           _onSubtitleTap();
  //           Navigator.pop(context);
  //         },
  //         iconData: _subtitleOn ? Icons.closed_caption : Icons.closed_caption_off_outlined,
  //         title: chewieController.optionsTranslation?.subtitlesButtonText ?? 'Subtitles',
  //       ),
  //     );
  //   }

  //   if (chewieController.additionalOptions != null &&
  //       chewieController.additionalOptions!(context).isNotEmpty) {
  //     options.addAll(chewieController.additionalOptions!(context));
  //   }

  //   return AnimatedOpacity(
  //     opacity: notifier.hideStuff ? 0.0 : 1.0,
  //     duration: const Duration(milliseconds: 250),
  //     child: IconButton(
  //       onPressed: () async {
  //         _hideTimer?.cancel();

  //         if (chewieController.optionsBuilder != null) {
  //           await chewieController.optionsBuilder!(context, options);
  //         } else {
  //           await showModalBottomSheet<OptionItem>(
  //             context: context,
  //             isScrollControlled: true,
  //             useRootNavigator: true,
  //             builder: (context) => OptionsDialog(
  //               options: options,
  //               cancelButtonText: chewieController.optionsTranslation?.cancelButtonText,
  //             ),
  //           );
  //         }

  //         if (_latestValue.isPlaying) {
  //           _startHideTimer();
  //         }
  //       },
  //       icon: const Icon(
  //         Icons.more_vert,
  //         color: Colors.white,
  //       ),
  //     ),
  //   );
  // }

  Widget _buildSubtitles(BuildContext context, Subtitles subtitles) {
    if (!_subtitleOn) {
      return Container();
    }
    final currentSubtitle = subtitles.getByPosition(_subtitlesPosition);
    if (currentSubtitle.isEmpty) {
      return Container();
    }

    if (chewieController.subtitleBuilder != null) {
      return chewieController.subtitleBuilder!(
        context,
        currentSubtitle.first!.text,
      );
    }

    return Padding(
      padding: EdgeInsets.all(marginSize),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0x96000000),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(
          currentSubtitle.first!.text as String,
          style: const TextStyle(
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  AnimatedOpacity _buildBottomBar(
    BuildContext context,
  ) {
    // final iconColor = Theme.of(context).textTheme.button!.color;
    final bool isFinished = _latestValue.position >= _latestValue.duration;

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        height: barHeight + (chewieController.isFullScreen ? 10.0 : 0),
        padding: EdgeInsets.only(
          left: 20,
          bottom: !chewieController.isFullScreen ? 10.0 : 0,
        ),
        child: SafeArea(
          bottom: chewieController.isFullScreen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flexible(
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: <Widget>[
              //       if (chewieController.isLive) const Expanded(child: Text('LIVE'))
              //       // else
              //       // const Spacer(),
              //       // _buildPosition(iconColor),
              //       // _buildExpandButton(),
              //     ],
              //   ),
              // ),
              if (!isFinished)
                SizedBox(
                  height: chewieController.isFullScreen ? 15.0 : 8,
                ),
              if (!chewieController.isLive && !chewieController.isFirstPlay)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      children: [
                        _buildProgressBar(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  GestureDetector _buildExpandButton() {
    final bool isFinished = _latestValue.position >= _latestValue.duration;

    return GestureDetector(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: barHeight + (chewieController.isFullScreen ? 15.0 : 0),
          margin: const EdgeInsets.only(right: 8.0),
          padding: const EdgeInsets.only(
            left: 8.0,
            right: 8.0,
          ),
          child: Icon(
            chewieController.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildIconbutton({
    required VoidCallback onTap,
    required IconData? icon,
    bool showWhenFinshedPlayingVideo = false,
    double iconSize = 32.0,
    EdgeInsetsGeometry padding = const EdgeInsets.all(8.0),
    bool alwayShow = false,
    Widget? iconWidget,
    BoxConstraints? constraints,
  }) {
    final isFinished = _latestValue.position >= _latestValue.duration;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: AnimatedOpacity(
            opacity: alwayShow
                ? 1
                : showWhenFinshedPlayingVideo && isFinished
                    ? 1.0
                    : !_dragging && !notifier.hideStuff
                        ? 1.0
                        : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: padding,
                // Always set the iconSize on the IconButton, not on the Icon itself:
                // https://github.com/flutter/flutter/issues/52980
                child: iconWidget ??
                    IconButton(
                      constraints: constraints,
                      iconSize: iconSize,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        icon,
                        // size: iconSize,
                        color: Colors.white,
                      ),
                      onPressed: onTap,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    final bool isFinished = _latestValue.position >= _latestValue.duration;

    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 60),
      child: Column(
        children: [
          // if (isFinished && widget.onClose != null)
          //   Expanded(
          //     child: _buildIconbutton(
          //       onTap: closePlayer,
          //       icon: Icons.close,
          //     ),
          //   ),
          // if (isFinished)
          //   const SizedBox(
          //     height: 8,
          //   ),
          if (!chewieController.isFirstPlay || isFinished)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_latestValue.isPlaying) {
                    if (_displayTapped) {
                      // setState(() {
                      notifier.hideStuff = true;
                      // });
                    } else {
                      _cancelAndRestartTimer();
                    }
                  } else {
                    _playPause();

                    // setState(() {
                    notifier.hideStuff = true;
                    // });
                  }
                },
                child: CenterPlayButton(
                  backgroundColor: Colors.black54,
                  iconColor: Colors.white,
                  isFinished: isFinished,
                  isPlaying: controller.value.isPlaying,
                  show: !_dragging && !notifier.hideStuff,
                  onPressed: _playPause,
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  // Future<void> _onSpeedButtonTap() async {
  //   _hideTimer?.cancel();

  //   final chosenSpeed = await showModalBottomSheet<double>(
  //     context: context,
  //     isScrollControlled: true,
  //     useRootNavigator: true,
  //     builder: (context) => PlaybackSpeedDialog(
  //       speeds: chewieController.playbackSpeeds,
  //       selected: _latestValue.playbackSpeed,
  //     ),
  //   );

  //   if (chosenSpeed != null) {
  //     controller.setPlaybackSpeed(chosenSpeed);
  //   }

  //   if (_latestValue.isPlaying) {
  //     _startHideTimer();
  //   }
  // }

  // Widget _buildPosition(Color? iconColor) {
  //   final position = _latestValue.position;
  //   final duration = _latestValue.duration;

  //   return RichText(
  //     text: TextSpan(
  //       text: '${formatDuration(position)} ',
  //       children: <InlineSpan>[
  //         TextSpan(
  //           text: '/ ${formatDuration(duration)}',
  //           style: TextStyle(
  //             fontSize: 14.0,
  //             color: Colors.white.withOpacity(.75),
  //             fontWeight: FontWeight.normal,
  //           ),
  //         )
  //       ],
  //       style: const TextStyle(
  //         fontSize: 14.0,
  //         color: Colors.white,
  //         fontWeight: FontWeight.bold,
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildSubtitleToggle() {
  //   //if don't have subtitle hiden button
  //   if (chewieController.subtitle?.isEmpty ?? true) {
  //     return Container();
  //   }
  //   return GestureDetector(
  //     onTap: _onSubtitleTap,
  //     child: Container(
  //       height: barHeight,
  //       color: Colors.transparent,
  //       padding: const EdgeInsets.only(
  //         left: 12.0,
  //         right: 12.0,
  //       ),
  //       child: Icon(
  //         _subtitleOn ? Icons.closed_caption : Icons.closed_caption_off_outlined,
  //         color: _subtitleOn ? Colors.white : Colors.grey[700],
  //       ),
  //     ),
  //   );
  // }

  void closePlayer() {
    widget.onClose!();
  }

  // void _onSubtitleTap() {
  //   setState(() {
  //     _subtitleOn = !_subtitleOn;
  //   });
  // }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      notifier.hideStuff = false;
      _displayTapped = true;
    });
  }

  Future<void> _initialize() async {
    _subtitleOn = chewieController.subtitle?.isNotEmpty ?? false;
    controller.addListener(_updateState);

    _updateState();

    if (controller.value.isPlaying || chewieController.autoPlay) {
      _startHideTimer();
    }

    if (chewieController.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        setState(() {
          notifier.hideStuff = false;
        });
      });
    }
  }

  void _onExpandCollapse() {
    setState(() {
      notifier.hideStuff = true;

      chewieController.toggleFullScreen();
      _showAfterExpandCollapseTimer = Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _cancelAndRestartTimer();
        });
      });
    });
  }

  void _playPause() {
    final isFinished = _latestValue.position >= _latestValue.duration;

    setState(() {
      if (controller.value.isPlaying) {
        notifier.hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
      } else {
        _cancelAndRestartTimer();

        if (!controller.value.isInitialized) {
          controller.initialize().then((_) {
            controller.play();
          });
        } else {
          if (isFinished) {
            controller.seekTo(const Duration());
          }
          controller.play();
        }
      }
    });
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        notifier.hideStuff = true;
      });
    });
  }

  void _updateState() {
    if (!mounted) return;
    setState(() {
      _latestValue = controller.value;
      _subtitlesPosition = controller.value.position;
      final isFinished = _latestValue.position >= _latestValue.duration;

      if (isFinished) {
        if (chewieController.isFirstPlay) {
          chewieController.isFirstPlay = false;
          if (chewieController.fullScreenByDefault && chewieController.isFullScreen) {
            chewieController.exitFullScreen();
          }
        }
        notifier.hideStuffNoState(false);
      }
    });
  }

  Widget _buildProgressBar() {
    final bool isFinished = _latestValue.position >= _latestValue.duration;
    if (isFinished) {
      return Container();
    } else {
      return Expanded(
        child: MaterialVideoProgressBar(
          controller,
          onDragStart: () {
            setState(() {
              _dragging = true;
            });

            _hideTimer?.cancel();
          },
          onDragEnd: () {
            setState(() {
              _dragging = false;
            });

            _startHideTimer();
          },
          colors: chewieController.materialProgressColors ??
              ChewieProgressColors(
                playedColor: Theme.of(context).accentColor,
                handleColor: Theme.of(context).accentColor,
                bufferedColor: Theme.of(context).backgroundColor.withOpacity(0.5),
                backgroundColor: Theme.of(context).disabledColor.withOpacity(.5),
              ),
        ),
      );
    }
  }
}
