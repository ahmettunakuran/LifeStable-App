class HelpBotResponse {
  final String answer;
  final String sourceDocId;
  final double confidenceScore;
  final bool usedCache;
  final bool usedFallback;
  final String? queryId;

  /// 2-3 related follow-up questions shown below the assistant's answer.
  final List<String> followUpSuggestions;

  const HelpBotResponse({
    required this.answer,
    required this.sourceDocId,
    required this.confidenceScore,
    required this.usedCache,
    required this.usedFallback,
    this.queryId,
    this.followUpSuggestions = const [],
  });
}
