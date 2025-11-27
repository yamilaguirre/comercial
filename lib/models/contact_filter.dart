enum ContactFilter { all, contacted, notContacted }

extension ContactFilterExtension on ContactFilter {
  String get label {
    switch (this) {
      case ContactFilter.all:
        return 'Todos';
      case ContactFilter.contacted:
        return 'Contactados';
      case ContactFilter.notContacted:
        return 'No contactados';
    }
  }
}
