import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_animations.dart';

const String _supportUrl = 'https://t.me/+GQf04WTt82o4ZmI8';

class SupportChatButton extends StatefulWidget {
  const SupportChatButton({super.key, this.bottomOffset});

  final double? bottomOffset;

  @override
  State<SupportChatButton> createState() => _SupportChatButtonState();
}

class _SupportChatButtonState extends State<SupportChatButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _pressController;
  late Animation<double> _pulseAnim;
  late Animation<double> _pressAnim;

  double _right = 24;
  double _bottom = 24;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pressController = AnimationController(
      vsync: this,
      duration: AppDurations.press,
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: AppEasing.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _openSupport() async {
    final url = Uri.parse(_supportUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      _right = 24;
      _bottom = 24 + (widget.bottomOffset ?? 0);
      _initialized = true;
    }

    return Positioned(
      right: _right,
      bottom: _bottom,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnim, _pressAnim]),
        builder: (context, _) {
          final scale = _pressAnim.value * (_pulseAnim.value - 1.0) + 1.0;
          return Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: _openSupport,
              onTapDown: (_) => _pressController.forward(),
              onTapUp: (_) => _pressController.reverse(),
              onTapCancel: () => _pressController.reverse(),
              onPanUpdate: (details) {
                setState(() {
                  _right -= details.delta.dx;
                  _bottom -= details.delta.dy;
                });
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'asset/bgLogo.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
