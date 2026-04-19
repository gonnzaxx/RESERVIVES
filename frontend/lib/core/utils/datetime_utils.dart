import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reservives/l10n/app_localizations.dart';

/// Returns the next valid weekday date (Mon-Fri).
DateTime nextWeekdayDate(DateTime date) {
  if (date.weekday == DateTime.saturday) {
    return date.add(const Duration(days: 2));
  }
  if (date.weekday == DateTime.sunday) {
    return date.add(const Duration(days: 1));
  }
  return date;
}

String formatRelativeDate(DateTime date, BuildContext context) {
  final diff = DateTime.now().difference(date);

  if (diff.inMinutes < 1) {
    return context.tr('time.justNow');
  }

  if (diff.inMinutes < 60) {
    return context.tr('time.minutesAgo').replaceAll('{n}', '${diff.inMinutes}');
  }

  if (diff.inHours < 24) {
    return context.tr('time.hoursAgo').replaceAll('{n}', '${diff.inHours}');
  }

  if (diff.inDays == 1) {
    return context.tr('time.yesterday');
  }

  if (diff.inDays < 7) {
    return context.tr('time.daysAgo').replaceAll('{n}', '${diff.inDays}');
  }

  final localeCode = Localizations.localeOf(context).languageCode;
  return DateFormat('dd MMM yyyy', localeCode).format(date);
}
