import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'strings.dart';

export 'strings.dart';

const supportedLocales = [Locale('zh'), Locale('en')];

/// The app's strings plus Flutter's own (text selection menus, tooltips).
const localizationsDelegates = <LocalizationsDelegate<Object?>>[
  _StringsDelegate(),
  ...GlobalMaterialLocalizations.delegates,
];

extension StringsOf on BuildContext {
  Strings get strings => Localizations.of<Strings>(this, Strings)!;
}

class _StringsDelegate extends LocalizationsDelegate<Strings> {
  const _StringsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<Strings> load(Locale locale) =>
      SynchronousFuture(Strings.forLanguage(locale.languageCode));

  @override
  bool shouldReload(_StringsDelegate old) => false;
}
