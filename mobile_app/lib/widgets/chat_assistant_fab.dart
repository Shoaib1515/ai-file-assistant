import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

const double _kButtonSize = 64;
const double _kChatWidth = 310;
const double _kChatHeight = 440;
const double _kMargin = 12;
const double _kTapMoveThreshold = 8;

final List<Map<String, String>> _chatSuggestions = const [
  {
    'icon': '📊',
    'label': 'Summary',
    'prompt': 'Summarize key insights and stats from this file.',
  },
  {
    'icon': '⚠️',
    'label': 'Find Issues',
    'prompt': 'What columns have missing values, anomalies, or errors?',
  },
  {
    'icon': '💡',
    'label': 'Cleaning Tips',
    'prompt': 'Suggest the best cleaning and transformation steps for this data.',
  },
  {
    'icon': '🇵🇰',
    'label': 'Roman Urdu',
    'prompt': 'Is dataset ka main summary aur stats Roman Urdu mein samjha dein.',
  },
  {
    'icon': '📈',
    'label': 'Key Stats',
    'prompt': 'What are the main numeric statistics and column types in this file?',
  },
];

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
    FocusManager.instance.primaryFocus?.unfocus();
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
    _chatController.addStatusListener((status) {
      if (mounted) setState(() {});
    });

    // Keep this instance's open/close animation in sync whenever the
    // shared chat state changes — including from a different screen.
    _chat.addListener(_onChatChanged);

    if (!_chat.isOpen && !_chat.hasShownIntroBubble) {
      _chat.hasShownIntroBubble = true;
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && !_chat.isOpen) setState(() => _showBubble = true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showBubble = false);
        });
      });
    }
  }

  void _onChatChanged() {
    if (_chat.isOpen) {
      _chatController.forward();
      if (mounted) setState(() => _showBubble = false);
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      _chatController.reverse();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
        // window / bubble / button closes the chat. Only rendered when chat is open.
        if (_chat.isOpen)
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
                      color: Colors.black.withOpacity(_isDragging ? 0.30 : 0.16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: _kChatWidth,
      height: _kChatHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sleek Gradient Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI File Assistant',
                        style: AppTextStyles.labelMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Online • Ready to analyze',
                            style: AppTextStyles.bodySm.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _chat.close,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chat Messages List
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: ListView.builder(
                itemCount: _chat.messages.length + (_chat.isSending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _chat.messages.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10, left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomLeft: const Radius.circular(2),
                          ),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Analyzing dataset...',
                              style: AppTextStyles.bodySm.copyWith(
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final m = _chat.messages[i];
                  return Align(
                    alignment: m.fromBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 275),
                      decoration: BoxDecoration(
                        gradient: !m.fromBot
                            ? const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: m.fromBot
                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                            : null,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomLeft: m.fromBot ? const Radius.circular(2) : const Radius.circular(16),
                          bottomRight: !m.fromBot ? const Radius.circular(2) : const Radius.circular(16),
                        ),
                        border: m.fromBot
                            ? Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                width: 1,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.fromBot)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.smart_toy_outlined, size: 12, color: Color(0xFF6366F1)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Assistant',
                                    style: AppTextStyles.bodySm.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF6366F1),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildFormattedMessage(m.text, m.fromBot, context),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Quick Suggestion Chips Bar
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _chatSuggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final item = _chatSuggestions[idx];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _chat.isSending
                      ? null
                      : () {
                          _controller.text = item['prompt']!;
                          _send();
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item['icon']!, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(
                          item['label']!,
                          style: AppTextStyles.bodySm.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Input Area
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _controller,
                      enabled: !_chat.isSending,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask about your file...',
                        hintStyle: AppTextStyles.bodySm.copyWith(
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: AppTextStyles.bodySm.copyWith(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFF4F46E5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _chat.isSending ? null : _send,
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedMessage(String text, bool fromBot, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = fromBot
        ? (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155))
        : Colors.white;
    final baseStyle = AppTextStyles.bodySm.copyWith(
      color: defaultColor,
      height: 1.45,
      fontSize: 12,
    );

    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        if (widgets.isNotEmpty && i < lines.length - 1) {
          widgets.add(const SizedBox(height: 6));
        }
        continue;
      }

      // 1. Check if it's a standalone Section Header (e.g. **📊 Dataset Overview** or ### Header)
      final headerMatch = RegExp(r'^(?:#{1,4}\s+|\*\*)([^\*]+)\*\*$').firstMatch(trimmed);
      if (headerMatch != null) {
        final headerTitle = headerMatch.group(1)!.trim();
        widgets.add(
          Container(
            margin: EdgeInsets.only(top: widgets.isNotEmpty ? 10 : 2, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fromBot
                  ? (isDark
                      ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                      : const Color(0xFFEEF2FF))
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: fromBot
                    ? (isDark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                        : const Color(0xFFC7D2FE))
                    : Colors.white.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    headerTitle,
                    style: AppTextStyles.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: fromBot
                          ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA))
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 2. Check indentation level for nested sub-bullets
      final leadingSpaces = rawLine.indexOf(rawLine.trimLeft());
      final isSubBullet = leadingSpaces >= 2;

      // 3. Check for bullet points (e.g. - item, * item, • item, 1. item)
      final bulletMatch = RegExp(r'^(\*|-|•|\d+\.)\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        final content = bulletMatch.group(2)!;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: 2.5,
              bottom: 2.5,
              left: isSubBullet ? 14 : 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  child: Container(
                    width: isSubBullet ? 4 : 5,
                    height: isSubBullet ? 4 : 5,
                    decoration: BoxDecoration(
                      color: fromBot ? const Color(0xFF6366F1) : Colors.white70,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildRichInlineText(content, baseStyle, fromBot, isDark),
                ),
              ],
            ),
          ),
        );
      } else {
        // Normal paragraph line
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _buildRichInlineText(trimmed, baseStyle, fromBot, isDark),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildRichInlineText(String text, TextStyle baseStyle, bool fromBot, bool isDark) {
    final spans = <InlineSpan>[];
    
    // Pattern matches both **bold** and `code`
    final tokenPattern = RegExp(r'(\*\*([^*]+)\*\*|`([^`]+)`)');
    int lastEnd = 0;

    for (final match in tokenPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      if (match.group(2) != null) {
        // Bold match
        final boldContent = match.group(2)!;
        spans.add(TextSpan(
          text: boldContent,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: fromBot
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : Colors.white,
          ),
        ));
      } else if (match.group(3) != null) {
        // Inline code / file name backtick match
        final codeContent = match.group(3)!;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                width: 0.8,
              ),
            ),
            child: Text(
              codeContent,
              style: baseStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fromBot ? const Color(0xFF4F46E5) : Colors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }
}