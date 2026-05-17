import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors_extension.dart';
import '../../utils/import_recognizer.dart';
import 'import_category_setup_screen.dart';

class ImportColumnMappingScreen extends StatefulWidget {
  final List<List<dynamic>> rawRows;
  final int headerRowIndex;

  const ImportColumnMappingScreen({
    super.key,
    required this.rawRows,
    required this.headerRowIndex,
  });

  @override
  State<ImportColumnMappingScreen> createState() =>
      _ImportColumnMappingScreenState();
}

class _ImportColumnMappingScreenState extends State<ImportColumnMappingScreen> {
  late List<String> _headers;

  int? _dateCol;
  int? _fromCol;
  int? _toCol;
  int? _amountFromCol;
  int? _currencyFromCol;
  int? _amountToCol;
  int? _currencyToCol;
  int? _noteCol;

  @override
  void initState() {
    super.initState();
    final headerRow = widget.rawRows[widget.headerRowIndex];
    _headers = headerRow.map((e) => e.toString().trim()).toList();
    _autoGuessColumns();
  }

  void _autoGuessColumns() {
    for (int i = 0; i < _headers.length; i++) {
      final h = _headers[i].toLowerCase();
      if (h.isEmpty) {
        continue;
      }

      if (_dateCol == null && ImportRecognizer.isDate(h)) {
        _dateCol = i;
      } else if (_fromCol == null && ImportRecognizer.isFrom(h)) {
        _fromCol = i;
      } else if (_toCol == null && ImportRecognizer.isTo(h)) {
        _toCol = i;
      } else if (_amountFromCol == null && ImportRecognizer.isAmountFrom(h)) {
        _amountFromCol = i;
      } else if (_currencyFromCol == null &&
          ImportRecognizer.isCurrencyFrom(h)) {
        _currencyFromCol = i;
      } else if (_amountToCol == null && ImportRecognizer.isAmountTo(h)) {
        _amountToCol = i;
      } else if (_currencyToCol == null && ImportRecognizer.isCurrencyTo(h)) {
        _currencyToCol = i;
      } else if (_noteCol == null && ImportRecognizer.isNote(h)) {
        _noteCol = i;
      }
    }

    _amountToCol ??= _amountFromCol;
    _currencyToCol ??= _currencyFromCol;
  }

  void _onNextPressed() {
    if (_dateCol == null || (_amountFromCol == null && _amountToCol == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('import_step2_error'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Set<String> uniqueCategories = {};
    int invalidConsecutiveRows = 0;

    for (int i = widget.headerRowIndex + 1; i < widget.rawRows.length; i++) {
      final row = widget.rawRows[i];
      if (row.isEmpty) {
        invalidConsecutiveRows++;
        if (invalidConsecutiveRows >= 3) break;
        continue;
      }

      if (_dateCol != null && _dateCol! < row.length) {
        final dateStr = row[_dateCol!].toString().trim();
        if (!RegExp(r'\d').hasMatch(dateStr)) {
          invalidConsecutiveRows++;
          if (invalidConsecutiveRows >= 3) break;
          continue;
        }
      }

      invalidConsecutiveRows = 0;

      if (_fromCol != null && _fromCol! < row.length) {
        final val = row[_fromCol!].toString().trim();
        if (val.isNotEmpty) {
          uniqueCategories.add(val);
        }
      }

      if (_toCol != null && _toCol! < row.length) {
        final val = row[_toCol!].toString().trim();
        if (val.isNotEmpty) {
          uniqueCategories.add(val);
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportCategorySetupScreen(
          rawRows: widget.rawRows,
          headerRowIndex: widget.headerRowIndex,
          dateCol: _dateCol,
          fromCol: _fromCol,
          toCol: _toCol,
          amountFromCol: _amountFromCol,
          currencyFromCol: _currencyFromCol,
          amountToCol: _amountToCol,
          currencyToCol: _currencyToCol,
          noteCol: _noteCol,
          foundCategories: uniqueCategories.toList(),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    AppColorsExtension colors,
    String title,
    int? currentValue,
    ValueChanged<int?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              title,
              style: TextStyle(
                color: colors.textMain,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            height: 24,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: colors.textSecondary.withValues(alpha: 0.2),
          ),
          Expanded(
            flex: 6,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: currentValue,
                dropdownColor: colors.cardBg,
                icon: Icon(Icons.keyboard_arrow_down, color: colors.accent),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'import_not_selected'.tr(),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ...List.generate(_headers.length, (index) {
                    return DropdownMenuItem<int?>(
                      value: index,
                      child: Text(
                        // ВИПРАВЛЕНО: Використання локалізації для дефолтної колонки
                        _headers[index].isEmpty
                            ? 'import_column_fallback'.tr(
                                args: [(index + 1).toString()],
                              )
                            : _headers[index],
                        style: TextStyle(color: colors.textMain, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return Scaffold(
      backgroundColor: colors.bgGradientStart,
      appBar: AppBar(
        title: Text(
          'import_step2_title'.tr(),
          style: TextStyle(color: colors.textMain, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textMain),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'import_step2_desc'.tr(),
                style: TextStyle(fontSize: 15, color: colors.textSecondary),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                children: [
                  _buildDropdown(
                    colors,
                    'import_col_date'.tr(),
                    _dateCol,
                    (val) => setState(() => _dateCol = val),
                  ),
                  _buildDropdown(
                    colors,
                    'import_col_from'.tr(),
                    _fromCol,
                    (val) => setState(() => _fromCol = val),
                  ),
                  _buildDropdown(
                    colors,
                    'import_col_to'.tr(),
                    _toCol,
                    (val) => setState(() => _toCol = val),
                  ),
                  const Divider(height: 32),
                  _buildDropdown(
                    colors,
                    'import_col_amount_from'.tr(),
                    _amountFromCol,
                    (val) => setState(() => _amountFromCol = val),
                  ),
                  _buildDropdown(
                    colors,
                    'import_col_currency_from'.tr(),
                    _currencyFromCol,
                    (val) => setState(() => _currencyFromCol = val),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    colors,
                    'import_col_amount_to'.tr(),
                    _amountToCol,
                    (val) => setState(() => _amountToCol = val),
                  ),
                  _buildDropdown(
                    colors,
                    'import_col_currency_to'.tr(),
                    _currencyToCol,
                    (val) => setState(() => _currencyToCol = val),
                  ),
                  const Divider(height: 32),
                  _buildDropdown(
                    colors,
                    'import_col_note'.tr(),
                    _noteCol,
                    (val) => setState(() => _noteCol = val),
                  ),
                ],
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _onNextPressed,
                  child: Text(
                    'import_next'.tr(),
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
    );
  }
}
