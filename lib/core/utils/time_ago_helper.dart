class TimeAgoHelper {
  static String format(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Hace ${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 30) {
      return 'Hace ${difference.inDays}d';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Hace ${months}mes';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Hace ${years}a';
    }
  }
}
