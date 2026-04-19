import 'package:url_launcher/url_launcher.dart';

class CalendarUtils {
  static Future<void> addToCalendar({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    String? details,
  }) async {
    final startStr = startTime.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first + 'Z';
    final endStr = endTime.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first + 'Z';

    final url = Uri.parse(
        'https://www.google.com/calendar/render?'
            'action=TEMPLATE&'
            'text=${Uri.encodeComponent(title)}&'
            'dates=$startStr/$endStr&'
            'details=${Uri.encodeComponent(details ?? '')}&'
            'location=${Uri.encodeComponent(location ?? '')}'
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
