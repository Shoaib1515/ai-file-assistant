import 'dart:async';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

const double _kButtonSize = 64;
const double _kChatWidth = 288;
const double _kChatHeight = 360;
const double _kMargin = 12;
const double _kTapMoveThreshold = 8; // px — below this, a drag is treated as a tap

class ChatMessage {
  final String text;
  final bool fromBot;
  const ChatMessage({required this.text, required this.fromBot});
}

/// App-wide chat state. This is a singleton (not per-widget State), so the
/// conversation, open/closed status, and bubble position all persist no
/// matter which screen the [ChatAssistantFab] is currently mounted on —
/// closing Home and opening Analyze reuses the same instance instead of
/// starting fresh.
class ChatAssistantState extends ChangeNotifier {
  ChatAssistantState._();
  static final ChatAssistantState instance = ChatAssistantState._();

  bool isOpen = false;
  bool hasShownIntroBubble = false;
  bool isSending = false;
  Offset? positionFraction; // 0..1, relative to whatever area it's drawn in

  /// The file the current screen has "in focus" (set by each screen's
  /// initState, e.g. AnalyzeScreen). The backend's /ask endpoint needs a
  /// file summary to answer anything useful, so when this is null the
  /// assistant answers locally instead of calling the backend.
  FileItem? _currentFile;

  final List<ChatMessage> messages = [
    const ChatMessage(
      text: "Hello! How can I help you with your files today?",
      fromBot: true,
    ),
  ];

  void setCurrentFile(FileItem? file) {
    _currentFile = file;
  }

  void open() {
    if (isOpen) return;
    isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!isOpen) return;
    isOpen = false;
    notifyListeners();
  }

  void toggle() => isOpen ? close() : open();

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSending) return;

    messages.add(ChatMessage(text: trimmed, fromBot: false));
    notifyListeners();

    final file = _currentFile;
    if (file == null || file.summary == null) {
      // No file open right now — the backend needs a file summary to
      // answer anything meaningful, so don't call it with nothing.
      messages.add(const ChatMessage(
        text: "Open a file from Home first, then ask me anything about it.",
        fromBot: true,
      ));
      notifyListeners();
      return;
    }

    isSending = true;
    notifyListeners();

    try {
      final answer = await ApiService.askAI(trimmed, file.summary!);
      messages.add(ChatMessage(text: answer, fromBot: true));
    } catch (e) {
      messages.add(ChatMessage(
        text: "Sorry, I couldn't get an answer: ${e.toString().replaceFirst('Exception: ', '')}",
        fromBot: true,
      ));
    } finally {
      isSending = false;
      notifyListeners();
    }
  }
}

/// A draggable "AI Assistant" floating bubble, styled like a professional
/// chat-head (Messenger / Intercom style):
/// - Follows the finger 1:1 while dragging.
/// - Springs to the nearest screen edge with a bounce when released.
/// - Opens/closes its chat window with a smooth scale + fade transition
///   anchored to the bubble, instead of popping instantly.
/// - Is always clamped to the actual visible area it's placed in (via
///   LayoutBuilder), so it can never end up underneath a bottom nav bar,
///   an app bar, or off-screen — no matter what screen it's dropped on.
///
/// Wrap your screen body in a Stack and drop this in as the LAST child so
/// it floats above everything, e.g.:
///
/// Stack(
///   children: [
///     yourScreenContent,
///     const ChatAssistantFab(),
///   ],
/// )
///
/// Important: place the Stack as the Scaffold's `body` (with your
/// bottomNavigationBar set separately on the Scaffold, not inside this
/// Stack) — that way the area this widget measures already excludes the
/// nav bar automatically.
class ChatAssistantFab extends StatefulWidget {
  final String hintBubbleText;

  const ChatAssistantFab({
    super.key,
    this.hintBubbleText = 'Any Help?',
  });

  @override
  State<ChatAssistantFab> createState() => _ChatAssistantFabState();
}

class _ChatAssistantFabState extends State<ChatAssistantFab>
    with TickerProviderStateMixin {
  final _chat = ChatAssistantState.instance;

  Offset? _position; // top-left of the button, relative to the measured area
  bool _showBubble = false;
  bool _isDragging = false;

  // Drag tracking
  Offset _dragStartPointer = Offset.zero;
  Offset _dragStartPosition = Offset.zero;
  double _dragDistance = 0;

  // Edge-snap animation
  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  // Chat open/close animation
  late final AnimationController _chatController;
  late final Animation<double> _chatScale;
  late final Animation<double> _chatFade;

  Timer? _introBubbleTimer;
  Timer? _introBubbleHideTimer;

  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() => _position = _snapAnimation!.value);
        }
      });

    // If the chat was already open on a previous screen, resume it here
    // instantly (value: 1) instead of replaying the open animation.
    _chatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
      value: _chat.isOpen ? 1 : 0,
    );
    _chatScale = CurvedAnimation(
      parent: _chatController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    _chatFade = CurvedAnimation(
      parent: _chatController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    // Keep this instance's open/close animation in sync whenever the
    // shared chat state changes — including from a different screen.
    _chat.addListener(_onChatChanged);

    if (!_chat.isOpen && !_chat.hasShownIntroBubble) {
      _chat.hasShownIntroBubble = true;
      _introBubbleTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted && !_chat.isOpen) {
          setState(() => _showBubble = true);
          _introBubbleHideTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(() => _showBubble = false);
          });
        }
      });
    }
  }

  void _onChatChanged() {
    if (_chat.isOpen) {
      _chatController.forward();
      if (mounted) setState(() => _showBubble = false);
    } else {
      _chatController.reverse();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _introBubbleTimer?.cancel();
    _introBubbleHideTimer?.cancel();
    _chat.removeListener(_onChatChanged);
    _controller.dispose();
    _snapController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    _controller.clear();
    _chat.sendMessage(text); // fires notifyListeners() itself as it progresses
    setState(() {});
  }

  /// Clamps [pos] so the button always stays fully inside [area] — the
  /// real, measured space this widget was given (already excludes any
  /// app bar / bottom nav bar since those live outside this Stack).
  Offset _clampToArea(Offset pos, Size area) {
    final maxX = (area.width - _kButtonSize - _kMargin).clamp(_kMargin, double.infinity);
    final maxY = (area.height - _kButtonSize - _kMargin).clamp(_kMargin, double.infinity);
    return Offset(
      pos.dx.clamp(_kMargin, maxX),
      pos.dy.clamp(_kMargin, maxY),
    );
  }

  void _onPanStart(DragStartDetails details, Offset currentPos) {
    _snapController.stop();
    _isDragging = true;
    _dragDistance = 0;
    _dragStartPointer = details.globalPosition;
    _dragStartPosition = currentPos;
  }

  void _onPanUpdate(DragUpdateDetails details, Size area) {
    final movedTotal = (details.globalPosition - _dragStartPointer).distance;
    final rawNewPos = _dragStartPosition + (details.globalPosition - _dragStartPointer);
    setState(() {
      _dragDistance = movedTotal;
      _position = _clampToArea(rawNewPos, area);
    });
  }

  void _onPanEnd(DragEndDetails details, Size area) {
    _isDragging = false;
    if (_dragDistance <= _kTapMoveThreshold) {
      // It was a tap, not a drag.
      _chat.toggle();
      setState(() {}); // clear dragging visuals
      return;
    }

    // Spring to the nearest horizontal edge, like a professional chat-head.
    final current = _position!;
    final centerX = current.dx + _kButtonSize / 2;
    final snapToRight = centerX > area.width / 2;
    final targetX = snapToRight ? area.width - _kButtonSize - _kMargin : _kMargin;
    final target = _clampToArea(Offset(targetX, current.dy), area);

    _snapAnimation = Tween<Offset>(begin: current, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    );
    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder gives us the REAL available space for this widget —
    // i.e. the Scaffold body area, already excluding the app bar and the
    // bottomNavigationBar. This is what fixes the "goes under the nav bar"
    // issue: we never clamp against the full device screen size, only
    // against the space we actually have.
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        return _buildContent(context, area);
      },
    );
  }

  Widget _buildContent(BuildContext context, Size area) {
    final defaultPos = _clampToArea(
      Offset(area.width - _kButtonSize - _kMargin, area.height - _kButtonSize - 96),
      area,
    );
    final pos = _position ?? defaultPos;
    final anchorRight = (pos.dx + _kButtonSize / 2) > area.width / 2;

    // Chat window anchoring: sits above the button, aligned to whichever
    // side the button is currently resting on. Falls back below if there
    // isn't enough vertical room above — and either way stays fully
    // clamped inside the measured area.
    double chatLeft = anchorRight ? (pos.dx + _kButtonSize) - _kChatWidth : pos.dx;
    chatLeft = chatLeft.clamp(_kMargin, (area.width - _kChatWidth - _kMargin).clamp(_kMargin, double.infinity));
    final bool chatFitsAbove = pos.dy - _kChatHeight - 12 > _kMargin;
    double chatTop = chatFitsAbove ? pos.dy - _kChatHeight - 12 : pos.dy + _kButtonSize + 12;
    chatTop = chatTop.clamp(_kMargin, (area.height - _kChatHeight - _kMargin).clamp(_kMargin, double.infinity));

    // Hint bubble: small, sits just above the button on the same side.
    const bubbleWidth = 160.0;
    double bubbleLeft = anchorRight ? (pos.dx + _kButtonSize) - bubbleWidth : pos.dx;
    bubbleLeft = bubbleLeft.clamp(_kMargin, (area.width - bubbleWidth - _kMargin).clamp(_kMargin, double.infinity));
    double bubbleTop = pos.dy - 56;
    bubbleTop = bubbleTop.clamp(_kMargin, area.height - _kMargin);

    final chatVisible = _chat.isOpen || _chatController.value > 0;

    return Stack(
      children: [
        // Full-area invisible barrier: tapping anywhere outside the chat
        // window / bubble / button closes the chat. Placed BELOW the chat
        // window and button in the Stack, so it never blocks taps on them
        // (Stack hit-tests the top-most child first).
        if (chatVisible)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _chat.close,
              child: const SizedBox.expand(),
            ),
          ),
        if (chatVisible)
          Positioned(
            left: chatLeft,
            top: chatTop,
            child: FadeTransition(
              opacity: _chatFade,
              child: ScaleTransition(
                scale: _chatScale,
                alignment: chatFitsAbove
                    ? (anchorRight ? Alignment.bottomRight : Alignment.bottomLeft)
                    : (anchorRight ? Alignment.topRight : Alignment.topLeft),
                // Swallow taps here so they don't fall through to the
                // barrier behind it and close the window while typing.
                child: GestureDetector(onTap: () {}, child: _buildChatWindow()),
              ),
            ),
          ),
        if (_showBubble && !_chat.isOpen)
          Positioned(
            left: bubbleLeft,
            top: bubbleTop,
            width: bubbleWidth,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Opacity(
                opacity: value.clamp(0, 1),
                child: Transform.scale(scale: value, child: child),
              ),
              child: _buildHintBubble(),
            ),
          ),
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onPanStart: (d) => _onPanStart(d, pos),
            onPanUpdate: (d) => _onPanUpdate(d, area),
            onPanEnd: (d) => _onPanEnd(d, area),
            child: AnimatedScale(
              scale: _isDragging ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Container(
                width: _kButtonSize,
                height: _kButtonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white70, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _isDragging ? 0.30 : 0.16),
                      blurRadius: _isDragging ? 24 : 14,
                      offset: Offset(0, _isDragging ? 10 : 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: AnimatedRotation(
                        turns: _chat.isOpen ? 0.02 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.smart_toy_rounded,
                            color: AppColors.primary, size: 32),
                      ),
                    ),
                    if (!_chat.isOpen)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHintBubble() {
    return GestureDetector(
      onTap: () => setState(() => _showBubble = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(4)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Text(
          widget.hintBubbleText,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.onPrimary),
        ),
      ),
    );
  }

  Widget _buildChatWindow() {
    return Container(
      width: _kChatWidth,
      height: _kChatHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('AI Assistant',
                    style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: _chat.close,
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: AppColors.surfaceContainerLow,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ListView.builder(
                itemCount: _chat.messages.length + (_chat.isSending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _chat.messages.length) {
                    // Trailing "typing..." bubble shown only while the
                    // real backend call in ChatAssistantState is in flight.
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)
                              .copyWith(bottomLeft: const Radius.circular(0)),
                        ),
                        child: const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final m = _chat.messages[i];
                  return Align(
                    alignment: m.fromBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      constraints: const BoxConstraints(maxWidth: 200),
                      decoration: BoxDecoration(
                        color: m.fromBot ? Colors.white : AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(12).copyWith(
                          bottomLeft: m.fromBot ? const Radius.circular(0) : null,
                          bottomRight: !m.fromBot ? const Radius.circular(0) : null,
                        ),
                      ),
                      child: Text(
                        m.text,
                        style: AppTextStyles.bodySm.copyWith(
                          color: m.fromBot ? AppColors.onSurface : AppColors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_chat.isSending,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: AppTextStyles.bodySm,
                  ),
                ),
                IconButton(
                  onPressed: _chat.isSending ? null : _send,
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}