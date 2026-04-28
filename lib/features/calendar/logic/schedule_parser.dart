import '../domain/entities/calendar_event_entity.dart';
import 'package:uuid/uuid.dart';

class ScheduleParser {
  static const Map<String, List<String>> weekdayAliases = {
    'monday': ['pazartesi', 'pzt', 'monday', 'mon'],
    'tuesday': ['salı', 'sali', 'tuesday', 'tue'],
    'wednesday': ['çarşamba', 'carsamba', 'wednesday', 'wed'],
    'thursday': ['perşembe', 'persembe', 'thursday', 'thu'],
    'friday': ['cuma', 'friday', 'fri'],
    'saturday': ['cumartesi', 'saturday', 'sat'],
    'sunday': ['pazar', 'sunday', 'sun'],
  };

  static List<CalendarEventEntity> parseRawText(String rawText, String userId) {
    final List<CalendarEventEntity> events = [];
    final lines = rawText.split('\n');
    
    String? currentDay;
    String? lastTime;

    for (var line in lines) {
      final cleanLine = line.trim().toLowerCase();
      if (cleanLine.isEmpty) continue;

      // 1. GÜN TESPİTİ (Alias kullanarak daha esnek arama)
      String? foundDayKey;
      weekdayAliases.forEach((key, aliases) {
        for (var alias in aliases) {
          if (cleanLine.contains(alias)) {
            foundDayKey = key;
            break;
          }
        }
      });

      if (foundDayKey != null) {
        currentDay = foundDayKey;
      }

      // 2. SAAT TESPİTİ (09:00, 10.30, 14 00 gibi esnek formatlar)
      final timeRegex = RegExp(r'(\d{1,2})[:.\s](\d{2})');
      final timeMatch = timeRegex.firstMatch(cleanLine);
      if (timeMatch != null) {
        lastTime = '${timeMatch.group(1)}:${timeMatch.group(2)}';
      }

      // 3. DERS ADI TESPİTİ
      // Eğer satırda gün veya saat bilgisi dışında bir metin varsa ders adıdır.
      String titleCandidate = line;
      // Gün ve saat ifadelerini temizle
      weekdayAliases.values.forEach((aliases) {
        for (var alias in aliases) {
          titleCandidate = titleCandidate.replaceAll(RegExp(alias, caseSensitive: false), '');
        }
      });
      titleCandidate = titleCandidate.replaceAll(timeRegex, '').replaceAll(RegExp(r'[-:.]'), '').trim();

      // Ders adı en az 3 karakter olmalı ve "pazartesi" gibi bir gün ismi olmamalı
      if (titleCandidate.length >= 3 && currentDay != null && lastTime != null) {
        final now = DateTime.now();
        final eventDate = _getNearestDayOfWeek(now, currentDay);

        final timeParts = lastTime.split(':');
        final startAt = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        // Aynı dersi mükerrer eklememek için kontrol
        bool exists = events.any((e) => e.title == titleCandidate && e.startAt == startAt);
        
        if (!exists) {
          events.add(CalendarEventEntity(
            id: const Uuid().v4(),
            userId: userId,
            title: titleCandidate,
            startAt: startAt,
            endAt: startAt.add(const Duration(hours: 1)),
            eventType: CalendarEventType.classSchedule,
          ));
        }
      }
    }

    // Eğer hiçbir ders bulunamadıysa (Tablo formatı olabilir), 
    // tüm metin içinden blok arama yapacak ikinci bir mantık eklenebilir.
    return events;
  }

  static DateTime _getNearestDayOfWeek(DateTime relativeTo, String dayKey) {
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    int targetDay = dayKeys.indexOf(dayKey.toLowerCase());
    
    int currentDay = relativeTo.weekday - 1; // 0-6
    int difference = targetDay - currentDay;
    
    return relativeTo.add(Duration(days: difference));
  }
}
