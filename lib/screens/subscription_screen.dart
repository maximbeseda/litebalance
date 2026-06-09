import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../providers/all_providers.dart';

import '../models/app_currency.dart';
import '../utils/app_constants.dart';
import '../utils/date_formatter.dart';
import '../utils/icon_helper.dart';
import '../widgets/dialogs/premium_date_picker.dart';
import '../theme/app_colors_extension.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_picker_sheet.dart';
import '../widgets/common/app_pill.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  final Subscription? subscription;

  const SubscriptionScreen({super.key, this.subscription});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _periodicityCtrl;
  late TextEditingController _accountCtrl;
  late TextEditingController _expenseCtrl;
  late TextEditingController _dateCtrl;

  String? _selectedCurrency;
  String? _selectedAccountId;
  String? _selectedExpenseId;
  String _selectedPeriodicity = 'monthly';
  late DateTime _selectedDate;

  int? _customIconCodePoint;
  bool _isAutoPay = false;

  bool _showNameError = false;
  bool _showAmountError = false;
  bool _showAccountError = false;
  bool _showExpenseError = false;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    final sub = widget.subscription;

    _nameCtrl = TextEditingController(text: sub?.name ?? '');

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
      text: sub != null ? formatInt(sub.amount) : '',
    );

    _currencyCtrl = TextEditingController();
    _periodicityCtrl = TextEditingController();
    _accountCtrl = TextEditingController();
    _expenseCtrl = TextEditingController();
    _dateCtrl = TextEditingController();

    _selectedPeriodicity = sub?.periodicity ?? 'monthly';
    _selectedDate = sub?.nextPaymentDate ?? DateTime.now();
    _customIconCodePoint = sub?.customIconCodePoint;
    _isAutoPay = sub?.isAutoPay ?? false;

    _nameCtrl.addListener(() {
      if (_showNameError && _nameCtrl.text.trim().isNotEmpty) {
        setState(() => _showNameError = false);
      }
    });
    _amountCtrl.addListener(() {
      if (_showAmountError && _amountCtrl.text.trim().isNotEmpty) {
        setState(() => _showAmountError = false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      final catState = ref.read(categoryProvider);
      final settingsState = ref.read(settingsProvider);

      if (_selectedCurrency == null) {
        _selectedCurrency =
            widget.subscription?.currency ?? settingsState.baseCurrency;
        _updateCurrencyText(_selectedCurrency!);
      }

      if (_selectedAccountId == null && widget.subscription != null) {
        final bool accountExists = catState.accounts.any(
          (c) => c.id == widget.subscription?.accountId,
        );
        if (accountExists) {
          _selectedAccountId = widget.subscription!.accountId;
          _updateCategoryText(
            _accountCtrl,
            catState.accounts,
            _selectedAccountId!,
          );
        }
      }

      if (_selectedExpenseId == null && widget.subscription != null) {
        final bool expenseExists = catState.expenses.any(
          (c) => c.id == widget.subscription?.categoryId,
        );
        if (expenseExists) {
          _selectedExpenseId = widget.subscription!.categoryId;
          _updateCategoryText(
            _expenseCtrl,
            catState.expenses,
            _selectedExpenseId!,
          );
        }
      }

      _updatePeriodicityText(_selectedPeriodicity);
      _updateDateText(_selectedDate);

      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _currencyCtrl.dispose();
    _periodicityCtrl.dispose();
    _accountCtrl.dispose();
    _expenseCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _updateCurrencyText(String code) {
    _currencyCtrl.text = AppCurrency.fromCode(code).code;
  }

  void _updatePeriodicityText(String period) {
    if (period == 'monthly') {
      _periodicityCtrl.text = 'period_monthly'.tr();
    } else if (period == 'yearly') {
      _periodicityCtrl.text = 'period_yearly'.tr();
    } else if (period == 'weekly') {
      _periodicityCtrl.text = 'period_weekly'.tr();
    } else if (period == 'every_28_days') {
      _periodicityCtrl.text = 'period_28_days'.tr();
    } else if (period == 'every_30_days') {
      _periodicityCtrl.text = 'period_30_days'.tr();
    }
  }

  void _updateCategoryText(
    TextEditingController ctrl,
    List<Category> list,
    String id,
  ) {
    ctrl.text = list.firstWhereOrNull((c) => c.id == id)?.name ?? '';
  }

  void _updateDateText(DateTime date) {
    _dateCtrl.text = DateFormatter.formatFull(date);
  }

  // 👇 ОНОВЛЕНО ДЛЯ КОНСИСТЕНТНОСТІ З КАТЕГОРІЯМИ
  Future<void> _openCurrencyPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final baseCurrency = ref.read(settingsProvider).baseCurrency;
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final List<String> codes = AppCurrency.orderedCodes(pin: baseCurrency);

    await AppPickerSheet.show<String>(
      context: context,
      title: 'currency'.tr(),
      selected: _selectedCurrency ?? baseCurrency,
      options: codes.map((code) {
        final curr = AppCurrency.fromCode(code);
        final bool isBase = code == baseCurrency;
        final Color activeColor = isBase ? colors.income : colors.accent;
        return AppPickerOption(
          value: code,
          label: 'currency_names.$code'.tr(),
          leading: AppPill(
            text: '${curr.code}  ${curr.symbol}',
            color: activeColor,
          ),
          color: activeColor,
          badge: isBase ? 'base_currency_label'.tr() : null,
        );
      }).toList(),
      onSelected: (code) {
        setState(() {
          _selectedCurrency = code;
          _updateCurrencyText(code);
        });
      },
    );

    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _openCategoryPicker(
    CategoryType type,
    TextEditingController ctrl,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final catState = ref.read(categoryProvider);
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final list = type == CategoryType.account
        ? catState.accounts
        : catState.expenses;

    final title = type == CategoryType.account
        ? 'write_off_from'.tr()
        : 'expense_category'.tr();

    final currentId = type == CategoryType.account
        ? _selectedAccountId
        : _selectedExpenseId;

    await showModalBottomSheet(
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
                title,
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
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final cat = list[index];
                    final bool isSelected = currentId == cat.id;

                    return ListTile(
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() {
                          if (type == CategoryType.account) {
                            _selectedAccountId = cat.id;
                            _showAccountError = false;
                          } else {
                            _selectedExpenseId = cat.id;
                            _showExpenseError = false;
                          }
                          _updateCategoryText(ctrl, list, cat.id);
                        });
                        Navigator.pop(ctx);
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(cat.bgColor),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          IconHelper.getIcon(cat.icon),
                          size: 18,
                          color: Color(cat.iconColor),
                        ),
                      ),
                      title: Text(
                        cat.name,
                        style: TextStyle(
                          color: isSelected
                              ? colors.accent
                              : colors.textMain,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: colors.accent)
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

    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _openPeriodicityPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final options = {
      'weekly': 'period_weekly'.tr(),
      'every_28_days': 'period_28_days'.tr(),
      'every_30_days': 'period_30_days'.tr(),
      'monthly': 'period_monthly'.tr(),
      'yearly': 'period_yearly'.tr(),
    };

    await AppPickerSheet.show<String>(
      context: context,
      title: 'period'.tr(),
      selected: _selectedPeriodicity,
      options: options.entries
          .map((e) => AppPickerOption(value: e.key, label: e.value))
          .toList(),
      onSelected: (val) {
        setState(() {
          _selectedPeriodicity = val;
          _updatePeriodicityText(val);
        });
      },
    );

    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final pickedDate = await PremiumDatePicker.show(
      context: context,
      initialDate: _selectedDate,
    );

    if (mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _updateDateText(pickedDate);
      });
    }
  }

  Future<void> _openIconPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    await showModalBottomSheet(
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
              ListTile(
                leading: Icon(Icons.refresh, color: colors.accent),
                title: Text(
                  'use_category_icon'.tr(),
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() => _customIconCodePoint = null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              Expanded(
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    for (var entry in AppConstants.groupedIcons.entries) ...[
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 12, top: 10),
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
                          final bool isSelected =
                              _customIconCodePoint == icon.codePoint;
                          return GestureDetector(
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              setState(
                                () => _customIconCodePoint = icon.codePoint,
                              );
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.accent
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
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final double parsedAmount =
        double.tryParse(
          _amountCtrl.text.replaceAll(',', '.').replaceAll(' ', ''),
        ) ??
        0.0;

    final int amountInCents = (parsedAmount * 100).round();

    setState(() {
      _showNameError = _nameCtrl.text.trim().isEmpty;
      _showAmountError = amountInCents <= 0;
      _showAccountError = _selectedAccountId == null;
      _showExpenseError = _selectedExpenseId == null;
    });

    if (_showNameError ||
        _showAmountError ||
        _showAccountError ||
        _showExpenseError) {
      return;
    }

    final subNotifier = ref.read(subscriptionProvider.notifier);
    final settingsState = ref.read(settingsProvider);

    final newSub = Subscription(
      id: widget.subscription?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      amount: amountInCents,
      categoryId: _selectedExpenseId!,
      accountId: _selectedAccountId!,
      nextPaymentDate: _selectedDate,
      periodicity: _selectedPeriodicity,
      customIconCodePoint: _customIconCodePoint,
      isAutoPay: _isAutoPay,
      currency: _selectedCurrency ?? settingsState.baseCurrency,
    );

    final isNew = widget.subscription == null;

    // 👇 ГОЛОВНИЙ ФІКС: Закриваємо екран створення/редагування ДО збереження в базу.
    // Це гарантує, що Navigator.pop не закриє випадково вікно підтвердження.
    if (mounted) Navigator.pop(context);

    if (isNew) {
      await subNotifier.addSubscription(newSub);
    } else {
      await subNotifier.updateSubscription(newSub);
    }
  }

  Future<void> _delete() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.subscription == null) return;
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    // Повідомлення з виділеною жирним назвою підписки.
    final itemName = widget.subscription!.name;
    final fullText = 'delete_subscription_message'.tr(args: [itemName]);
    final nameIndex = fullText.indexOf(itemName);
    final messageWidget = Text.rich(
      TextSpan(
        children: nameIndex != -1
            ? [
                TextSpan(text: fullText.substring(0, nameIndex)),
                TextSpan(
                  text: itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.textMain,
                  ),
                ),
                TextSpan(
                  text: fullText.substring(nameIndex + itemName.length),
                ),
              ]
            : [TextSpan(text: fullText)],
      ),
      textAlign: TextAlign.center,
    );

    final confirmed = await AppDialog.destructive(
      context,
      title: 'delete_subscription_title'.tr(),
      messageWidget: messageWidget,
      confirmText: 'delete'.tr(),
    );

    if (!mounted) return;
    if (confirmed) {
      final notifier = ref.read(subscriptionProvider.notifier);
      final sub = widget.subscription!;

      // 👇 ФІКС: Закриваємо екран ДО того, як відправляти в кошик
      if (mounted) Navigator.pop(context);

      await notifier.moveToTrash(sub);
    }
  }

  Widget _buildMaterialField({
    required TextEditingController controller,
    required String label,
    required AppColorsExtension colors,
    bool isError = false,
    bool isNumber = false,
    int? maxLength,
  }) {
    final baseColor = isError ? Colors.red : colors.textSecondary;
    final activeColor = isError ? Colors.red : colors.accent;
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
        counterText: '',
        labelStyle: TextStyle(color: baseColor, fontSize: 16),
        floatingLabelStyle: TextStyle(
          color: activeColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
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

  // 👇 ОНОВЛЕНО: Додали можливість передавати кастомні кольори (для валюти)
  Widget _buildSelectorField({
    required TextEditingController controller,
    required String label,
    required AppColorsExtension colors,
    required VoidCallback onTap,
    bool isError = false,
    Widget? prefix,
    Widget? suffix,
    Color? customActiveColor,
    Color? customTextColor,
  }) {
    final baseColor = isError ? Colors.red : colors.textSecondary;
    final activeColor = isError
        ? Colors.red
        : (customActiveColor ?? colors.accent);
    final textColor = customTextColor ?? colors.textMain;
    final underlineBaseColor = isError
        ? Colors.red
        : (customActiveColor != null
              ? customActiveColor.withValues(alpha: 0.5)
              : colors.textSecondary.withValues(alpha: 0.3));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: InputDecorator(
        isEmpty: controller.text.isEmpty && prefix == null,
        decoration: InputDecoration(
          filled: false,
          labelText: label,
          labelStyle: TextStyle(color: baseColor, fontSize: 16),
          floatingLabelStyle: TextStyle(
            color: activeColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          prefix: prefix,
          suffixIcon:
              suffix ??
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: colors.textSecondary,
                ),
              ),
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
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            const Text(
              'Wj', // Для підтримки висоти
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.transparent,
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    controller.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold, // Зробили трохи жирнішим для краси
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final catState = ref.watch(categoryProvider);
    final settingsState = ref.watch(settingsProvider);
    final isEditing = widget.subscription != null;

    // 👇 ОНОВЛЕНО: Логіка підсвітки базової валюти
    final bool isCurrentBase =
        (_selectedCurrency ?? settingsState.baseCurrency) ==
        settingsState.baseCurrency;
    final Color currencyAccentColor = isCurrentBase
        ? colors.income
        : colors.accent;

    final currencySymbol = AppCurrency.fromCode(
      _selectedCurrency ?? settingsState.baseCurrency,
    ).symbol;

    IconData displayIcon = Icons.card_giftcard;
    Color displayColor = colors.iconBg;
    Color displayIconColor = colors.textSecondary;

    if (_customIconCodePoint != null) {
      displayIcon = IconHelper.getIcon(_customIconCodePoint!);
      if (_selectedExpenseId != null) {
        final cat = catState.expenses.firstWhereOrNull(
          (c) => c.id == _selectedExpenseId,
        );
        if (cat != null) {
          displayColor = Color(cat.bgColor);
          displayIconColor = Color(cat.iconColor);
        }
      }
    } else if (_selectedExpenseId != null) {
      final cat = catState.expenses.firstWhereOrNull(
        (c) => c.id == _selectedExpenseId,
      );
      if (cat != null) {
        displayIcon = IconHelper.getIcon(cat.icon);
        displayColor = Color(cat.bgColor);
        displayIconColor = Color(cat.iconColor);
      }
    }

    return Scaffold(
      backgroundColor: colors.cardBg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                      isEditing ? 'edit'.tr() : 'new_subscription'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textMain,
                      ),
                    ),
                    Row(
                      children: [
                        if (isEditing)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: colors.expense,
                              size: 26,
                            ),
                            onPressed: _delete,
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.check,
                            color: colors.accent,
                            size: 28,
                          ),
                          onPressed: () => unawaited(_save()),
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
                      GestureDetector(
                        onTap: _openIconPicker,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: displayColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: displayColor.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                displayIcon,
                                color: displayIconColor,
                                size: 36,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.cardBg,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.edit,
                                color: colors.accent,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      _buildMaterialField(
                        controller: _nameCtrl,
                        label: 'name_hint_netflix'.tr(),
                        colors: colors,
                        isError: _showNameError,
                        maxLength: 40,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildMaterialField(
                              controller: _amountCtrl,
                              label: 'amount'.tr(),
                              colors: colors,
                              isNumber: true,
                              isError: _showAmountError,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSelectorField(
                              controller: _currencyCtrl,
                              label: 'currency'.tr(),
                              colors: colors,
                              onTap: _openCurrencyPicker,
                              // 👇 Застосовуємо наші нові кольори
                              customActiveColor: currencyAccentColor,
                              customTextColor: isCurrentBase
                                  ? currencyAccentColor
                                  : colors.textMain,
                              prefix: Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isCurrentBase
                                      ? currencyAccentColor.withValues(
                                          alpha: 0.15,
                                        )
                                      : colors.iconBg,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        currencySymbol.trim(),
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        strutStyle: const StrutStyle(
                                          fontSize: 14,
                                          height: 1.0,
                                          forceStrutHeight: true,
                                        ),
                                        textHeightBehavior:
                                            const TextHeightBehavior(
                                              applyHeightToFirstAscent: false,
                                              applyHeightToLastDescent: false,
                                            ),
                                        style: TextStyle(
                                          color: isCurrentBase
                                              ? currencyAccentColor
                                              : colors.textMain,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          height: 1.0,
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
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildSelectorField(
                              controller: _dateCtrl,
                              label: 'payment'.tr(),
                              colors: colors,
                              onTap: _pickDate,
                              suffix: Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Icon(
                                  Icons.calendar_month,
                                  color: colors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSelectorField(
                              controller: _periodicityCtrl,
                              label: 'period'.tr(),
                              colors: colors,
                              onTap: _openPeriodicityPicker,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildSelectorField(
                        controller: _accountCtrl,
                        label: 'write_off_from'.tr(),
                        colors: colors,
                        isError: _showAccountError,
                        onTap: () => _openCategoryPicker(
                          CategoryType.account,
                          _accountCtrl,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildSelectorField(
                        controller: _expenseCtrl,
                        label: 'expense_category'.tr(),
                        colors: colors,
                        isError: _showExpenseError,
                        onTap: () => _openCategoryPicker(
                          CategoryType.expense,
                          _expenseCtrl,
                        ),
                      ),
                      const SizedBox(height: 24),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'auto_pay'.tr(),
                          style: TextStyle(
                            color: colors.textMain,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        value: _isAutoPay,
                        activeThumbColor: colors.accent,
                        onChanged: (val) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => _isAutoPay = val);
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
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
