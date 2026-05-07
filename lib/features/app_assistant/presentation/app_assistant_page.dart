import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/constants/app_colors.dart';
import '../../../app/router/app_routes.dart';
import '../../../features/assistant/presentation/widgets/chat_bubble.dart';
import '../logic/app_assistant_cubit.dart';

class AppAssistantPage extends StatelessWidget {
  const AppAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppAssistantCubit(),
      child: const _AppAssistantView(),
    );
  }
}

class _AppAssistantView extends StatefulWidget {
  const _AppAssistantView();
  @override
  State<_AppAssistantView> createState() => _AppAssistantViewState();
}

class _AppAssistantViewState extends State<_AppAssistantView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<AppAssistantCubit>().ask(text);
    _controller.clear();
    _focusNode.unfocus();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D0D),
              Color(0xFF1A1200),
              Color(0xFF0D0D0D),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocConsumer<AppAssistantCubit, AppAssistantState>(
            listenWhen: (prev, curr) => prev.status != curr.status,
            listener: (context, state) {
              if (!state.isResponding) _scrollToBottom();
              if (state.status == AppAssistantStatus.error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.cardBg,
                    content: const Text(
                      'Could not get an answer. Please try again.',
                      style: TextStyle(color: Colors.white),
                    ),
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: AppColors.gold,
                      onPressed: () =>
                          context.read<AppAssistantCubit>().clearError(),
                    ),
                  ),
                );
              }
            },
            builder: (context, state) {
              return Column(
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: state.showWelcome
                        ? _buildWelcome(context)
                        : _buildChatList(state),
                  ),
                  _buildInputArea(context, state),
                  _buildBottomNav(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withOpacity(0.08),
              border: Border.all(color: AppColors.gold.withOpacity(0.2)),
            ),
            child: const Icon(Icons.menu_book_outlined,
                color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.goldLight, AppColors.gold],
                ).createShader(bounds),
                child: const Text(
                  'App Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'Answers about LifeStable',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Welcome screen ────────────────────────────────────────────────────────

  Widget _buildWelcome(BuildContext context) {
    final suggestions = [
      'How do I create a domain?',
      'How does the habit streak work?',
      'Nasıl görev oluşturabilirim?',
      'How do I sync Google Calendar?',
      'How do I join a team?',
      'Uygulama çevrimdışı çalışır mı?',
    ];

    return Column(
      children: [
        const Spacer(),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [AppColors.goldLight, AppColors.gold],
          ).createShader(b),
          child: const Icon(Icons.quiz_outlined, color: Colors.white, size: 52),
        ),
        const SizedBox(height: 18),
        const Text(
          'App Assistant',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask me anything about how LifeStable works.\nI answer in your language — EN or TR.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: suggestions
                .map((s) => _SuggestionChip(
                      label: s,
                      onTap: () {
                        _controller.text = s;
                        _send(context);
                      },
                    ))
                .toList(),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  // ── Chat list ─────────────────────────────────────────────────────────────

  Widget _buildChatList(AppAssistantState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length,
      itemBuilder: (_, i) => ChatBubble(message: state.messages[i]),
    );
  }

  // ── Input area ────────────────────────────────────────────────────────────

  Widget _buildInputArea(BuildContext context, AppAssistantState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          top: BorderSide(color: AppColors.gold.withOpacity(0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !state.isResponding,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: state.isResponding
                      ? 'Looking up answer…'
                      : 'Ask about LifeStable…',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: AppColors.gold.withOpacity(0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: AppColors.gold.withOpacity(0.4),
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(context),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _buildSendButton(context, state.isResponding),
        ],
      ),
    );
  }

  Widget _buildSendButton(BuildContext context, bool isResponding) {
    return GestureDetector(
      onTap: isResponding ? null : () => _send(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isResponding
              ? null
              : const LinearGradient(
                  colors: [AppColors.goldLight, AppColors.gold],
                ),
          color: isResponding ? Colors.white.withOpacity(0.05) : null,
          border: Border.all(
            color: AppColors.gold.withOpacity(isResponding ? 0.1 : 0.0),
          ),
        ),
        child: isResponding
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold.withOpacity(0.6),
                ),
              )
            : const Icon(Icons.arrow_upward_rounded,
                color: Colors.black, size: 20),
      ),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          top: BorderSide(color: AppColors.gold.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navBtn(context, Icons.group_outlined, 'Team', AppRoutes.teamDashboard),
          _navBtn(context, Icons.calendar_month_outlined, 'Calendar', AppRoutes.calendar),
          _navBtn(context, Icons.dashboard_outlined, 'Dashboard', AppRoutes.homeDashboard),
          _navBtn(context, Icons.local_fire_department_outlined, 'Habit', AppRoutes.habitTracker),
        ],
      ),
    );
  }

  Widget _navBtn(BuildContext context, IconData icon, String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold.withOpacity(0.6), size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
