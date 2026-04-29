class RagResult {
  final String docId;
  final String content;
  final String docType;
  final String sourceKey;
  final double similarity;
  final String titleType;

  const RagResult({
    required this.docId,
    required this.content,
    required this.docType,
    required this.sourceKey,
    required this.similarity,
    required this.titleType,
  });
}
