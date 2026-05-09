import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
export '../database/app_database.dart';

// 👇 ПРОКАЧАНИЙ клас-нотіфаєр для прапорця бекапів (Безсмертний)
class DbDirtyNotifier extends Notifier<bool> {
  static const _key = 'is_db_dirty_persistent';

  @override
  bool build() {
    // При старті додатку читаємо збережений стан з пам'яті телефону
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  // Метод для зміни прапорця
  void setDirty(bool isDirty) {
    state = isDirty;
    // Одразу фізично зберігаємо в пам'ять телефону!
    ref.read(sharedPreferencesProvider).setBool(_key, isDirty);
  }
}

// Провайдер, який ми використовуємо всюди
final dbDirtyProvider = NotifierProvider<DbDirtyNotifier, bool>(
  DbDirtyNotifier.new,
);

// Провайдер для SharedPreferences (буде перевизначений у main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main.dart',
  );
});

// Провайдер для інформації про додаток
final packageInfoProvider = Provider<PackageInfo>((ref) {
  throw UnimplementedError(
    'packageInfoProvider must be overridden in main.dart',
  );
});
