part of '../main.dart';

class AppSettingsScope extends InheritedNotifier<PreferencesController> {
  const AppSettingsScope({
    required PreferencesController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static PreferencesController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()!.notifier!;
}

Locale? selectedLocale(AppLanguage language) => switch (language) {
  AppLanguage.system => null,
  AppLanguage.zhHans => const Locale('zh'),
  AppLanguage.zhHant => const Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
  ),
  AppLanguage.en => const Locale('en'),
};

Locale resolveWalletLocale(List<Locale>? locales, Iterable<Locale> supported) {
  for (final locale in locales ?? const <Locale>[]) {
    if (locale.languageCode == 'zh') {
      return locale.scriptCode == 'Hant' ||
              ['TW', 'HK', 'MO'].contains(locale.countryCode)
          ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
          : const Locale('zh');
    }
    if (locale.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

String languageLabel(BuildContext context, AppLanguage language) =>
    switch (language) {
      AppLanguage.system => tr(context, MessageCode.msgSystemDefault),
      AppLanguage.zhHans => tr(context, MessageCode.languageSimplifiedChinese),
      AppLanguage.zhHant => tr(context, MessageCode.languageTraditionalChinese),
      AppLanguage.en => 'English',
    };

class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppSettingsScope.of(context);
    return PopupMenuButton<AppLanguage>(
      key: const ValueKey('language-menu'),
      tooltip: tr(context, MessageCode.msgLanguage),
      initialValue: controller.value.language,
      icon: const Icon(Icons.language),
      onSelected: (language) => controller.update(language: language),
      itemBuilder: (_) => [
        for (final language in AppLanguage.values)
          CheckedPopupMenuItem(
            value: language,
            checked: language == controller.value.language,
            child: Text(
              localized(
                context,
                language == AppLanguage.system
                    ? tr(context, MessageCode.msgSystemDefault)
                    : languageLabel(context, language),
              ),
            ),
          ),
      ],
    );
  }
}

class AppPreferenceControls extends StatelessWidget {
  const AppPreferenceControls({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppSettingsScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr(context, MessageCode.msgLanguage),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              localized(
                context,
                controller.value.language == AppLanguage.system
                    ? tr(context, MessageCode.msgSystemDefault)
                    : languageLabel(context, controller.value.language),
              ),
            ),
            const LanguageMenuButton(),
          ],
        ),
        if (controller.saveFailed)
          Text(
            tr(
              context,
              MessageCode.msgPreferencesCouldNotBeSavedPreviousSettingsMay,
            ),
          ),
      ],
    );
  }
}
