import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

// 👇 1. Замінили provider на flutter_riverpod
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_constants.dart';
import '../utils/icon_helper.dart';
import '../theme/app_colors_extension.dart';
import '../theme/category_defaults.dart';
import '../models/app_currency.dart';
import '../widgets/common/app_pill.dart';

// 👇 2. Підключаємо наш хаб провайдерів
import '../providers/all_providers.dart';

// 👇 3. Змінили StatefulWidget на ConsumerStatefulWidget
class CategoryScreen extends ConsumerStatefulWidget {
  final Category? category;
  final CategoryType type;

  const CategoryScreen({super.key, this.category, required this.type});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

// 👇 4. Змінили State на ConsumerState
class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _budgetCtrl;
  late TextEditingController _currencyCtrl;
  late IconData _selectedIcon;

  String? _selectedCurrency;
  bool _includeInTotal = true;

  bool _showNameError = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _currencyCtrl = TextEditingController();

    String formatInt(int val) {
      final double displayVal = val / 100.0;
      final String str = displayVal
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'\.?0*$'), '');
      final parts = str.split('.');
      final String intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ',
      );
      return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
    }

    _amountCtrl = TextEditingController(
      text: widget.category != null ? formatInt(widget.category!.amount) : '',
    );
    _budgetCtrl = TextEditingController(
      text: widget.category?.budget != null
          ? formatInt(widget.category!.budget!)
          : '',
    );

    final IconData? iconFromDb = widget.category != null
        ? IconHelper.getIcon(widget.category!.icon)
        : null;

    _selectedIcon = (iconFromDb != null)
        ? iconFromDb
        : AppConstants.groupedIcons.values.first.first;

    _nameCtrl.addListener(() {
      if (_showNameError && _nameCtrl.text.trim().isNotEmpty) {
        setState(() => _showNameError = false);
      }
    });

    // 👇 5. Отримуємо базову валюту з налаштувань
    final settings = ref.read(settingsProvider);
    _selectedCurrency = widget.category?.currency ?? settings.baseCurrency;
    _includeInTotal = widget.category?.includeInTotal ?? true;
    _updateCurrencyText(_selectedCurrency!);
  }

  void _updateCurrencyText(String code) {
    _currencyCtrl.text = 'currency_names.$code'.tr();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _budgetCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  void _openIconPicker() {
    FocusScope.of(context).unfocus();
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'choose_icon'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    for (var entry in AppConstants.groupedIcons.entries) ...[
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 12),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 60,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final IconData icon = entry.value[i];
                          final bool isSelected = _selectedIcon == icon;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedIcon = icon);
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blueAccent
                                    : colors.iconBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: isSelected
                                    ? Colors.white
                                    : colors.textMain,
                                size: 26,
                              ),
                            ),
                          );
                        }, childCount: entry.value.length),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCurrencyPicker() {
    FocusScope.of(context).unfocus();
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    // Сортуємо: базова валюта завжди перша, інші за алфавітом
    final baseCurrency = ref.read(settingsProvider).baseCurrency;
    final List<String> availableCurrencies = AppCurrency.supportedCurrencies
        .map((c) => c.code)
        .toList();

    availableCurrencies.remove(baseCurrency);
    availableCurrencies.sort();
    availableCurrencies.insert(0, baseCurrency);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'currency'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  itemCount: availableCurrencies.length,
                  itemBuilder: (context, index) {
                    final code = availableCurrencies[index];
                    final curr = AppCurrency.fromCode(code);

                    final bool isSelected = _selectedCurrency == code;
                    final bool isBase =
                        code ==
                        baseCurrency; // 👈 Визначаємо, чи це базова валюта

                    // Колір акценту: зелений для базової, акцентний для інших
                    final Color activeColor = isBase
                        ? colors.income
                        : colors.accent;

                    return ListTile(
                      onTap: () {
                        setState(() {
                          _selectedCurrency = code;
                          _updateCurrencyText(code);
                        });
                        Navigator.pop(ctx);
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minLeadingWidth: 0,
                      leading: AppPill(
                        text: '${curr.code}  ${curr.symbol}',
                        color: activeColor,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'currency_names.${curr.code}'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected
                                    ? activeColor
                                    : colors.textMain,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isBase) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: activeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'base_currency_label'.tr(),
                                style: TextStyle(
                                  color: activeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: activeColor)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveCategory() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _showNameError = true);
      return;
    }

    final double parsedAmount =
        double.tryParse(
          _amountCtrl.text.replaceAll(',', '.').replaceAll(' ', ''),
        ) ??
        0.0;
    final int finalAmount = (parsedAmount * 100).round();

    int? finalBudget;
    final double? parsedBudget = double.tryParse(
      _budgetCtrl.text.replaceAll(',', '.').replaceAll(' ', ''),
    );
    if (parsedBudget != null) {
      finalBudget = (parsedBudget * 100).round();
    }

    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'icon': _selectedIcon.codePoint,
      'amount': finalAmount,
      'budget': finalBudget,
      'currency': _selectedCurrency,
      'includeInTotal': _includeInTotal,
    });
  }

  Future<void> _deleteCategory() async {
    if (widget.category == null) return;
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: colors.cardBg,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.expense.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: colors.expense,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'delete_category_title'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textMain,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final itemName = widget.category!.name;
                      final fullText = 'delete_category_message'.tr(
                        args: [itemName],
                      );
                      final nameIndex = fullText.indexOf(itemName);

                      return Text.rich(
                        TextSpan(
                          children: nameIndex != -1
                              ? [
                                  TextSpan(
                                    text: fullText.substring(0, nameIndex),
                                  ),
                                  TextSpan(
                                    text: itemName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textMain,
                                    ),
                                  ),
                                  TextSpan(
                                    text: fullText.substring(
                                      nameIndex + itemName.length,
                                    ),
                                  ),
                                ]
                              : [TextSpan(text: fullText)],
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            'cancel'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.expense,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            'delete'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;

    if (!mounted) return;

    if (confirmed) {
      Navigator.pop(context, 'delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    // 👇 6. Тепер використовуємо ref.watch для реактивного доступу
    final settings = ref.watch(settingsProvider);

    final Color previewBgColor = CategoryDefaults.getBgColor(widget.type);
    final Color previewIconColor = CategoryDefaults.getIconColor(widget.type);

    // 👇 Візуально підсвічуємо валюту на формі, якщо вона базова
    final bool isCurrentBase = _selectedCurrency == settings.baseCurrency;
    final Color currencyAccentColor = isCurrentBase
        ? colors.income
        : colors.accent;

    final currencyCode = _selectedCurrency ?? settings.baseCurrency;
    final currencySymbol = AppCurrency.fromCode(currencyCode).symbol;

    return Scaffold(
      backgroundColor: colors.cardBg,
      body: SafeArea(
        child: Column(
          children: [
            // ШАПКА
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: colors.textSecondary,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    widget.category == null ? 'new_category'.tr() : 'edit'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textMain,
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.category != null)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colors.expense,
                            size: 26,
                          ),
                          onPressed: _deleteCategory,
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.check,
                          color: Colors.blueAccent,
                          size: 28,
                        ),
                        onPressed: _saveCategory,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    // КОМПАКТНА МОНЕТКА ДЛЯ ПЕРЕГЛЯДУ
                    GestureDetector(
                      onTap: _openIconPicker,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: previewBgColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: previewBgColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _selectedIcon,
                              color: previewIconColor,
                              size: 36,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.cardBg,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.blueAccent,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ЧИСТИЙ МІНІМАЛІСТИЧНИЙ ФОРМ-БЛОК
                    Column(
                      children: [
                        // 1. НАЗВА
                        _buildMaterialField(
                          controller: _nameCtrl,
                          label: 'name'.tr(),
                          colors: colors,
                          maxLength: 20,
                          isError: _showNameError,
                        ),
                        const SizedBox(height: 16),

                        // 2. ВАЛЮТА
                        TextField(
                          controller: _currencyCtrl,
                          readOnly: true,
                          onTap: _openCurrencyPicker,
                          style: TextStyle(
                            color: isCurrentBase
                                ? currencyAccentColor
                                : colors.textMain, // Підсвітка в полі
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            labelText: 'currency'.tr(),
                            labelStyle: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 16,
                            ),
                            floatingLabelStyle: TextStyle(
                              color: currencyAccentColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            prefix: Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: AppPill(
                                text: '$currencyCode  $currencySymbol',
                                color: currencyAccentColor,
                              ),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: colors.textSecondary,
                              ),
                            ),
                            counterText: '',
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: isCurrentBase
                                    ? currencyAccentColor.withValues(alpha: 0.5)
                                    : colors.textSecondary.withValues(
                                        alpha: 0.3,
                                      ),
                                width: 1,
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: currencyAccentColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. РАХУНОК (АКАУНТ)
                        if (widget.type == CategoryType.account) ...[
                          _buildMaterialField(
                            controller: _amountCtrl,
                            label: widget.category == null
                                ? 'initial_balance'.tr()
                                : 'current_balance'.tr(),
                            colors: colors,
                            isNumber: true,
                            suffix: ' $currencySymbol',
                          ),
                          const SizedBox(height: 16),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'include_in_total'.tr(),
                              style: TextStyle(
                                color: colors.textMain,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            value: _includeInTotal,
                            activeThumbColor: Colors.blueAccent,
                            onChanged: (val) =>
                                setState(() => _includeInTotal = val),
                          ),
                        ],

                        // 4. БЮДЖЕТ (ДЛЯ ВИТРАТ ТА ДОХОДІВ)
                        if (widget.type != CategoryType.account) ...[
                          _buildMaterialField(
                            controller: _budgetCtrl,
                            label: 'monthly_budget'.tr(),
                            colors: colors,
                            isNumber: true,
                            suffix: ' $currencySymbol',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ДОПОМІЖНИЙ ВІДЖЕТ ДЛЯ МАТЕРІАЛ-ПОЛЯ
  Widget _buildMaterialField({
    required TextEditingController controller,
    required String label,
    required AppColorsExtension colors,
    String? suffix,
    bool isNumber = false,
    int? maxLength,
    bool isError = false,
  }) {
    final baseColor = isError ? Colors.red : colors.textSecondary;
    final activeColor = isError ? Colors.red : Colors.blueAccent;
    final underlineBaseColor = isError
        ? Colors.red
        : colors.textSecondary.withValues(alpha: 0.3);

    return TextField(
      controller: controller,
      maxLength: isNumber ? null : maxLength,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [
              TextInputFormatter.withFunction((oldValue, newValue) {
                String text = newValue.text
                    .replaceAll(',', '.')
                    .replaceAll(' ', '');
                if (text.isEmpty) return newValue.copyWith(text: text);

                if (text.indexOf('.') != text.lastIndexOf('.')) return oldValue;

                if (text.length > 1 &&
                    text.startsWith('0') &&
                    !text.startsWith('0.')) {
                  text = text.replaceFirst(RegExp(r'^0+'), '');
                  if (text.isEmpty) text = '0';
                }

                if (text.startsWith('.')) text = '0$text';

                final parts = text.split('.');
                String intPart = parts[0];
                String? decPart = parts.length > 1 ? parts[1] : null;

                if (intPart.length > 12) {
                  intPart = intPart.substring(0, 12);
                }

                if (decPart != null && decPart.length > 2) {
                  decPart = decPart.substring(0, 2);
                }

                final String formattedInt = intPart.replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]} ',
                );

                final String newString = decPart == null
                    ? formattedInt
                    : (text.endsWith('.')
                          ? '$formattedInt.'
                          : '$formattedInt.$decPart');

                return TextEditingValue(
                  text: newString,
                  selection: TextSelection.collapsed(offset: newString.length),
                );
              }),
            ]
          : null,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        color: colors.textMain,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: false,
        labelText: label,
        labelStyle: TextStyle(color: baseColor, fontSize: 16),
        floatingLabelStyle: TextStyle(
          color: activeColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: colors.textSecondary,
          fontSize: 16,
        ),
        counterText: '',
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: underlineBaseColor,
            width: isError ? 2 : 1,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: activeColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        isDense: true,
      ),
    );
  }
}
