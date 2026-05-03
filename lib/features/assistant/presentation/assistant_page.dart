import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../shared/constants/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../app/router/app_routes.dart';

import '../logic/assistant_cubit.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/image_input_button.dart';
import 'widgets/suggestion_chips.dart';
import 'widgets/voice_input_button.dart';

import '../../tasks/domain/repositories/task_repository.dart';
import '../../calendar/domain/repositories/calendar_repository.dart';
import '../../dashboard/domain/repositories/domain_repository.dart';
import '../../../core/logic/ai_pipeline_service.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AssistantCubit(
        taskRepository: context.read<TaskRepository>(),
        calendarRepository: context.read<CalendarRepository>(),
        domainRepository: context.read<DomainRepository>(),
        aiPipeline: AiPipelineService(),
      ),
      child: const _AssistantView(),
    );
  }
}

class _AssistantView extends StatefulWidget {
  const _AssistantView();
  @override
  State<_AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<_AssistantView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  String? _lastShownUndoableToken;
  Timer? _undoableDismissTimer;
  String? _attachedImagePath;

  @override
  void dispose() {
    _undoableDismissTimer?.cancel();
    _textController.dispose();
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

  void _sendMessage(BuildContext context, String text) {
    final trimmed = text.trim();
    final imagePath = _attachedImagePath;

    if (imagePath != null) {
      context.read<AssistantCubit>().sendImage(
            imagePath,
            caption: trimmed.isEmpty ? null : trimmed,
          );
      setState(() => _attachedImagePath = null);
    } else {
      if (trimmed.isEmpty) return;
      context.read<AssistantCubit>().sendMessage(trimmed);
    }

    _textController.clear();
    _focusNode.unfocus();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
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
          child: BlocConsumer<AssistantCubit, AssistantState>(
            listenWhen: (prev, curr) =>
                prev.status != curr.status ||
                prev.errorMessage != curr.errorMessage ||
                prev.undoable?.token != curr.undoable?.token,
            listener: (context, state) {
              if (state.status == AssistantStatus.responding ||
                  state.status == AssistantStatus.idle ||
                  state.status == AssistantStatus.navigate) {
                _scrollToBottom();
              }
              if (state.undoable != null &&
                  state.undoable!.token != _lastShownUndoableToken) {
                final undoable = state.undoable!;
                _lastShownUndoableToken = undoable.token;
                final cubit = context.read<AssistantCubit>();
                final messenger = ScaffoldMessenger.of(context);
                _undoableDismissTimer?.cancel();
                messenger.hideCurrentSnackBar();
                final controller = messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      undoable.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: const Color(0xFF2A1D08),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'Geri al',
                      textColor: AppColors.gold,
                      onPressed: () => cubit.undoLast(undoable.token),
                    ),
                  ),
                );
                _undoableDismissTimer = Timer(const Duration(seconds: 4), () {
                  messenger.hideCurrentSnackBar();
                });
                controller.closed.then((_) {
                  _undoableDismissTimer?.cancel();
                  if (mounted) cubit.clearUndoable();
                });
              }
              if (state.status == AssistantStatus.navigate && state.redirectTo != null) {
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(
                      context,
                      state.redirectTo!,
                      arguments: state.redirectArgs,
                    );
                  }
                });
              }
              if (state.status == AssistantStatus.error &&
                  state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: Colors.red.shade900,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                context.read<AssistantCubit>().clearError();
              }
            },
            builder: (context, state) {
              return Column(
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: state.showWelcome
                        ? _buildWelcomeView(context)
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
            child: const Icon(Icons.smart_toy_outlined,
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
                  'LifeStable AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'Always here for you',
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

  // ── Welcome ekranı ────────────────────────────────────────────────────────

  Widget _buildWelcomeView(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.goldLight, AppColors.gold],
          ).createShader(bounds),
          child: const Icon(Icons.auto_awesome,
              color: Colors.white, size: 56),
        ),
        const SizedBox(height: 20),
        const Text(
          'Hello!\nHow Can I Help You?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'You can ask me anything about\nyour tasks, habits, or calendar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const Spacer(),
        SuggestionChips(
          onSuggestionTap: (text) => _sendMessage(context, text),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── Mesaj listesi ─────────────────────────────────────────────────────────

  Widget _buildChatList(AssistantState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: state.messages.length,
      itemBuilder: (_, index) =>
          ChatBubble(message: state.messages[index]),
    );
  }

  // ── Input alanı ───────────────────────────────────────────────────────────

  Widget _buildInputArea(BuildContext context, AssistantState state) {
    final isResponding = state.status == AssistantStatus.responding;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          top: BorderSide(color: AppColors.gold.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachedImagePath != null) _buildAttachmentPreview(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ImageInputButton(
                onImageSelected: (path) {
                  setState(() => _attachedImagePath = path);
                  _focusNode.requestFocus();
                },
              ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !isResponding,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: isResponding
                      ? 'AI is thinking...'
                      : 'Type your message',
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10,
                  ),
                ),
                onSubmitted: (text) => _sendMessage(context, text),
              ),
            ),
          ),
              VoiceInputButton(
                isListening: state.isListening,
                onListeningChanged: (val) =>
                    context.read<AssistantCubit>().setListening(val),
                onTranscriptionReady: (text) {
                  // Fill the input field and focus it so the user can review
                  // (and edit) the transcription before tapping Send.
                  _textController.value = TextEditingValue(
                    text: text,
                    selection:
                        TextSelection.collapsed(offset: text.length),
                  );
                  _focusNode.requestFocus();
                },
              ),
              const SizedBox(width: 4),
              _buildSendButton(context, isResponding),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    final path = _attachedImagePath;
    if (path == null) return const SizedBox.shrink();
    final fileName = path.split('/').last;
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _attachedImagePath = null),
            child: Icon(Icons.close,
                color: Colors.white.withOpacity(0.6), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(BuildContext context, bool isResponding) {
    return GestureDetector(
      onTap: isResponding
          ? null
          : () => _sendMessage(context, _textController.text),
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
          color: isResponding
              ? Colors.white.withOpacity(0.05)
              : null,
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

  // ── Bottom Nav (diğer sayfalarla tutarlı) ────────────────────────────────

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
          _navBtn(context, Icons.group_outlined, 'Team',
              AppRoutes.teamDashboard),
          _navBtn(context, Icons.calendar_month_outlined, 'Calendar',
              AppRoutes.calendar),
          _navBtn(context, Icons.dashboard_outlined, 'Dashboard',
              AppRoutes.homeDashboard),
          _navBtn(context, Icons.local_fire_department_outlined, 'Habit',
              AppRoutes.habitTracker),
        ],
      ),
    );
  }

  Widget _navBtn(BuildContext context, IconData icon, String label,
      String route) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: AppColors.gold.withOpacity(0.6), size: 22),
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

