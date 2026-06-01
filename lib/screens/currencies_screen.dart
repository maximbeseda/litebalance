import 'package:flutter/material.dart';
// 👇 1. Замінили provider на flutter_riverpod
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

// 👇 2. Імпортуємо наш хаб провайдерів
import '../providers/all_providers.dart';
import '../models/app_currency.dart';
import '../utils/date_formatter.dart';
import '../theme/app_colors_extension.dart';
import '../widgets/common/app_empty_state.dart';

// 👇 3. Змінили StatefulWidget на ConsumerStatefulWidget
class CurrenciesScreen extends ConsumerStatefulWidget {
  const CurrenciesScreen({super.key});

  @override
  ConsumerState<CurrenciesScreen> createState() => _CurrenciesScreenState();
}

// 👇 4. Змінили State на ConsumerState
class _CurrenciesScreenState extends ConsumerState<CurrenciesScreen> {
  bool _isUpdating = false;
  String? _errorMessage;

  String _formatRate(double val) {
    String formatted = val.toStringAsFixed(4);
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0*$'), '');
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }
    return formatted;
  }

  void _showAddCurrencyDialog(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    // 👇 Отримуємо стан налаштувань через ref.read
    final settingsState = ref.read(settingsProvider);

    final availableCurrencies = AppCurrency.supportedCurrencies
        .where((c) => !settingsState.selectedCurrencies.contains(c.code))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'add_currency'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (availableCurrencies.isEmpty)
              Expanded(
                child: AppEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  color: colors.income,
                  title: 'all_currencies_added'.tr(),
                  subtitle: 'all_currencies_added_hint'.tr(),
                  illustrationSize: 96,
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: availableCurrencies.length,
                  itemBuilder: (context, index) {
                    final currency = availableCurrencies[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.iconBg,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currency.symbol,
                              style: TextStyle(
                                color: colors.textMain,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        currency.code,
                        style: TextStyle(color: colors.textMain),
                      ),
                      onTap: () {
                        // 👇 Викликаємо метод через Notifier
                        ref
                            .read(settingsProvider.notifier)
                            .toggleSelectedCurrency(currency.code);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    // 👇 Викликаємо оновлення курсів через Notifier
    final success = await ref
        .read(settingsProvider.notifier)
        .forceUpdateRates();

    if (!mounted) return;

    setState(() {
      _isUpdating = false;
      if (!success) {
        _errorMessage = 'rates_update_error'.tr();
      }
    });

    if (!success) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      });
    }
  }

  // ВИПРАВЛЕНО: Замість var вказуємо точний тип SettingsState
  Widget _buildStatusRow(
    AppColorsExtension colors,
    SettingsState settingsState,
  ) {
    if (_errorMessage != null) {
      return Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: colors.expense),
          const SizedBox(width: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 12,
              color: colors.expense,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else if (_isUpdating) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'updating_rates'.tr(),
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      );
    } else if (settingsState.lastRatesUpdate != null) {
      return Row(
        children: [
          Icon(Icons.access_time, size: 14, color: colors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '${'last_update'.tr()}: ${DateFormatter.formatWithTime(settingsState.lastRatesUpdate!)}',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    // 👇 МАГІЯ RIVERPOD: Отримуємо реактивний стан і забуваємо про Consumer!
    final settingsState = ref.watch(settingsProvider);
    final baseCurrency = AppCurrency.fromCode(settingsState.baseCurrency);

    return Scaffold(
      backgroundColor: colors.bgGradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textMain),
        title: Text(
          'exchange_rates'.tr(),
          style: TextStyle(color: colors.textMain, fontWeight: FontWeight.bold),
        ),
        actions: [
          _isUpdating
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textMain,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _handleRefresh,
                ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              child: _buildStatusRow(colors, settingsState),
            ),
            Expanded(
              child: RefreshIndicator(
                color: colors.income,
                backgroundColor: colors.cardBg,
                onRefresh: _handleRefresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(16),
                  itemCount: settingsState.selectedCurrencies.length,
                  itemBuilder: (context, index) {
                    final code = settingsState.selectedCurrencies[index];
                    final currency = AppCurrency.fromCode(code);

                    if (code == settingsState.baseCurrency) {
                      return _buildCurrencyCard(
                        context,
                        currency: currency,
                        isBase: true,
                        rateText: 'base_currency'.tr(),
                        colors: colors,
                      );
                    }

                    final rate = settingsState.exchangeRates[code];
                    final rateText = rate != null
                        ? '1 ${currency.symbol} = ${_formatRate(1 / rate)} ${baseCurrency.symbol}'
                        : 'loading'.tr();

                    return _buildCurrencyCard(
                      context,
                      currency: currency,
                      isBase: false,
                      rateText: rateText,
                      colors: colors,
                      onDelete: () => ref
                          .read(settingsProvider.notifier)
                          .toggleSelectedCurrency(code),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.income,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddCurrencyDialog(context),
      ),
    );
  }

  Widget _buildCurrencyCard(
    BuildContext context, {
    required AppCurrency currency,
    required bool isBase,
    required String rateText,
    required AppColorsExtension colors,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: isBase
            ? Border.all(color: colors.income.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isBase
              ? colors.income.withValues(alpha: 0.2)
              : colors.iconBg,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currency.symbol,
                style: TextStyle(
                  color: isBase ? colors.income : colors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          currency.code,
          style: TextStyle(fontWeight: FontWeight.bold, color: colors.textMain),
        ),
        subtitle: Text(
          rateText,
          style: TextStyle(
            color: isBase ? colors.income : colors.textSecondary,
          ),
        ),
        trailing: !isBase && onDelete != null
            ? IconButton(
                icon: Icon(Icons.delete_outline, color: colors.expense),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
