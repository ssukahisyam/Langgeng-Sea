import 'package:intl/intl.dart';

/// Returns the label to show for a Track in popups and tooltips.
///
/// If [storedName] is non-null and non-empty after trimming, it is
/// returned as-is (the user-assigned Trip/Haul name). Otherwise, a
/// default label is synthesised from [startedAt] using the
/// `yyyy-MM-dd HH:mm` format.
///
/// This is a pure function to keep rendering logic easily testable
/// against Requirements 3.3, 3.3a, and 3.7.
String trackDisplayLabel({
  String? storedName,
  required DateTime startedAt,
}) {
  if (storedName != null && storedName.trim().isNotEmpty) {
    return storedName;
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(startedAt);
}
