// utils/date_utils.dart
import 'package:shamsi_date/shamsi_date.dart';

String formatToJalali(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return 'نامشخص';

  try {
    final gregorian = DateTime.parse(isoDate);
    final jalali = gregorian.toJalali();
    return '${jalali.day}/${jalali.month}/${jalali.year}';
  } catch (e) {
    return isoDate; // اگر تبدیل ممکن نبود، همان تاریخ میلادی را نمایش بده
  }
}
