import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/logic/ai_pipeline_service.dart';

/// Parses a class-schedule image into raw entry maps.
///
/// Strategy:
/// 1. ML Kit OCR returns text blocks with bounding boxes.
/// 2. We find blocks whose text matches a day name and record their X centres.
/// 3. Every other block below the header row is assigned to the day whose
///    header X is closest. This gives us per-day text deterministically,
///    without relying on an LLM to interpret a 2D layout.
/// 4. The per-day text is sent to Gemini for final parsing into
///    {title, dayOfWeek, startHour/Minute, endHour/Minute} entries.
class ScheduleImageParser {
  final AiPipelineService _aiPipeline;
  ScheduleImageParser(this._aiPipeline);

  static const Map<String, int> _dayKeywords = {
    'monday': 1, 'mon': 1, 'pazartesi': 1, 'pzt': 1, 'pzts': 1,
    'tuesday': 2, 'tue': 2, 'tues': 2, 'salı': 2, 'sali': 2, 'sal': 2,
    'wednesday': 3, 'wed': 3, 'çarşamba': 3, 'carsamba': 3, 'çar': 3, 'car': 3,
    'thursday': 4, 'thu': 4, 'thur': 4, 'thurs': 4, 'perşembe': 4, 'persembe': 4, 'per': 4,
    'friday': 5, 'fri': 5, 'cuma': 5, 'cum': 5,
    'saturday': 6, 'sat': 6, 'cumartesi': 6, 'cmt': 6,
    'sunday': 7, 'sun': 7, 'pazar': 7, 'paz': 7,
  };

  /// Returns parsed entries (raw maps) or null if the image isn't a schedule.
  Future<List<Map<String, dynamic>>?> parse(String imagePath) async {
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );

      // Step 1: locate day-header blocks.
      final dayHeaders = <int, ({double x, double y})>{};
      for (final block in result.blocks) {
        final text = _normalize(block.text);
        final dow = _dayKeywords[text];
        if (dow != null && !dayHeaders.containsKey(dow)) {
          dayHeaders[dow] = (
            x: block.boundingBox.center.dx,
            y: block.boundingBox.center.dy,
          );
        }
      }
      if (dayHeaders.length < 3) return null;

      final headerYMax =
          dayHeaders.values.map((h) => h.y).reduce((a, b) => a > b ? a : b);

      // Step 2: assign every other block to the nearest day column.
      final perDay = <int, List<TextBlock>>{
        for (final dow in dayHeaders.keys) dow: <TextBlock>[],
      };

      for (final block in result.blocks) {
        final text = _normalize(block.text);
        if (_dayKeywords.containsKey(text)) continue;
        final centerY = block.boundingBox.center.dy;
        if (centerY <= headerYMax + 5) continue; // header row or above

        final centerX = block.boundingBox.center.dx;
        int? bestDow;
        double bestDist = double.infinity;
        for (final e in dayHeaders.entries) {
          final d = (centerX - e.value.x).abs();
          if (d < bestDist) {
            bestDist = d;
            bestDow = e.key;
          }
        }
        if (bestDow != null) {
          perDay[bestDow]!.add(block);
        }
      }

      // Step 3: build per-day text in top-to-bottom order.
      final perDayText = <int, String>{};
      for (final entry in perDay.entries) {
        if (entry.value.isEmpty) continue;
        entry.value.sort(
          (a, b) => a.boundingBox.top.compareTo(b.boundingBox.top),
        );
        perDayText[entry.key] =
            entry.value.map((b) => b.text.trim()).where((t) => t.isNotEmpty).join('\n');
      }
      if (perDayText.isEmpty) return null;

      // Step 4: hand off to Gemini for parsing within each day.
      return await _aiPipeline.parseSchedulePerDay(perDayText);
    } finally {
      await recognizer.close();
    }
  }

  static String _normalize(String s) => s.toLowerCase().trim();
}