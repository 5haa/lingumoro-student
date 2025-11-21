import 'package:flutter/material.dart';
import 'package:student/services/locale_service.dart';

class LocaleProvider extends InheritedWidget {
  final LocaleService localeService;

  const LocaleProvider({
    Key? key,
    required this.localeService,
    required Widget child,
  }) : super(key: key, child: child);

  static LocaleService of(BuildContext context) {
    final LocaleProvider? provider =
        context.dependOnInheritedWidgetOfExactType<LocaleProvider>();
    assert(provider != null, 'No LocaleProvider found in context');
    return provider!.localeService;
  }

  @override
  bool updateShouldNotify(LocaleProvider oldWidget) {
    return localeService != oldWidget.localeService;
  }
}

