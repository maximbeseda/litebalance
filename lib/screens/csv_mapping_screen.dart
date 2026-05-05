import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';

import '../theme/app_colors_extension.dart';
import '../theme/category_defaults.dart';
import '../providers/all_providers.dart';
import '../services/storage_service.dart';
import '../utils/import_recognizer.dart';

class CsvMappingScreen extends ConsumerStatefulWidget {
  final List<List<dynamic>> rawRows;

  const CsvMappingScreen({super.key, required this.rawRows});

  @override
  ConsumerState<CsvMappingScreen> createState() => _CsvMappingScreenState();
}

class _CsvMappingScreenState extends ConsumerState<CsvMappingScreen> {
  int _currentStep = 0;

  int? _dateCol;
  int? _fromCol;
  int? _toCol;
  int? _amountFromCol;
  int? _currencyFromCol;
  int? _amountToCol;
  int? _currencyToCol;
  int? _noteCol;

  Map<String, CategoryType> _pendingCategories = {};
  Map<String, String> _pendingCurrencies = {};

  bool _isProcessing = false;
  double? _progress;
  String _loadingTitle = '';
  String _loadingSubtitle = '';

  List<String> _headers = [];
  List<List<dynamic>> _dataRows = [];

  @override
  void initState() {
    super.initState();
    _setupData();
    _autoGuessColumns();
  }

  void _setupData() {
    final headerRow = widget.rawRows.firstWhere(
      (row) => row.any(
        (cell) => ImportRecognizer.isDate(cell.toString().trim().toLowerCase()),
      ),
      orElse: () => widget.rawRows.first,
    );
    _headers = headerRow.map((e) => e.toString().trim()).toList();
    final int headerIdx = widget.rawRows.indexOf(headerRow);
    _dataRows = widget.rawRows.sublist(headerIdx + 1);
  }

  void _autoGuessColumns() {
    for (int i = 0; i < _headers.length; i++) {
      final h = _headers[i].toLowerCase();
      if (ImportRecognizer.isDate(h)) {
        _dateCol = i;
      } else if (ImportRecognizer.isFrom(h)) {
        _fromCol = i;
      } else if (ImportRecognizer.isTo(h)) {
        _toCol = i;
      } else if (ImportRecognizer.isAmountFrom(h)) {
        _amountFromCol ??= i;
      } else if (ImportRecognizer.isCurrencyFrom(h)) {
        _currencyFromCol ??= i;
      } else if (ImportRecognizer.isAmountTo(h)) {
        _amountToCol = i;
      } else if (ImportRecognizer.isCurrencyTo(h)) {
        _currencyToCol = i;
      } else if (ImportRecognizer.isNote(h)) {
        _noteCol = i;
      }
    }

    _amountToCol ??= _amountFromCol;
    _currencyToCol ??= _currencyFromCol;
  }

  Future<void> _analyzeCategories() async {
    if (_dateCol == null ||
        _fromCol == null ||
        _toCol == null ||
        _amountToCol == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('select_required_columns'.tr())));
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = null;
      _loadingTitle = 'analyzing_file'.tr();
      _loadingSubtitle = 'searching_categories'.tr();
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final allCats = ref.read(categoryProvider).allCategoriesList;
    final defaultCurrency = ref.read(settingsProvider).baseCurrency;

    final Map<String, CategoryType> foundTypes = {};
    final Map<String, String> foundCurrencies = {};

    final requiredIndices = [
      _dateCol,
      _fromCol,
      _toCol,
      _amountToCol,
    ].whereType<int>().toList();
    final maxIdx = requiredIndices.reduce((a, b) => a > b ? a : b);

    for (var row in _dataRows) {
      if (row.length <= maxIdx) {
        continue;
      }

      final fromName = row[_fromCol!].toString().trim();
      final toName = row[_toCol!].toString().trim();

      String currencyTo = defaultCurrency;
      if (_currencyToCol != null && row.length > _currencyToCol!) {
        currencyTo = row[_currencyToCol!].toString().trim();
        if (currencyTo.isEmpty) {
          currencyTo = defaultCurrency;
        }
      }

      String currencyFrom = currencyTo;
      if (_currencyFromCol != null && row.length > _currencyFromCol!) {
        currencyFrom = row[_currencyFromCol!].toString().trim();
        if (currencyFrom.isEmpty) {
          currencyFrom = defaultCurrency;
        }
      }

      if (fromName.isNotEmpty) {
        final bool existsActive = allCats.any(
          (c) =>
              c.name.toLowerCase() == fromName.toLowerCase() && !c.isArchived,
        );
        if (!existsActive && !foundTypes.containsKey(fromName)) {
          foundTypes[fromName] = ImportRecognizer.guessType(
            fromName,
            isFrom: true,
          );
          foundCurrencies[fromName] = currencyFrom;
        }
      }
      if (toName.isNotEmpty) {
        final bool existsActive = allCats.any(
          (c) => c.name.toLowerCase() == toName.toLowerCase() && !c.isArchived,
        );
        if (!existsActive && !foundTypes.containsKey(toName)) {
          foundTypes[toName] = ImportRecognizer.guessType(
            toName,
            isFrom: false,
          );
          foundCurrencies[toName] = currencyTo;
        }
      }
    }

    setState(() {
      _pendingCategories = foundTypes;
      _pendingCurrencies = foundCurrencies;
      _currentStep = 1;
      _isProcessing = false;
    });
  }

  Future<void> _executeImport() async {
    setState(() {
      _isProcessing = true;
      _progress = 0.1;
      _loadingTitle = 'step_1_3_categories'.tr();
      _loadingSubtitle = 'restoring_creating_categories'.tr();
    });

    final catNotifier = ref.read(categoryProvider.notifier);
    final db = ref.read(appDatabaseProvider);
    final currentBase = ref.read(settingsProvider).baseCurrency;

    final Map<String, Category> sessionCategories = {};

    final List<Category> workingCategories = List.from(
      ref.read(categoryProvider).allCategoriesList,
    );

    for (var cat in workingCategories) {
      final key = cat.name.toLowerCase();
      if (!sessionCategories.containsKey(key) ||
          sessionCategories[key]!.isArchived) {
        sessionCategories[key] = cat;
      }
    }

    for (var entry in _pendingCategories.entries) {
      final name = entry.key;
      final type = entry.value;
      final currency = _pendingCurrencies[name] ?? currentBase;

      final existingArchived = workingCategories
          .where(
            (c) =>
                c.name.toLowerCase() == name.toLowerCase() &&
                c.type == type &&
                c.isArchived,
          )
          .firstOrNull;

      if (existingArchived != null) {
        final unarchived = existingArchived.copyWith(isArchived: false);
        await catNotifier.addOrUpdateCategory(unarchived);

        final idx = workingCategories.indexWhere((c) => c.id == unarchived.id);
        if (idx != -1) {
          workingCategories[idx] = unarchived;
        }
        sessionCategories[name.toLowerCase()] = unarchived;
      } else {
        if (!sessionCategories.containsKey(name.toLowerCase())) {
          final newCat = Category(
            id: 'ck_${type.name}_${name.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecond}',
            name: name,
            type: type,
            icon: ImportRecognizer.getIconForName(name),
            bgColor: CategoryDefaults.getBgColor(type).toARGB32(),
            iconColor: CategoryDefaults.getIconColor(type).toARGB32(),
            amount: 0,
            isArchived: false,
            currency: currency,
            includeInTotal: true,
            sortOrder: 0,
          );
          await catNotifier.addOrUpdateCategory(newCat);
          workingCategories.add(newCat);
          sessionCategories[name.toLowerCase()] = newCat;
        }
      }
    }

    Category? resolveCategory(String name, bool isFrom) {
      final matches = workingCategories
          .where((c) => c.name.toLowerCase() == name.toLowerCase())
          .toList();
      if (matches.isEmpty) {
        return null;
      }

      final activeMatches = matches.where((c) => !c.isArchived).toList();
      final candidates = activeMatches.isNotEmpty ? activeMatches : matches;

      if (candidates.length == 1) {
        return candidates.first;
      }

      if (isFrom) {
        return candidates
                .where((c) => c.type == CategoryType.income)
                .firstOrNull ??
            candidates
                .where((c) => c.type == CategoryType.account)
                .firstOrNull ??
            candidates.first;
      } else {
        return candidates
                .where((c) => c.type == CategoryType.expense)
                .firstOrNull ??
            candidates
                .where((c) => c.type == CategoryType.account)
                .firstOrNull ??
            candidates.first;
      }
    }

    setState(() {
      _progress = 0.3;
      _loadingTitle = 'step_2_3_transactions'.tr();
      _loadingSubtitle = 'processing_rows'.tr();
    });

    final List<Transaction> txsToSave = [];
    final Map<String, int> accountDeltas = {};
    final int total = _dataRows.length;
    int skippedCount = 0;

    final requiredIndices = [
      _dateCol,
      _fromCol,
      _toCol,
      _amountToCol,
    ].whereType<int>().toList();
    final maxIdx = requiredIndices.reduce((a, b) => a > b ? a : b);

    for (int i = 0; i < total; i++) {
      if (!mounted) {
        return;
      }

      final row = _dataRows[i];
      if (row.length <= maxIdx) {
        continue;
      }

      final dateStr = row[_dateCol!].toString();
      final date = _parseDate(dateStr);
      if (date == null) {
        skippedCount++;
        continue;
      }

      final fromName = row[_fromCol!].toString().trim();
      final toName = row[_toCol!].toString().trim();

      if (fromName.isEmpty || toName.isEmpty) {
        continue;
      }

      final amountTo = _parseAmount(row[_amountToCol!].toString());
      if (amountTo == 0) {
        continue;
      }

      String currencyTo = currentBase;
      if (_currencyToCol != null) {
        final parsedCur = row[_currencyToCol!].toString().trim();
        if (parsedCur.isNotEmpty) currencyTo = parsedCur;
      }

      int amountFrom = amountTo;
      if (_amountFromCol != null) {
        amountFrom = _parseAmount(row[_amountFromCol!].toString());
      }

      String currencyFrom = currencyTo;
      if (_currencyFromCol != null) {
        final parsedCurFrom = row[_currencyFromCol!].toString().trim();
        if (parsedCurFrom.isNotEmpty) currencyFrom = parsedCurFrom;
      }

      Category? fromCat = resolveCategory(fromName, true);
      Category? toCat = resolveCategory(toName, false);

      if (fromCat == null || toCat == null) {
        skippedCount++;
        continue;
      }

      if (fromCat.isArchived) {
        fromCat = fromCat.copyWith(isArchived: false);
        await catNotifier.addOrUpdateCategory(fromCat);
        final idx = workingCategories.indexWhere((c) => c.id == fromCat!.id);
        if (idx != -1) workingCategories[idx] = fromCat;
      }
      if (toCat.isArchived) {
        toCat = toCat.copyWith(isArchived: false);
        await catNotifier.addOrUpdateCategory(toCat);
        final idx = workingCategories.indexWhere((c) => c.id == toCat!.id);
        if (idx != -1) workingCategories[idx] = toCat;
      }

      int baseAmt = amountTo;
      if (currencyTo == currentBase) {
        baseAmt = amountTo;
      } else if (currencyFrom == currentBase) {
        baseAmt = amountFrom;
      }

      final tx = Transaction(
        id: 'ck_import_${date.millisecondsSinceEpoch}_$i',
        fromId: fromCat.id,
        toId: toCat.id,
        title: _noteCol != null && row.length > _noteCol!
            ? row[_noteCol!].toString().trim()
            : toName,
        amount: amountFrom,
        date: date,
        currency: currencyFrom,
        targetAmount: (amountFrom != amountTo || currencyFrom != currencyTo)
            ? amountTo
            : null,
        targetCurrency: (amountFrom != amountTo || currencyFrom != currencyTo)
            ? currencyTo
            : null,
        baseAmount: baseAmt,
        baseCurrency: currentBase,
      );

      txsToSave.add(tx);

      if (fromCat.type == CategoryType.account) {
        accountDeltas[fromCat.id] =
            (accountDeltas[fromCat.id] ?? 0) - amountFrom;
      }
      if (toCat.type == CategoryType.account) {
        accountDeltas[toCat.id] = (accountDeltas[toCat.id] ?? 0) + amountTo;
      }

      if (i % 100 == 0 && mounted) {
        setState(() {
          _progress = 0.3 + (0.5 * (i / total));
        });
      }
    }

    setState(() {
      _progress = 0.9;
      _loadingTitle = 'step_3_3_saving'.tr();
      _loadingSubtitle = 'mass_saving'.tr();
    });

    if (txsToSave.isNotEmpty) {
      await StorageService.saveHistory(db, txsToSave);
    }

    for (var entry in accountDeltas.entries) {
      catNotifier.updateCategoryAmount(entry.key, entry.value);
    }

    ref.invalidate(transactionProvider);
    ref.invalidate(categoryProvider);
    ref.invalidate(statsProvider);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'import_completed'.tr(
              args: [txsToSave.length.toString(), skippedCount.toString()],
            ),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.pop(context);
    }
  }

  DateTime? _parseDate(String v) {
    try {
      final clean = v.replaceAll('"', '').trim();
      final datePart = clean.split(' ')[0];
      final p = datePart.split('.');
      if (p.length == 3) {
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      final p2 = datePart.split('/');
      if (p2.length == 3) {
        return DateTime(int.parse(p2[2]), int.parse(p2[1]), int.parse(p2[0]));
      }
      return DateTime.tryParse(clean);
    } catch (_) {
      return null;
    }
  }

  int _parseAmount(String v) {
    try {
      final clean = v
          .replaceAll('"', '')
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(',', '.');
      return (double.parse(clean).abs() * 100).round();
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return PopScope(
      canPop: !_isProcessing && _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep == 1 && !_isProcessing) {
          setState(() {
            _currentStep = 0;
          });
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: Text(
                _currentStep == 0
                    ? 'step_1_columns'.tr()
                    : 'step_2_categories'.tr(),
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
            ),
            body: _currentStep == 0
                ? _buildStep0Columns(colors)
                : _buildStep1Categories(colors),
          ),

          if (_isProcessing)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Material(
                      type: MaterialType.transparency,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      value: _progress,
                                      strokeWidth: 6,
                                      color: colors.accent,
                                      backgroundColor: colors.accent.withValues(
                                        alpha: 0.1,
                                      ),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  if (_progress != null)
                                    Text(
                                      '${(_progress! * 100).toInt()}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colors.textMain,
                                        fontSize: 18,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _loadingTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textMain,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _loadingSubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep0Columns(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildPicker(
                  colors,
                  'transaction_date'.tr(),
                  _dateCol,
                  (v) => setState(() => _dateCol = v),
                ),
                const Divider(height: 32),
                _buildPicker(
                  colors,
                  'source_from'.tr(),
                  _fromCol,
                  (v) => setState(() => _fromCol = v),
                ),
                _buildPicker(
                  colors,
                  'target_to'.tr(),
                  _toCol,
                  (v) => setState(() => _toCol = v),
                ),
                const Divider(height: 32),
                _buildPicker(
                  colors,
                  'amount_from'.tr(),
                  _amountFromCol,
                  (v) => setState(() => _amountFromCol = v),
                ),
                _buildPicker(
                  colors,
                  'currency_from'.tr(),
                  _currencyFromCol,
                  (v) => setState(() => _currencyFromCol = v),
                ),
                const SizedBox(height: 8),
                _buildPicker(
                  colors,
                  'amount_to'.tr(),
                  _amountToCol,
                  (v) => setState(() => _amountToCol = v),
                ),
                _buildPicker(
                  colors,
                  'currency_to'.tr(),
                  _currencyToCol,
                  (v) => setState(() => _currencyToCol = v),
                ),
                const Divider(height: 32),
                _buildPicker(
                  colors,
                  'column_comment'.tr(),
                  _noteCol,
                  (v) => setState(() => _noteCol = v),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _analyzeCategories,
              child: Text(
                'next'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Categories(AppColorsExtension colors) {
    if (_pendingCategories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'all_categories_found'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'no_new_categories_needed'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _executeImport,
                child: Text(
                  'import_data_btn'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'found_new_categories'.tr(),
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _pendingCategories.length,
              itemBuilder: (context, index) {
                final String catName = _pendingCategories.keys.elementAt(index);
                final CategoryType currentType = _pendingCategories[catName]!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.textMain,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeButton(
                              colors,
                              CategoryType.income,
                              currentType,
                              'type_income'.tr(),
                              Colors.green,
                              (newType) => setState(
                                () => _pendingCategories[catName] = newType,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTypeButton(
                              colors,
                              CategoryType.account,
                              currentType,
                              'type_account'.tr(),
                              Colors.blue,
                              (newType) => setState(
                                () => _pendingCategories[catName] = newType,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTypeButton(
                              colors,
                              CategoryType.expense,
                              currentType,
                              'type_expense'.tr(),
                              Colors.red,
                              (newType) => setState(
                                () => _pendingCategories[catName] = newType,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _executeImport,
              child: Text(
                'import_data_btn'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(
    AppColorsExtension colors,
    CategoryType type,
    CategoryType selectedType,
    String label,
    Color activeColor,
    Function(CategoryType) onTap,
  ) {
    final isSelected = type == selectedType;
    return GestureDetector(
      onTap: () => onTap(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? activeColor
                : colors.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : colors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPicker(
    AppColorsExtension colors,
    String title,
    int? value,
    Function(int?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: colors.textMain, fontSize: 13),
            ),
          ),
          DropdownButton<int>(
            value: value,
            underline: const SizedBox(),
            dropdownColor: colors.cardBg,
            items: List.generate(_headers.length, (i) {
              return DropdownMenuItem(
                value: i,
                child: Text(
                  _headers[i],
                  style: TextStyle(fontSize: 12, color: colors.textMain),
                ),
              );
            }),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
