import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';

import 'import_wizard/import_header_selection_screen.dart';
import '../providers/all_providers.dart';
import '../utils/app_page_route.dart';
import '../services/export_import_service.dart';
import '../theme/app_colors_extension.dart';
import '../widgets/dialogs/custom_date_range_picker.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/section_header.dart';
import '../utils/icon_helper.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _exportOnlyFiltered = false;

  DateTimeRange? _exportDateRange;

  final Set<CategoryType> _exportTypes = {
    CategoryType.income,
    CategoryType.expense,
    CategoryType.account,
  };

  final Set<String> _exportCategoryIds = {};

  List<Transaction> _getFilteredTransactions() {
    // 👇 ВИПРАВЛЕНО: дістаємо історію з AsyncValue
    final txAsync = ref.read(transactionProvider);
    final allTransactions = txAsync.value?.history ?? [];

    if (!_exportOnlyFiltered) return allTransactions;

    final categories = ref.read(categoryProvider).allCategoriesList;
    final catMap = {for (var c in categories) c.id: c};

    return allTransactions.where((tx) {
      if (_exportDateRange != null) {
        if (tx.date.isBefore(_exportDateRange!.start) ||
            tx.date.isAfter(
              _exportDateRange!.end.add(const Duration(days: 1)),
            )) {
          return false;
        }
      }
      final fromCat = catMap[tx.fromId];
      final toCat = catMap[tx.toId];
      CategoryType txType = CategoryType.expense;
      if (fromCat?.type == CategoryType.income) txType = CategoryType.income;
      if (fromCat?.type == CategoryType.account &&
          toCat?.type == CategoryType.account) {
        txType = CategoryType.account;
      }
      if (!_exportTypes.contains(txType)) return false;
      if (_exportCategoryIds.isNotEmpty) {
        if (!_exportCategoryIds.contains(tx.fromId) &&
            !_exportCategoryIds.contains(tx.toId)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final List<Transaction> txToExport = _getFilteredTransactions();
    final List<Category> allCats = ref.read(categoryProvider).allCategoriesList;

    final result = await ExportImportService.exportToCsv(
      transactions: txToExport,
      allCategories: allCats,
    );

    setState(() => _isExporting = false);

    if (mounted) {
      if (result == 'success') {
        AppSnackbar.success(context, 'export_success'.tr());
      } else if (result == 'error') {
        AppSnackbar.error(context, 'export_error'.tr());
      }
    }
  }

  void _handleImport() async {
    if (_isImporting) return;

    FilePickerResult? result;

    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isImporting = true);
        final file = File(result.files.single.path!);
        final rawRows = await ExportImportService.readCsvRaw(file);

        if (mounted) {
          setState(() => _isImporting = false);

          if (rawRows != null && rawRows.isNotEmpty) {
            unawaited(
              Navigator.push(
                context,
                appPageRoute(ImportHeaderSelectionScreen(rawRows: rawRows)),
              ),
            );
          } else {
            AppSnackbar.error(context, 'import_format_error'.tr());
          }
        }
      }
    } catch (e) {
      debugPrint('Помилка вибору файлу CSV: $e');
    } finally {
      if (result != null) {
        try {
          await FilePicker.platform.clearTemporaryFiles();
          debugPrint('✅ Кеш FilePicker (Імпорт CSV) успішно очищено');
        } catch (e) {
          debugPrint('❌ Не вдалося очистити кеш FilePicker (CSV): $e');
        }
      }
    }
  }

  Widget _buildCheckRow(
    AppColorsExtension colors,
    String title,
    bool isSelected,
    Color activeColor,
    VoidCallback onTap, {
    Widget? leadingIcon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              leadingIcon,
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: colors.textMain,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? Colors.grey.shade600 : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? Colors.grey.shade600
                      : colors.textSecondary.withValues(alpha: 0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGroup(
    AppColorsExtension colors,
    String title,
    List<Category> cats,
    StateSetter setModalState,
  ) {
    if (cats.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...cats.map((cat) {
          return _buildCheckRow(
            colors,
            cat.name,
            _exportCategoryIds.contains(cat.id),
            colors.accent,
            () {
              setModalState(() {
                if (_exportCategoryIds.contains(cat.id)) {
                  _exportCategoryIds.remove(cat.id);
                } else {
                  _exportCategoryIds.add(cat.id);
                }
              });
              setState(() {});
            },
            leadingIcon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(cat.bgColor),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconHelper.getIcon(cat.icon),
                size: 20,
                color: Color(cat.iconColor),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showFilterSheet(AppColorsExtension colors) {
    final allCats = ref
        .read(categoryProvider)
        .allCategoriesList
        .where((c) => !c.isArchived)
        .toList();
    final incomeCats = allCats
        .where((c) => c.type == CategoryType.income)
        .toList();
    final expenseCats = allCats
        .where((c) => c.type == CategoryType.expense)
        .toList();
    final accountCats = allCats
        .where((c) => c.type == CategoryType.account)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Container(
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 20,
                    ),
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.textSecondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'filter_settings'.tr(),
                          style: TextStyle(
                            color: colors.textMain,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'filter_period'.tr().toUpperCase(),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final result = await showModalBottomSheet<dynamic>(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => CustomDateRangePicker(
                                initialRange: _exportDateRange,
                                colors: colors,
                              ),
                            );
                            if (result != null) {
                              if (result is DateTimeRange) {
                                setModalState(() => _exportDateRange = result);
                                setState(() {});
                              } else if (result is ResetRangeSignal) {
                                setModalState(() => _exportDateRange = null);
                                setState(() {});
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: colors.textSecondary.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.textSecondary.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.date_range_rounded,
                                  color: colors.accent,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    _exportDateRange == null
                                        ? 'filter_all_time'.tr()
                                        : "${DateFormat('dd.MM.yyyy').format(_exportDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_exportDateRange!.end)}",
                                    style: TextStyle(
                                      color: colors.textMain,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: colors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'filter_tx_type'.tr().toUpperCase(),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            _buildCheckRow(
                              colors,
                              'filter_type_incomes'.tr(),
                              _exportTypes.contains(CategoryType.income),
                              Colors.green,
                              () {
                                setModalState(() {
                                  _exportTypes.contains(CategoryType.income)
                                      ? _exportTypes.remove(CategoryType.income)
                                      : _exportTypes.add(CategoryType.income);
                                });
                                setState(() {});
                              },
                              leadingIcon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.north_east_rounded,
                                  size: 20,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            _buildCheckRow(
                              colors,
                              'filter_type_expenses'.tr(),
                              _exportTypes.contains(CategoryType.expense),
                              Colors.red,
                              () {
                                setModalState(() {
                                  _exportTypes.contains(CategoryType.expense)
                                      ? _exportTypes.remove(
                                          CategoryType.expense,
                                        )
                                      : _exportTypes.add(CategoryType.expense);
                                });
                                setState(() {});
                              },
                              leadingIcon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.south_east_rounded,
                                  size: 20,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            _buildCheckRow(
                              colors,
                              'filter_type_transfers'.tr(),
                              _exportTypes.contains(CategoryType.account),
                              Colors.blue,
                              () {
                                setModalState(() {
                                  _exportTypes.contains(CategoryType.account)
                                      ? _exportTypes.remove(
                                          CategoryType.account,
                                        )
                                      : _exportTypes.add(CategoryType.account);
                                });
                                setState(() {});
                              },
                              leadingIcon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.sync_alt_rounded,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'filter_categories'.tr().toUpperCase(),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCheckRow(
                              colors,
                              'filter_all_categories'.tr(),
                              _exportCategoryIds.isEmpty,
                              colors.accent,
                              () {
                                setModalState(() => _exportCategoryIds.clear());
                                setState(() {});
                              },
                              leadingIcon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.checklist_rounded,
                                  size: 20,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCategoryGroup(
                              colors,
                              'filter_type_incomes'.tr().toUpperCase(),
                              incomeCats,
                              setModalState,
                            ),
                            _buildCategoryGroup(
                              colors,
                              'filter_type_transfers'.tr().toUpperCase(),
                              accountCats,
                              setModalState,
                            ),
                            _buildCategoryGroup(
                              colors,
                              'filter_type_expenses'.tr().toUpperCase(),
                              expenseCats,
                              setModalState,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'apply'.tr(),
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
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final exportCount = _getFilteredTransactions().length;

    return Scaffold(
      backgroundColor: colors.cardBg,
      appBar: AppBar(
        title: Text(
          'data_management'.tr(),
          style: TextStyle(
            color: colors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(color: colors.textMain),
        backgroundColor: colors.cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- ЕКСПОРТ ---
              SectionHeader(
                'export_csv'.tr(),
                padding: const EdgeInsets.only(bottom: 12),
              ),
              Text(
                'export_description'.tr(),
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: colors.income,
                activeTrackColor: colors.income.withValues(alpha: 0.5),
                title: Text(
                  'export_only_filtered'.tr(),
                  style: TextStyle(
                    color: colors.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _exportOnlyFiltered
                      ? 'exporting_count'.tr(args: ['$exportCount'])
                      : "${'exporting_count'.tr(args: ['$exportCount'])} (${'exporting_all'.tr()})",
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                value: _exportOnlyFiltered,
                onChanged: (val) {
                  setState(() {
                    _exportOnlyFiltered = val;
                    if (val) _showFilterSheet(colors);
                  });
                },
              ),
              if (_exportOnlyFiltered)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: Icon(
                      Icons.tune_rounded,
                      color: colors.accent,
                      size: 20,
                    ),
                    label: Text(
                      'filter_settings'.tr(),
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _showFilterSheet(colors),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      backgroundColor: colors.accent.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.income,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isExporting ? null : _handleExport,
                  child: _isExporting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'export_button'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 28),
              Divider(height: 1, color: colors.divider),
              const SizedBox(height: 24),
              // --- ІМПОРТ ---
              SectionHeader(
                'import_csv'.tr(),
                padding: const EdgeInsets.only(bottom: 12),
              ),
              Text(
                'import_description'.tr(),
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isImporting ? null : _handleImport,
                  child: _isImporting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'import_button'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
