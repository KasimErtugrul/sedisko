String formatDate(DateTime? date) {
  if (date == null) return '-';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}
