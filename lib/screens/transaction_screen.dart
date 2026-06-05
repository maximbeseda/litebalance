import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/all_providers.dart';
import '../models/app_currency.dart';
import '../theme/app_colors_extension.dart';
import '../widgets/common/custom_numpad.dart';
import '../utils/calculator_helper.dart';
import '../utils/icon_helper.dart';
import '../widgets/common/date_strip_selector.dart';
import '../widgets/dialogs/premium_date_picker.dart';

class TransactionScreen extends ConsumerStatefulWidget {
  final Category source;
  final Category target;

  final int? initialAmount;
  final int? initialTargetAmount;
  final DateTime? initialDate;
  final String? initialNote;

  // 👇 ДОДАНО: Валюти оригінальної транзакції (щоб історія не ламалася при редагуванні)
  final String? initialSourceCurrency;
  final String? initialTargetCurrency;

  const TransactionScreen({
    super.key,
    required this.source,
    required this.target,
    this.initialAmount,
    this.initialTargetAmount,
    this.initialDate,
    this.initialNote,
    this.initialSourceCurrency,
    this.initialTargetCurrency,
  });

  @override
  ConsumerState<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  String _sourceExpression = '';
  String _sourceAmount = '0';

  String _targetExpression = '';
  String _targetAmount = '0';

  bool _isEditingTarget = false;

  bool _isRateLinked = true;
  String _lastEdited = 'source';

  bool _clearOnNextDigit = false;

  double _currentExchangeRate = 1.0;
  bool _isRateInitialized = false;

  bool _isLoadingRate = false;
  bool _isUsingFallbackRate = false;

  late DateTime _selectedDate;
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isCommentActive = false;

  Timer? _rateDebounceTimer;

  // 👇 ДОДАНО: Локальні змінні для валют
  late String _sourceCurrency;
  late String _targetCurrency;

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate ?? DateTime.now();

    // 👇 Беремо оригінальну валюту (якщо є) або поточну валюту категорії
    _sourceCurrency = widget.initialSourceCurrency ?? widget.source.currency;
    _targetCurrency = widget.initialTargetCurrency ?? widget.target.currency;

    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _sourceAmount = _formatAmount(widget.initialAmount!);
      _sourceExpression = _sourceAmount;
    }

    if (widget.initialTargetAmount != null && widget.initialTargetAmount! > 0) {
      _targetAmount = _formatAmount(widget.initialTargetAmount!);
      _targetExpression = _targetAmount;
      _isRateLinked = false;
    }

    if (widget.initialNote != null && widget.initialNote!.isNotEmpty) {
      _commentCtrl.text = widget.initialNote!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRateInitialized) {
      _isRateInitialized = true;
      _fetchRateForDate(_selectedDate);
    }
  }

  Future<void> _fetchRateForDate(DateTime date) async {
    // 👇 Використовуємо локальні валюти замість widget.source.currency
    if (_sourceCurrency == _targetCurrency) return;

    if (mounted) {
      setState(() {
        _isLoadingRate = true;
      });
    }

    final settingsState = ref.read(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final baseCurrency = settingsState.baseCurrency;

    double? sourceRate = await settingsNotifier.getRateForDate(
      _sourceCurrency,
      date,
    );
    double? targetRate = await settingsNotifier.getRateForDate(
      _targetCurrency,
      date,
    );

    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      sourceRate ??= settingsState.exchangeRates[_sourceCurrency];
      targetRate ??= settingsState.exchangeRates[_targetCurrency];
    }

    if (sourceRate == null ||
        targetRate == null ||
        sourceRate == 0 ||
        targetRate == 0) {
      _updateRatesAndUI(1.0, 1.0, baseCurrency, isFallback: true);
    } else {
      _updateRatesAndUI(
        sourceRate,
        targetRate,
        baseCurrency,
        isFallback: false,
      );
    }
  }

  void _updateRatesAndUI(
    double sourceRate,
    double targetRate,
    String baseCurrency, {
    required bool isFallback,
  }) {
    if (!mounted) return;

    setState(() {
      _isLoadingRate = false;

      if (isFallback) {
        _currentExchangeRate = 1.0;
        _isUsingFallbackRate = true;
        _isRateLinked = false;
      } else {
        if (_isUsingFallbackRate) {
          _isRateLinked = true;
        }
        _isUsingFallbackRate = false;

        final double rawRate = targetRate / sourceRate;
        if (rawRate >= 1.0) {
          _currentExchangeRate = double.parse(rawRate.toStringAsFixed(4));
        } else {
          final double inverted = sourceRate / targetRate;
          final double invertedRounded = double.parse(
            inverted.toStringAsFixed(4),
          );
          _currentExchangeRate = 1.0 / invertedRounded;
        }
      }
      _recalculateLinkedAmounts();
    });
  }

  void _recalculateLinkedAmounts() {
    if (!_isRateLinked || _isUsingFallbackRate) return;

    final double currentVal =
        double.tryParse(_isEditingTarget ? _targetAmount : _sourceAmount) ??
        0.0;

    if (!_isEditingTarget) {
      final double targetVal = currentVal * _currentExchangeRate;
      _targetAmount = _formatDoubleForInput(targetVal);
      _targetExpression = _targetAmount;
    } else {
      final double sourceVal = currentVal / _currentExchangeRate;
      _sourceAmount = _formatDoubleForInput(sourceVal);
      _sourceExpression = _sourceAmount;
    }
  }

  String get _activeExpression =>
      _isEditingTarget ? _targetExpression : _sourceExpression;
  set _activeExpression(String val) {
    if (_isEditingTarget) {
      _targetExpression = val;
    } else {
      _sourceExpression = val;
    }
  }

  void _setActiveAmount(String val) {
    if (_isEditingTarget) {
      _targetAmount = val;
    } else {
      _sourceAmount = val;
    }
  }

  String _formatAmount(int val) {
    if (val == 0) return '0';
    final double displayVal = val / 100.0;
    return _formatDoubleForInput(displayVal);
  }

  String _formatDoubleForInput(double val) {
    final String formatted = val.toStringAsFixed(2);
    if (formatted.endsWith('.00')) {
      return formatted.substring(0, formatted.length - 3);
    } else if (formatted.endsWith('0')) {
      return formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  String _formatRate(double val) {
    if (val == 0) return '0';
    String formatted = val.toStringAsFixed(4);
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0*$'), '');
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }
    return formatted;
  }

  @override
  void dispose() {
    _rateDebounceTimer?.cancel();
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _onNumpadPressed(String key) {
    setState(() {
      if (_isRateLinked) {
        if (_isEditingTarget && _lastEdited == 'source') {
          _isRateLinked = false;
        } else if (!_isEditingTarget && _lastEdited == 'target') {
          _isRateLinked = false;
        }
      }
      _lastEdited = _isEditingTarget ? 'target' : 'source';

      if (_clearOnNextDigit) {
        final bool isNumberOrDot =
            RegExp(r'^[0-9.]$').hasMatch(key) || key == '00';
        if (isNumberOrDot) {
          _activeExpression = '';
        }
        _clearOnNextDigit = false;
      }

      if (key == 'C') {
        _activeExpression = '';
        _setActiveAmount('0');
      } else if (key == '⌫') {
        if (_activeExpression.isNotEmpty) {
          _activeExpression = _activeExpression.substring(
            0,
            _activeExpression.length - 1,
          );
        }
      } else if (key == '=') {
        _activeExpression = CalculatorHelper.calculate(_activeExpression);
      } else if (key == '%') {
        if (_activeExpression.isEmpty ||
            CalculatorHelper.endsWithOperator(_activeExpression)) {
          return;
        }

        final String currentNumber = _activeExpression
            .split(RegExp(r'[+\-×÷]'))
            .last;
        if (currentNumber.isEmpty) return;

        final double percentValue = double.tryParse(currentNumber) ?? 0.0;
        final String baseExpression = _activeExpression.substring(
          0,
          _activeExpression.length - currentNumber.length,
        );

        if (baseExpression.isNotEmpty) {
          final String operator = baseExpression.substring(
            baseExpression.length - 1,
          );
          if (operator == '+' || operator == '-') {
            final String exprWithoutOp = baseExpression.substring(
              0,
              baseExpression.length - 1,
            );
            final double baseAmount =
                double.tryParse(CalculatorHelper.calculate(exprWithoutOp)) ??
                0.0;
            final double calculatedPercent = baseAmount * (percentValue / 100);

            final String formattedPercent =
                calculatedPercent == calculatedPercent.toInt()
                ? calculatedPercent.toInt().toString()
                : calculatedPercent.toStringAsFixed(2);
            _activeExpression = baseExpression + formattedPercent;
          } else if (operator == '×' || operator == '÷') {
            final double calc = percentValue / 100;
            final String formatted = calc == calc.toInt()
                ? calc.toInt().toString()
                : calc.toString();
            _activeExpression = baseExpression + formatted;
          }
        } else {
          final double calc = percentValue / 100;
          final String formatted = calc == calc.toInt()
              ? calc.toInt().toString()
              : calc.toString();
          _activeExpression = formatted;
        }
      } else if (['+', '-', '×', '÷'].contains(key)) {
        if (_activeExpression.isEmpty) {
          if (key == '-') _activeExpression = '-';
        } else if (CalculatorHelper.endsWithOperator(_activeExpression)) {
          _activeExpression =
              _activeExpression.substring(0, _activeExpression.length - 1) +
              key;
        } else {
          _activeExpression += key;
        }
      } else {
        final String currentNumber = _activeExpression
            .split(RegExp(r'[+\-×÷]'))
            .last;

        if (key == '.') {
          if (currentNumber.contains('.')) return;
          if (currentNumber.isEmpty) {
            _activeExpression += '0.';
          } else {
            _activeExpression += '.';
          }
        } else {
          if (currentNumber.contains('.')) {
            final int decimalPlaces = currentNumber.split('.').last.length;
            if (decimalPlaces >= 2) return;

            if (key == '00') {
              if (decimalPlaces == 0) {
                _activeExpression += '00';
              } else if (decimalPlaces == 1) {
                _activeExpression += '0';
              }
            } else {
              _activeExpression += key;
            }
          } else {
            if (currentNumber == '0') {
              if (key == '0' || key == '00') {
                return;
              } else {
                _activeExpression =
                    _activeExpression.substring(
                      0,
                      _activeExpression.length - 1,
                    ) +
                    key;
              }
            } else {
              if (currentNumber.length >= 12) return;

              if (key == '00') {
                if (currentNumber.length == 11) {
                  _activeExpression += '0';
                } else {
                  _activeExpression += '00';
                }
              } else {
                _activeExpression += key;
              }
            }
          }
        }
      }

      if (_activeExpression.isEmpty) {
        _setActiveAmount('0');
      } else if (_activeExpression == '-') {
        _setActiveAmount('-0');
      } else {
        String exprToCalc = _activeExpression;

        if (CalculatorHelper.endsWithOperator(exprToCalc)) {
          exprToCalc = exprToCalc.substring(0, exprToCalc.length - 1);
        }

        final String result = CalculatorHelper.calculate(exprToCalc);
        _setActiveAmount(result);
      }

      _recalculateLinkedAmounts();
    });
  }

  void _saveTransaction() {
    FocusManager.instance.primaryFocus?.unfocus();

    String cleanSource = _sourceExpression;
    if (CalculatorHelper.endsWithOperator(cleanSource)) {
      cleanSource = cleanSource.substring(0, cleanSource.length - 1);
    }

    String cleanTarget = _targetExpression;
    if (CalculatorHelper.endsWithOperator(cleanTarget)) {
      cleanTarget = cleanTarget.substring(0, cleanTarget.length - 1);
    }

    final double sourceDouble =
        double.tryParse(CalculatorHelper.calculate(cleanSource)) ?? 0.0;
    final double targetDouble =
        double.tryParse(CalculatorHelper.calculate(cleanTarget)) ?? 0.0;

    final int finalSourceAmount = (sourceDouble * 100).round();
    final int finalTargetAmount = (targetDouble * 100).round();

    Navigator.pop(context, {
      'amount': finalSourceAmount,
      // 👇 Використовуємо локальні валюти для перевірки
      'targetAmount': _sourceCurrency != _targetCurrency
          ? finalTargetAmount
          : null,
      'date': _selectedDate,
      'comment': _commentCtrl.text.trim(),
      // 👇 Передаємо назад фінальні валюти
      'currency': _sourceCurrency,
      'targetCurrency': _targetCurrency,
    });
  }

  void _handleDateChanged(DateTime newDate) {
    if (_selectedDate.year == newDate.year &&
        _selectedDate.month == newDate.month &&
        _selectedDate.day == newDate.day) {
      return;
    }

    _selectedDate = newDate;

    _rateDebounceTimer?.cancel();
    _rateDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchRateForDate(newDate);
      }
    });
  }

  Future<void> _handleCalendarTap() async {
    final DateTime? picked = await PremiumDatePicker.show(
      context: context,
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _fetchRateForDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return Scaffold(
      backgroundColor: colors.cardBg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          if (_isCommentActive) {
            setState(() {
              _isCommentActive = false;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    _buildHeader(colors),
                    Expanded(child: _buildAmountArea(colors)),
                    _buildToolbar(colors),
                    _buildSaveButton(),
                    _buildKeyboardArea(colors),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.close, color: colors.textSecondary, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(child: _buildMiniCategory(widget.source, colors)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: colors.textSecondary,
                    ),
                  ),
                  Expanded(child: _buildMiniCategory(widget.target, colors)),
                ],
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.check, color: colors.textMain, size: 26),
            onPressed: _saveTransaction,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCategory(Category cat, AppColorsExtension colors) {
    final Color catColor = Color(cat.bgColor);
    final Color iconColor = Color(cat.iconColor);
    final IconData iconData = IconHelper.getIcon(cat.icon);

    return Hero(
      tag: 'category_coin_${cat.id}',
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            return DefaultTextStyle(
              style: DefaultTextStyle.of(toHeroContext).style,
              child: toHeroContext.widget,
            );
          },
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: catColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  cat.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleAmountBox({
    required String amount,
    required String expression,
    required String symbol,
    required bool isActive,
    required VoidCallback onTap,
    required AppColorsExtension colors,
  }) {
    final bool hasMathOperators =
        expression.contains('+') ||
        expression.contains('×') ||
        expression.contains('÷') ||
        (expression.contains('-') && expression.lastIndexOf('-') > 0);

    final String displayMainAmount = hasMathOperators
        ? amount
        : (expression.isEmpty ? '0' : expression);

    String formatWithSpaces(String text) {
      return text.replaceAllMapped(RegExp(r'\d+(\.\d+)?'), (match) {
        final parts = match[0]!.split('.');
        final String intPart = parts[0].replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );
        return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
      });
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: formatWithSpaces(displayMainAmount)),
                    TextSpan(
                      text: ' $symbol',
                      style: TextStyle(
                        fontSize: isActive ? 36 : 28,
                        color: colors.textSecondary.withValues(
                          alpha: isActive ? 1.0 : 0.4,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: isActive ? 56 : 42,
                  fontWeight: FontWeight.w800,
                  color: colors.textMain.withValues(
                    alpha: isActive ? 1.0 : 0.4,
                  ),
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          if (expression != amount &&
              expression.isNotEmpty &&
              hasMathOperators &&
              isActive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatWithSpaces(expression),
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 22,
                    color: colors.textSecondary.withValues(
                      alpha: isActive ? 1.0 : 0.4,
                    ),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiddleExchangeRow(
    AppColorsExtension colors,
    String sourceSymbol,
    String targetSymbol,
  ) {
    final settingsState = ref.read(settingsProvider);
    String rateText = '';

    if (_isLoadingRate) {
      rateText = 'updating_rates'.tr();
    } else if (_isUsingFallbackRate) {
      rateText = "${"rate_unavailable".tr()}\n${"enter_manually".tr()}";
    } else if (_sourceCurrency == settingsState.baseCurrency &&
        _targetCurrency != settingsState.baseCurrency) {
      final double invertedRate = _currentExchangeRate > 0
          ? (1.0 / _currentExchangeRate)
          : 1.0;
      rateText = '1 $targetSymbol = ${_formatRate(invertedRate)} $sourceSymbol';
    } else {
      rateText =
          '1 $sourceSymbol = ${_formatRate(_currentExchangeRate)} $targetSymbol';
    }

    final Color activeColor = _isUsingFallbackRate
        ? colors.expense
        : colors.accent;
    final Color inactiveColor = colors.textSecondary.withValues(alpha: 0.4);
    Color currentColor = _isRateLinked ? activeColor : inactiveColor;

    if (_isUsingFallbackRate) currentColor = colors.expense;

    return GestureDetector(
      onTap: () {
        if (_isUsingFallbackRate || _isLoadingRate) return;
        if (!_isRateLinked) {
          setState(() {
            _isRateLinked = true;
            _recalculateLinkedAmounts();
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Row(
          children: [
            const Spacer(),
            if (_isLoadingRate)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.textSecondary,
                ),
              )
            else
              Icon(
                _isUsingFallbackRate ? Icons.error_outline : Icons.swap_vert,
                color: currentColor,
                size: 28,
              ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: currentColor,
                      fontSize: _isUsingFallbackRate ? 12 : 14,
                      fontWeight: _isRateLinked || _isUsingFallbackRate
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                    child: Text(
                      rateText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildAmountArea(AppColorsExtension colors) {
    // 👇 Використовуємо локальні валюти для відображення
    final bool isMultiCurrency = _sourceCurrency != _targetCurrency;
    final String sourceSymbol = AppCurrency.fromCode(_sourceCurrency).symbol;
    final String targetSymbol = AppCurrency.fromCode(_targetCurrency).symbol;

    if (!isMultiCurrency) {
      return Center(
        child: _buildSingleAmountBox(
          amount: _sourceAmount,
          expression: _sourceExpression,
          symbol: sourceSymbol,
          isActive: true,
          onTap: () {
            if (_isEditingTarget) {
              setState(() {
                _isEditingTarget = false;
                _clearOnNextDigit = true;
              });
            }
          },
          colors: colors,
        ),
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSingleAmountBox(
            amount: _sourceAmount,
            expression: _sourceExpression,
            symbol: sourceSymbol,
            isActive: !_isEditingTarget,
            onTap: () {
              if (_isEditingTarget) {
                setState(() {
                  _isEditingTarget = false;
                  _clearOnNextDigit = true;
                });
              }
            },
            colors: colors,
          ),
          _buildMiddleExchangeRow(colors, sourceSymbol, targetSymbol),
          _buildSingleAmountBox(
            amount: _targetAmount,
            expression: _targetExpression,
            symbol: targetSymbol,
            isActive: _isEditingTarget,
            onTap: () {
              if (!_isEditingTarget) {
                setState(() {
                  _isEditingTarget = true;
                  _clearOnNextDigit = true;
                });
              }
            },
            colors: colors,
          ),
        ],
      );
    }
  }

  Widget _buildToolbar(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: DateStripSelector(
                selectedDate: _selectedDate,
                onDateChanged: _handleDateChanged,
                onCalendarTap: _handleCalendarTap,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _isCommentActive = true;
              });
              _commentFocusNode.requestFocus();
            },
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: _isCommentActive || _commentCtrl.text.isNotEmpty
                    ? colors.iconBg
                    : colors.cardBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(Icons.notes, color: colors.textMain, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saveTransaction,
          child: Text(
            'done'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardArea(AppColorsExtension colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = BorderRadius.all(Radius.circular(8));
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : colors.textSecondary.withValues(alpha: 0.06);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: _isCommentActive
          ? Padding(
              key: const ValueKey('text_field'),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: TextField(
                focusNode: _commentFocusNode,
                controller: _commentCtrl,
                autofocus: true,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                cursorColor: colors.accent,
                onSubmitted: (_) {
                  _commentFocusNode.unfocus();
                  setState(() => _isCommentActive = false);
                },
                style: TextStyle(color: colors.textMain, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: fillColor,
                  isDense: true,
                  hintText: 'add_note'.tr(),
                  hintStyle: TextStyle(color: colors.textSecondary),
                  counterText: '',
                  prefixIcon: Icon(
                    Icons.notes_rounded,
                    color: colors.accent,
                    size: 22,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.check_circle,
                      color: colors.accent,
                      size: 28,
                    ),
                    onPressed: () {
                      _commentFocusNode.unfocus();
                      setState(() => _isCommentActive = false);
                    },
                  ),
                ),
              ),
            )
          : CustomNumpad(
              key: const ValueKey('numpad'),
              onKeyPressed: _onNumpadPressed,
            ),
    );
  }
}
