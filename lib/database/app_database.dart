import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

enum CategoryType { income, account, expense }

// ==========================================
// ТАБЛИЦІ
// ==========================================

class Categories extends Table {
  TextColumn get id => text()();
  IntColumn get type => intEnum<CategoryType>()();
  TextColumn get name => text()();
  IntColumn get icon => integer()();
  IntColumn get bgColor => integer()();
  IntColumn get iconColor => integer()();
  IntColumn get amount => integer().withDefault(const Constant(0))();
  IntColumn get budget => integer().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get currency => text().withDefault(const Constant('UAH'))();
  BoolColumn get includeInTotal =>
      boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get fromId => text()();
  TextColumn get toId => text()();
  TextColumn get title => text()();
  TextColumn get titleLower =>
      text().nullable()(); // Додано для швидкого пошуку
  DateTimeColumn get date => dateTime()();

  IntColumn get amount => integer()();
  TextColumn get currency => text()();

  IntColumn get targetAmount => integer().nullable()();
  TextColumn get targetCurrency => text().nullable()();

  IntColumn get baseAmount => integer().withDefault(const Constant(0))();
  TextColumn get baseCurrency => text()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Subscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get amount => integer()();
  TextColumn get categoryId => text()();
  TextColumn get accountId => text()();
  DateTimeColumn get nextPaymentDate => dateTime()();
  TextColumn get periodicity => text().withDefault(const Constant('monthly'))();
  IntColumn get customIconCodePoint => integer().nullable()();
  BoolColumn get isAutoPay => boolean().withDefault(const Constant(false))();
  TextColumn get currency => text().withDefault(const Constant('UAH'))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ==========================================
// БАЗА ДАНИХ ТА ЗАПИТИ
// ==========================================

@DriftDatabase(tables: [Categories, Transactions, Subscriptions])
class AppDatabase extends _$AppDatabase {
  // Приватний конструктор (позиційний аргумент)
  AppDatabase._internal([QueryExecutor? e]) : super(e ?? _openConnection());

  static AppDatabase? _instance;

  factory AppDatabase([QueryExecutor? executor]) {
    if (executor != null) {
      return AppDatabase._internal(executor);
    }
    _instance ??= AppDatabase._internal();
    return _instance!;
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(categories, categories.deletedAt);
          await m.addColumn(transactions, transactions.deletedAt);
          await m.addColumn(subscriptions, subscriptions.deletedAt);
        }
        if (from < 3) {
          await m.addColumn(transactions, transactions.titleLower);
          await customStatement(
            'UPDATE transactions SET title_lower = dart_lower(title);',
          );
        }
      },
    );
  }

  Future<List<Transaction>> getFilteredTransactions({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? filterCategoryIds,
    String? currency,
    int? limit,
    int? offset,
    String? searchQuery,
    bool includeDeleted = false,
  }) {
    final query = select(transactions);

    query.where((t) {
      Expression<bool> predicate = const Constant(true);

      if (!includeDeleted) {
        predicate = predicate & t.deletedAt.isNull();
      }

      if (startDate != null && endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        predicate = predicate & t.date.isBetweenValues(startDate, endOfDay);
      } else if (startDate != null) {
        predicate = predicate & t.date.isBiggerOrEqualValue(startDate);
      } else if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        predicate = predicate & t.date.isSmallerOrEqualValue(endOfDay);
      }

      if (filterCategoryIds != null && filterCategoryIds.isNotEmpty) {
        predicate =
            predicate &
            (t.fromId.isIn(filterCategoryIds) | t.toId.isIn(filterCategoryIds));
      }

      if (currency != null && currency.isNotEmpty) {
        predicate =
            predicate &
            (t.currency.equals(currency) | t.targetCurrency.equals(currency));
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final cleanSearch = searchQuery.trim().replaceAll(',', '.');
        final queryLower = cleanSearch.toLowerCase();

        // 1. Пошук по назві
        final titleFallback = FunctionCallExpression<String>('dart_lower', [
          t.title,
        ]);
        final titleField = coalesce<String>([t.titleLower, titleFallback]);

        Expression<bool> searchPredicate = titleField.like('%$queryLower%');

        // 2. Пошук по сумі
        final amountFormatted = FunctionCallExpression<String>('printf', [
          const Constant('%.2f'),
          t.amount.cast<double>() / const Constant(100.0),
        ]);
        searchPredicate =
            searchPredicate | amountFormatted.like('%$cleanSearch%');

        // 3. Пошук по назві категорії
        final categoryExists = existsQuery(
          select(categories)..where(
            (c) =>
                FunctionCallExpression<String>('dart_lower', [
                  c.name,
                ]).like('%$queryLower%') &
                (c.id.equalsExp(t.fromId) | c.id.equalsExp(t.toId)),
          ),
        );
        searchPredicate = searchPredicate | categoryExists;

        // ==============================================================
        // 4. Пошук по даті (Комбінований підхід: Dart Regex + SQLite)
        // ==============================================================
        DateTime? parsedStart;
        DateTime? parsedEnd;

        // Патерни для розпізнавання дат у тексті:
        final dateEu = RegExp(
          r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
        ).firstMatch(cleanSearch); // DD.MM.YYYY
        final dateIso = RegExp(
          r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
        ).firstMatch(cleanSearch); // YYYY-MM-DD
        // ВИПРАВЛЕНО: Рік має бути строго 4 цифри, щоб 12.10 не сприймалося як MM.YYYY
        final monthYearEu = RegExp(
          r'^(\d{1,2})\.(\d{4})$',
        ).firstMatch(cleanSearch); // MM.YYYY
        final monthIso = RegExp(
          r'^(\d{4})-(\d{1,2})$',
        ).firstMatch(cleanSearch); // YYYY-MM
        // ДОДАНО: Розпізнавання лише дня і місяця (наприклад 12.10)
        final dayMonthEu = RegExp(
          r'^(\d{1,2})\.(\d{1,2})$',
        ).firstMatch(cleanSearch); // DD.MM
        final yearOnly = RegExp(r'^(\d{4})$').firstMatch(cleanSearch); // YYYY

        try {
          if (dateEu != null) {
            final day = int.parse(dateEu.group(1)!);
            final month = int.parse(dateEu.group(2)!);
            final year = int.parse(dateEu.group(3)!);
            parsedStart = DateTime(year, month, day);
            parsedEnd = DateTime(year, month, day, 23, 59, 59);
          } else if (dateIso != null) {
            final year = int.parse(dateIso.group(1)!);
            final month = int.parse(dateIso.group(2)!);
            final day = int.parse(dateIso.group(3)!);
            parsedStart = DateTime(year, month, day);
            parsedEnd = DateTime(year, month, day, 23, 59, 59);
          } else if (monthYearEu != null) {
            final month = int.parse(monthYearEu.group(1)!);
            final year = int.parse(monthYearEu.group(2)!);
            parsedStart = DateTime(year, month, 1);
            parsedEnd = DateTime(
              year,
              month + 1,
              1,
            ).subtract(const Duration(seconds: 1));
          } else if (monthIso != null) {
            final year = int.parse(monthIso.group(1)!);
            final month = int.parse(monthIso.group(2)!);
            parsedStart = DateTime(year, month, 1);
            parsedEnd = DateTime(
              year,
              month + 1,
              1,
            ).subtract(const Duration(seconds: 1));
          } else if (dayMonthEu != null) {
            final day = int.parse(dayMonthEu.group(1)!);
            final month = int.parse(dayMonthEu.group(2)!);
            final year = DateTime.now().year; // Прив'язуємо до поточного року
            parsedStart = DateTime(year, month, day);
            parsedEnd = DateTime(year, month, day, 23, 59, 59);
          } else if (yearOnly != null) {
            final year = int.parse(yearOnly.group(1)!);
            parsedStart = DateTime(year, 1, 1);
            parsedEnd = DateTime(year, 12, 31, 23, 59, 59);
          }
        } catch (_) {
          // Ігноруємо помилки (наприклад якщо введено 99.99)
        }

        // Якщо Dart зрозумів дату, додаємо строгий та швидкий фільтр
        if (parsedStart != null && parsedEnd != null) {
          searchPredicate =
              searchPredicate | t.date.isBetweenValues(parsedStart, parsedEnd);
        }

        // РЕЗЕРВНИЙ ВАРІАНТ (Fallback SQLite):
        // Працює, коли ти вводиш дату посимвольно ("1", "12.", "12.1"),
        // а також дозволяє знайти "12.10" за всі минулі роки!
        final sqlDateEu = FunctionCallExpression<String>('strftime', [
          const Constant('%d.%m.%Y'),
          t.date,
          const Constant('unixepoch'),
          const Constant('localtime'),
        ]);
        final sqlDateIso = FunctionCallExpression<String>('strftime', [
          const Constant('%Y-%m-%d'),
          t.date,
          const Constant('unixepoch'),
          const Constant('localtime'),
        ]);

        searchPredicate =
            searchPredicate |
            sqlDateEu.like('%$cleanSearch%') |
            sqlDateIso.like('%$cleanSearch%');

        predicate = predicate & searchPredicate;
      }

      return predicate;
    });

    query.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
    ]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }
}

// --- ПОКРАЩЕНЕ ПІДКЛЮЧЕННЯ (WAL + SETUP) ---

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'coinflow_db.sqlite'));

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode = WAL;');
        db.execute('PRAGMA synchronous = NORMAL;');

        db.createFunction(
          functionName: 'dart_lower',
          function: (args) {
            if (args.isNotEmpty && args[0] is String) {
              return (args[0] as String).toLowerCase();
            }
            return args.isEmpty ? null : args[0];
          },
        );
      },
    );
  });
}

// --- RIVERPOD ПРОВАЙДЕР ---

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(() {});
  return db;
}
