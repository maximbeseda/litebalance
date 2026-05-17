import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors_extension.dart';
import 'import_column_mapping_screen.dart';

class ImportHeaderSelectionScreen extends StatefulWidget {
  final List<List<dynamic>> rawRows;

  const ImportHeaderSelectionScreen({super.key, required this.rawRows});

  @override
  State<ImportHeaderSelectionScreen> createState() =>
      _ImportHeaderSelectionScreenState();
}

class _ImportHeaderSelectionScreenState
    extends State<ImportHeaderSelectionScreen> {
  int? _selectedIndex;

  late final List<List<dynamic>> _previewRows;

  @override
  void initState() {
    super.initState();
    _previewRows = widget.rawRows.take(50).toList();
  }

  // ПОКРАЩЕНА ПЕРЕВІРКА: Шукаємо дати. Якщо є дата — це дані, а не заголовок
  bool _isValidHeaderRow(List<dynamic> row) {
    int textColumnsCount = 0;
    bool hasDateLike = false;

    // Регулярний вираз для пошуку дат у форматах dd.mm.yyyy, yyyy-mm-dd тощо
    final dateRegExp = RegExp(r'\b\d{1,4}[\./-]\d{1,2}[\./-]\d{1,4}\b');

    for (final cell in row) {
      final str = cell.toString().trim();
      if (str.isEmpty) {
        continue;
      }

      if (dateRegExp.hasMatch(str)) {
        hasDateLike = true;
      }

      if (double.tryParse(str) == null) {
        textColumnsCount++;
      }
    }

    // Рядок вважається заголовком, якщо є текст і НЕМАЄ нічого схожого на дати
    return textColumnsCount >= 2 && !hasDateLike;
  }

  void _onNextPressed() {
    if (_selectedIndex == null) {
      return;
    }

    final selectedRow = _previewRows[_selectedIndex!];

    if (!_isValidHeaderRow(selectedRow)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('import_step1_error'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportColumnMappingScreen(
          rawRows: widget.rawRows,
          headerRowIndex: _selectedIndex!,
        ),
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
          'import_step1_title'.tr(),
          style: TextStyle(color: colors.textMain, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textMain),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'import_step1_desc'.tr(),
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InteractiveViewer(
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(16),
                  minScale: 0.5,
                  maxScale: 2.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(_previewRows.length, (rowIndex) {
                      final row = _previewRows[rowIndex];
                      final isSelected = _selectedIndex == rowIndex;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = rowIndex;
                          });
                        },
                        child: Container(
                          color: isSelected
                              ? colors.accent.withValues(alpha: 0.3)
                              : (rowIndex % 2 == 0
                                    ? Colors.transparent
                                    : colors.textSecondary.withValues(
                                        alpha: 0.05,
                                      )),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: colors.textSecondary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    bottom: BorderSide(
                                      color: colors.textSecondary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                                child: Text(
                                  '${rowIndex + 1}',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              ...row.map((cell) {
                                return Container(
                                  width: 120,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: colors.textSecondary.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                      bottom: BorderSide(
                                        color: colors.textSecondary.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    cell.toString(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? colors.textMain
                                          : colors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                  onPressed: _selectedIndex == null ? null : _onNextPressed,
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
          ),
        ],
      ),
    );
  }
}
