import 'package:flutter/material.dart';

class StreakIndicator extends StatefulWidget {
  final int streak;
  const StreakIndicator({super.key, required this.streak});

  @override
  State<StreakIndicator> createState() => _StreakIndicatorState();
}

class _StreakIndicatorState extends State<StreakIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(StreakIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streak > oldWidget.streak) {
      // Trigger a special pulse or just let the continuous one reflect the growth
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getIconSize() {
    if (widget.streak >= 8) return 32.0;
    if (widget.streak >= 4) return 26.0;
    if (widget.streak >= 1) return 20.0;
    return 18.0;
  }

  Color _getFlameColor() {
    if (widget.streak >= 8) return Colors.deepOrange;
    if (widget.streak >= 4) return Colors.orange;
    if (widget.streak >= 1) return Colors.orangeAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streak == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _animation,
          child: Icon(
            Icons.local_fire_department,
            color: _getFlameColor(),
            size: _getIconSize(),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${widget.streak}',
          style: TextStyle(
            color: _getFlameColor(),
            fontWeight: FontWeight.bold,
            fontSize: _getIconSize() * 0.7,
          ),
        ),
      ],
    );
  }
}
