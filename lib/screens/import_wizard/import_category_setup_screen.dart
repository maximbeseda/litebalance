import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/all_providers.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors_extension.dart';
import '../../theme/category_defaults.dart';
import '../../utils/import_recognizer.dart';

class ImportCategorySetupScreen extends ConsumerStatefulWidget {
  final List<List<dynamic>> rawRows;
  final int headerRowIndex;
  final int? dateCol;
  final int? fromCol;
  final int? toCol;
  final int? amountFromCol;
  final int? currencyFromCol;
  final int? amountToCol;
  final int? currencyToCol;
  final int? noteCol;
  final List<String> foundCategories;

  const ImportCategorySetupScreen({
    super.key,
    required this.rawRows,
    required this.headerRowIndex,
    this.dateCol,
    this.fromCol,
    this.toCol,
    this.amountFromCol,
    this.currencyFromCol,
    this.amountToCol,
    this.currencyToCol,
    this.noteCol,
    required this.foundCategories,
  });

  @override
  ConsumerState<ImportCategorySetupScreen> createState() =>
      _ImportCategorySetupScreenState();
}

class _ImportCategorySetupScreenState
    extends ConsumerState<ImportCategorySetupScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  double? _progress;
  String _loadingSubtitle = '';

  final Map<String, CategoryType> _pendingTypes = {};
  final Map<String, bool> _pendingArchive = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeCategories();
    });
  }

  void _analyzeCategories() {
    final allCats = ref.read(categoryProvider).allCategoriesList;

    for (final name in widget.foundCategories) {
      final exists = allCats.any(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );

      if (!exists) {
        _pendingTypes[name] = ImportRecognizer.guessType(name, isFrom: false);
        _pendingArchive[name] = false;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  DateTime? _parseDate(String v) {
    try {
      final clean = v.replaceAll('"', '').trim();
      final datePart = clean.split('T')[0].split(' ')[0];
      final parsedIso = DateTime.tryParse(clean);
      if (parsedIso != null) return parsedIso;

      final parts = datePart.split(RegExp(r'[\./-]'));
      if (parts.length == 3) {
        final p0 = int.parse(parts[0]);
        final p1 = int.parse(parts[1]);
        final p2 = int.parse(parts[2]);

        final int year;
        final int month;
        final int day;

        if (p0 > 1000) {
          year = p0;
          month = p1;
          day = p2;
        } else {
          year = p2 < 100 ? (p2 > 50 ? 1900 + p2 : 2000 + p2) : p2;
          if (p0 > 12) {
            day = p0;
            month = p1;
          } else if (p1 > 12) {
            month = p0;
            day = p1;
          } else {
            if (datePart.contains('/')) {
              month = p0;
              day = p1;
            } else {
              day = p0;
              month = p1;
            }
          }
        }

        if (month > 0 && month <= 12 && day > 0 && day <= 31) {
          return DateTime(year, month, day);
        }
      }
      return DateTime.tryParse(datePart);
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

  Future<void> _executeImport() async {
    setState(() {
      _isProcessing = true;
      _progress = 0.1;
      // ВИПРАВЛЕНО: Локалізація
      _loadingSubtitle = 'import_creating_categories'.tr();
    });

    final catNotifier = ref.read(categoryProvider.notifier);
    final db = ref.read(appDatabaseProvider);
    final currentBase = ref.read(settingsProvider).baseCurrency;

    final List<Category> workingCategories = List.from(
      ref.read(categoryProvider).allCategoriesList,
    );

    for (final entry in _pendingTypes.entries) {
      final name = entry.key;
      final type = entry.value;
      final isArchived = _pendingArchive[name] ?? false;

      final newCat = Category(
        id: 'ck_imp_${type.name}_${name.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecond}',
        name: name,
        type: type,
        icon: ImportRecognizer.getIconForName(name),
        bgColor: CategoryDefaults.getBgColor(type).toARGB32(),
        iconColor: CategoryDefaults.getIconColor(type).toARGB32(),
        amount: 0,
        isArchived: isArchived,
        currency: currentBase,
        includeInTotal: true,
        sortOrder: 0,
      );

      await catNotifier.addOrUpdateCategory(newCat);
      workingCategories.add(newCat);
    }

    Category? resolveCategory(String name, bool isFrom) {
      if (name.isEmpty) return null;
      final matches = workingCategories
          .where((c) => c.name.toLowerCase() == name.toLowerCase())
          .toList();
      if (matches.isEmpty) return null;

      final activeMatches = matches.where((c) => !c.isArchived).toList();
      final candidates = activeMatches.isNotEmpty ? activeMatches : matches;

      if (candidates.length == 1) return candidates.first;

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
      _progress = 0.4;
      // ВИПРАВЛЕНО: Локалізація
      _loadingSubtitle = 'import_processing_transactions'.tr();
    });

    final List<Transaction> txsToSave = [];
    final Map<String, int> accountDeltas = {};
    int skippedCount = 0;
    int invalidConsecutiveRows = 0;

    final totalRows = widget.rawRows.length;
    final startIndex = widget.headerRowIndex + 1;

    for (int i = startIndex; i < totalRows; i++) {
      if (!mounted) return;

      final row = widget.rawRows[i];
      if (row.isEmpty) {
        invalidConsecutiveRows++;
        if (invalidConsecutiveRows >= 3) break;
        continue;
      }

      if (widget.dateCol! >= row.length) {
        invalidConsecutiveRows++;
        if (invalidConsecutiveRows >= 3) break;
        continue;
      }

      final dateStr = row[widget.dateCol!].toString();
      final date = _parseDate(dateStr);
      if (date == null) {
        invalidConsecutiveRows++;
        if (invalidConsecutiveRows >= 3) break;
        continue;
      }

      invalidConsecutiveRows = 0;

      final fromName = widget.fromCol != null && widget.fromCol! < row.length
          ? row[widget.fromCol!].toString().trim()
          : '';
      final toName = widget.toCol != null && widget.toCol! < row.length
          ? row[widget.toCol!].toString().trim()
          : '';

      if (fromName.isEmpty && toName.isEmpty) {
        skippedCount++;
        continue;
      }

      final int amountTo =
          (widget.amountToCol != null && widget.amountToCol! < row.length)
          ? _parseAmount(row[widget.amountToCol!].toString())
          : 0;

      if (amountTo == 0) {
        skippedCount++;
        continue;
      }

      final String currencyTo;
      if (widget.currencyToCol != null && widget.currencyToCol! < row.length) {
        final parsedCur = row[widget.currencyToCol!].toString().trim();
        currencyTo = parsedCur.isNotEmpty ? parsedCur : currentBase;
      } else {
        currencyTo = currentBase;
      }

      final int amountFrom =
          (widget.amountFromCol != null && widget.amountFromCol! < row.length)
          ? _parseAmount(row[widget.amountFromCol!].toString())
          : amountTo;

      final String currencyFrom;
      if (widget.currencyFromCol != null &&
          widget.currencyFromCol! < row.length) {
        final parsedCurFrom = row[widget.currencyFromCol!].toString().trim();
        currencyFrom = parsedCurFrom.isNotEmpty ? parsedCurFrom : currencyTo;
      } else {
        currencyFrom = currencyTo;
      }

      final Category? fromCat = resolveCategory(fromName, true);
      final Category? toCat = resolveCategory(toName, false);

      if (fromCat == null || toCat == null) {
        skippedCount++;
        continue;
      }

      final int baseAmt;
      if (currencyTo == currentBase) {
        baseAmt = amountTo;
      } else if (currencyFrom == currentBase) {
        baseAmt = amountFrom;
      } else {
        baseAmt = amountTo;
      }

      final tx = Transaction(
        id: 'ck_import_${date.millisecondsSinceEpoch}_$i',
        fromId: fromCat.id,
        toId: toCat.id,
        title: widget.noteCol != null && widget.noteCol! < row.length
            ? row[widget.noteCol!].toString().trim()
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

      if (i % 50 == 0 && mounted) {
        setState(() {
          _progress =
              0.4 + (0.4 * ((i - startIndex) / (totalRows - startIndex)));
        });
      }
    }

    setState(() {
      _progress = 0.9;
      // ВИПРАВЛЕНО: Локалізація
      _loadingSubtitle = 'import_saving_data'.tr();
    });

    if (txsToSave.isNotEmpty) {
      await StorageService.saveHistory(db, txsToSave);
    }

    for (final entry in accountDeltas.entries) {
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
            'import_success'.tr(
              args: [txsToSave.length.toString(), skippedCount.toString()],
            ),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _buildTypeButton(
    AppColorsExtension colors,
    CategoryType type,
    CategoryType selectedType,
    String label,
    Color activeColor,
    VoidCallback onTap,
  ) {
    final isSelected = type == selectedType;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
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
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : colors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return PopScope(
      canPop: !_isProcessing,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: colors.bgGradientStart,
            appBar: AppBar(
              title: Text(
                'import_step3_title'.tr(),
                style: TextStyle(color: colors.textMain, fontSize: 18),
              ),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: colors.textMain),
            ),
            body: SafeArea(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: colors.accent),
                    )
                  : Column(
                      children: [
                        if (_pendingTypes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              'import_step3_desc'.tr(),
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        Expanded(
                          child: _pendingTypes.isEmpty
                              ? _buildEmptyState(colors)
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20.0,
                                  ),
                                  itemCount: _pendingTypes.length,
                                  itemBuilder: (context, index) {
                                    final catName = _pendingTypes.keys
                                        .elementAt(index);
                                    final currentType = _pendingTypes[catName]!;
                                    final isArchived =
                                        _pendingArchive[catName]!;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colors.cardBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: colors.textSecondary
                                              .withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  catName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: colors.textMain,
                                                    fontSize: 16,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'import_archive'.tr(),
                                                    style: TextStyle(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Transform.scale(
                                                    scale: 0.8,
                                                    child: Switch(
                                                      value: isArchived,
                                                      activeThumbColor:
                                                          colors.accent,
                                                      activeTrackColor: colors
                                                          .accent
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      materialTapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                      onChanged: (val) {
                                                        setState(() {
                                                          _pendingArchive[catName] =
                                                              val;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildTypeButton(
                                                  colors,
                                                  CategoryType.income,
                                                  currentType,
                                                  'import_type_income'.tr(),
                                                  Colors.green,
                                                  () => setState(
                                                    () =>
                                                        _pendingTypes[catName] =
                                                            CategoryType.income,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _buildTypeButton(
                                                  colors,
                                                  CategoryType.account,
                                                  currentType,
                                                  'import_type_account'.tr(),
                                                  Colors.blue,
                                                  () => setState(
                                                    () =>
                                                        _pendingTypes[catName] =
                                                            CategoryType
                                                                .account,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _buildTypeButton(
                                                  colors,
                                                  CategoryType.expense,
                                                  currentType,
                                                  'import_type_expense'.tr(),
                                                  Colors.red,
                                                  () => setState(
                                                    () =>
                                                        _pendingTypes[catName] =
                                                            CategoryType
                                                                .expense,
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
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _executeImport,
                              child: Text(
                                'import_finish_btn'.tr(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(16),
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
                              'import_in_progress'.tr(),
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
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'import_all_categories_known'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            'import_all_categories_known_desc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
