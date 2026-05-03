import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../logic/assistant_cubit.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  bool get _isUser => message.sender == MessageSender.user;
  bool get _hasSlots =>
      !_isUser &&
      !message.slotsConsumed &&
      message.suggestedSlots != null &&
      message.suggestedSlots!.isNotEmpty;
  bool get _hasPending =>
      !_isUser && !message.pendingResolved && message.pendingEvent != null;
  bool get _hasSchedule =>
      !_isUser &&
      !message.pendingScheduleResolved &&
      message.pendingSchedule != null;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: _isUser ? 64 : 16,
          right: _isUser ? 16 : 64,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: _isUser
              ? const LinearGradient(
            colors: [AppColors.goldLight, AppColors.gold],
          )
              : null,
          color: _isUser ? null : const Color(0xFF1E1608),
          border: _isUser
              ? null
              : Border.all(color: AppColors.gold.withOpacity(0.15)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(_isUser ? 18 : 4),
            bottomRight: Radius.circular(_isUser ? 4 : 18),
          ),
        ),
        child: message.isLoading
            ? const _SkeletonLoader()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: _isUser ? Colors.black : Colors.white.withOpacity(0.85),
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: _isUser ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  if (_hasSlots) ...[
                    const SizedBox(height: 10),
                    _SlotsPanel(
                      slots: message.suggestedSlots!,
                      title: message.slotTitle,
                      messageId: message.id,
                    ),
                  ],
                  if (_hasPending) ...[
                    const SizedBox(height: 10),
                    _GuardrailPanel(
                      pending: message.pendingEvent!,
                      messageId: message.id,
                    ),
                  ],
                  if (_hasSchedule) ...[
                    const SizedBox(height: 10),
                    _ScheduleScopePanel(
                      pending: message.pendingSchedule!,
                      messageId: message.id,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SlotsPanel extends StatelessWidget {
  final List<SuggestedSlot> slots;
  final String? title;
  final String messageId;
  const _SlotsPanel({
    required this.slots,
    required this.title,
    required this.messageId,
  });

  String _two(int v) => v.toString().padLeft(2, '0');

  String _label(SuggestedSlot s) {
    final d = '${_two(s.startTime.day)}.${_two(s.startTime.month)}';
    final start = '${_two(s.startTime.hour)}:${_two(s.startTime.minute)}';
    final end = '${_two(s.endTime.hour)}:${_two(s.endTime.minute)}';
    return '$d  $start – $end';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...slots.map((s) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => _onAccept(context, s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available, color: AppColors.gold, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _label(s),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.add_circle_outline, color: AppColors.gold, size: 18),
                    ],
                  ),
                ),
              ),
            )),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.read<AssistantCubit>().requestLighterDay(),
                icon: const Icon(Icons.refresh, size: 16, color: AppColors.gold),
                label: const Text(
                  'Find a lighter day',
                  style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.gold.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onAccept(BuildContext context, SuggestedSlot slot) async {
    final controller = TextEditingController(text: title ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1608),
        title: const Text('Etkinlik Başlığı', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Örn: Çalışma bloğu',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.gold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Ekle', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (!context.mounted) return;
    await context.read<AssistantCubit>().acceptSlot(
          messageId: messageId,
          slot: slot,
          title: result,
        );
  }
}

class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double widthFraction) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth * widthFraction;
            return Container(
              height: 10,
              width: w,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment(-1.0 + 2.0 * t, 0),
                  end: Alignment(1.0 + 2.0 * t, 0),
                  colors: [
                    Colors.white.withOpacity(0.04),
                    AppColors.gold.withOpacity(0.18),
                    Colors.white.withOpacity(0.04),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _bar(0.95),
          _bar(0.75),
          _bar(0.55),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final t = (_controller.value + i / 3) % 1.0;
              final scale = 1.0 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 7 * scale,
                height: 7 * scale,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _GuardrailPanel extends StatelessWidget {
  final PendingEvent pending;
  final String messageId;
  const _GuardrailPanel({required this.pending, required this.messageId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.health_and_safety_outlined, color: Colors.redAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Health guardrail',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.read<AssistantCubit>().requestBreakInstead(messageId),
                  icon: const Icon(Icons.coffee, size: 14, color: AppColors.gold),
                  label: const Text(
                    'Find lighter day',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.gold.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.read<AssistantCubit>().confirmPendingEvent(messageId),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text(
                    'Confirm anyway',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.85),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleScopePanel extends StatelessWidget {
  final PendingScheduleImport pending;
  final String messageId;
  const _ScheduleScopePanel({required this.pending, required this.messageId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssistantCubit>();
    final count = pending.entries.length;

    Widget chip(String label, IconData icon, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.gold, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count ders bulundu',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('Sadece bu hafta', Icons.today, () {
              cubit.acceptScheduleImport(
                messageId: messageId,
                weeks: 1,
              );
            }),
            chip('Haftaya', Icons.next_week, () {
              cubit.acceptScheduleImport(
                messageId: messageId,
                weeks: 1,
                weekOffset: 1,
              );
            }),
            chip('Dönem (14 hafta)', Icons.event_repeat, () {
              cubit.acceptScheduleImport(
                messageId: messageId,
                weeks: 14,
              );
            }),
            GestureDetector(
              onTap: () => cubit.dismissScheduleImport(messageId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  'İptal',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}