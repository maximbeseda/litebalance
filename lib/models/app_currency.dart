class AppCurrency {
  final String code; // Наприклад: "USD"
  final String symbol; // Наприклад: "$"

  const AppCurrency({required this.code, required this.symbol});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppCurrency &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  Map<String, dynamic> toJson() {
    return {'code': code, 'symbol': symbol};
  }

  factory AppCurrency.fromJson(Map<String, dynamic> json) {
    return AppCurrency(
      code: json['code'] as String,
      symbol: json['symbol'] as String,
    );
  }

  static const List<AppCurrency> supportedCurrencies = [
    AppCurrency(code: 'UAH', symbol: '₴'),
    AppCurrency(code: 'USD', symbol: '\$'),
    AppCurrency(code: 'EUR', symbol: '€'),
    AppCurrency(code: 'GBP', symbol: '£'),
    AppCurrency(code: 'CHF', symbol: '₣'),
    AppCurrency(code: 'JPY', symbol: '¥'),
    AppCurrency(code: 'PLN', symbol: 'zł'),
    AppCurrency(code: 'CZK', symbol: 'Kč'),
    AppCurrency(code: 'RON', symbol: 'lei'),
    AppCurrency(code: 'HUF', symbol: 'Ft'),
    AppCurrency(code: 'BGN', symbol: 'лв'),
    AppCurrency(code: 'MDL', symbol: 'L'),
    AppCurrency(code: 'SEK', symbol: 'kr'),
    AppCurrency(code: 'NOK', symbol: 'kr'),
    AppCurrency(code: 'DKK', symbol: 'kr'),
    AppCurrency(code: 'TRY', symbol: '₺'),
    AppCurrency(code: 'GEL', symbol: '₾'),
    AppCurrency(code: 'KZT', symbol: '₸'),
    AppCurrency(code: 'ILS', symbol: '₪'),
    AppCurrency(code: 'AED', symbol: 'د.إ'),
    AppCurrency(code: 'CNY', symbol: '¥'),
    AppCurrency(code: 'INR', symbol: '₹'),
    AppCurrency(code: 'CAD', symbol: 'C\$'),
    AppCurrency(code: 'AUD', symbol: 'A\$'),
    AppCurrency(code: 'NZD', symbol: 'NZ\$'),
    AppCurrency(code: 'BRL', symbol: 'R\$'),
    AppCurrency(code: 'MXN', symbol: 'Mex\$'),
    // Розширений світовий набір.
    AppCurrency(code: 'SGD', symbol: 'S\$'),
    AppCurrency(code: 'HKD', symbol: 'HK\$'),
    AppCurrency(code: 'KRW', symbol: '₩'),
    AppCurrency(code: 'THB', symbol: '฿'),
    AppCurrency(code: 'ZAR', symbol: 'R'),
    AppCurrency(code: 'SAR', symbol: 'SR'),
    AppCurrency(code: 'QAR', symbol: 'QR'),
    AppCurrency(code: 'KWD', symbol: 'KD'),
    AppCurrency(code: 'IDR', symbol: 'Rp'),
    AppCurrency(code: 'MYR', symbol: 'RM'),
    AppCurrency(code: 'PHP', symbol: '₱'),
    AppCurrency(code: 'VND', symbol: '₫'),
    AppCurrency(code: 'TWD', symbol: 'NT\$'),
    AppCurrency(code: 'ISK', symbol: 'kr'),
    AppCurrency(code: 'RSD', symbol: 'дин.'),
    AppCurrency(code: 'ARS', symbol: '\$'),
    AppCurrency(code: 'CLP', symbol: '\$'),
    AppCurrency(code: 'COP', symbol: '\$'),
    AppCurrency(code: 'PEN', symbol: 'S/'),
    AppCurrency(code: 'EGP', symbol: 'E£'),
    AppCurrency(code: 'NGN', symbol: '₦'),
    AppCurrency(code: 'MAD', symbol: 'DH'),
    // Розширений набір (додано за відгуками тестерів). Без RUB/BYN і без
    // 3-знакових валют. Усі підтримуються Fawazahmed currency-api.
    AppCurrency(code: 'ALL', symbol: 'L'),
    AppCurrency(code: 'MKD', symbol: 'den'),
    AppCurrency(code: 'BAM', symbol: 'KM'),
    AppCurrency(code: 'LBP', symbol: 'LL'),
    AppCurrency(code: 'YER', symbol: 'YR'),
    AppCurrency(code: 'AZN', symbol: '₼'),
    AppCurrency(code: 'AMD', symbol: '֏'),
    AppCurrency(code: 'UZS', symbol: 'soʻm'),
    AppCurrency(code: 'KGS', symbol: 'som'),
    AppCurrency(code: 'TJS', symbol: 'SM'),
    AppCurrency(code: 'PKR', symbol: '₨'),
    AppCurrency(code: 'BDT', symbol: '৳'),
    AppCurrency(code: 'LKR', symbol: 'Rs'),
    AppCurrency(code: 'NPR', symbol: 'रू'),
    AppCurrency(code: 'AFN', symbol: '؋'),
    AppCurrency(code: 'MMK', symbol: 'Ks'),
    AppCurrency(code: 'KHR', symbol: '៛'),
    AppCurrency(code: 'LAK', symbol: '₭'),
    AppCurrency(code: 'MNT', symbol: '₮'),
    AppCurrency(code: 'KES', symbol: 'KSh'),
    AppCurrency(code: 'GHS', symbol: '₵'),
    AppCurrency(code: 'TZS', symbol: 'TSh'),
    AppCurrency(code: 'UGX', symbol: 'USh'),
    AppCurrency(code: 'DZD', symbol: 'DA'),
    AppCurrency(code: 'ETB', symbol: 'Br'),
    AppCurrency(code: 'ZMW', symbol: 'ZK'),
    AppCurrency(code: 'BWP', symbol: 'P'),
    AppCurrency(code: 'NAD', symbol: 'N\$'),
    AppCurrency(code: 'MZN', symbol: 'MT'),
    AppCurrency(code: 'AOA', symbol: 'Kz'),
    AppCurrency(code: 'CDF', symbol: 'FC'),
    AppCurrency(code: 'RWF', symbol: 'FRw'),
    AppCurrency(code: 'XOF', symbol: 'CFA'),
    AppCurrency(code: 'XAF', symbol: 'FCFA'),
    AppCurrency(code: 'BOB', symbol: 'Bs'),
    AppCurrency(code: 'UYU', symbol: '\$U'),
    AppCurrency(code: 'GTQ', symbol: 'Q'),
    AppCurrency(code: 'DOP', symbol: 'RD\$'),
    AppCurrency(code: 'CRC', symbol: '₡'),
    AppCurrency(code: 'HNL', symbol: 'L'),
    AppCurrency(code: 'NIO', symbol: 'C\$'),
    AppCurrency(code: 'JMD', symbol: 'J\$'),
    AppCurrency(code: 'PYG', symbol: '₲'),
    AppCurrency(code: 'PGK', symbol: 'K'),
  ];

  /// Популярні валюти + гривня, що завжди йдуть зверху списків (у цьому порядку).
  static const List<String> topCodes = ['UAH', 'USD', 'EUR', 'GBP', 'PLN'];

  /// Валюти без дробової частини. JPY/KRW/VND/CLP/ISK мають 0 знаків за ISO 4217;
  /// HUF за ISO = 2, але де-факто без філлерів (скасовані 1999) — тож теж 0.
  static const Set<String> zeroDecimalCodes = {
    'JPY',
    'KRW',
    'VND',
    'CLP',
    'ISK',
    'HUF',
    // Нові безкопійчані (0 знаків за ISO 4217).
    'UGX',
    'RWF',
    'XOF',
    'XAF',
    'PYG',
  };

  /// Кількість знаків після коми для валюти (0 для «безкопійчаних», інакше 2).
  static int decimals(String code) =>
      zeroDecimalCodes.contains(code.toUpperCase()) ? 0 : 2;

  // 👇 ОПТИМІЗАЦІЯ: Кеш для миттєвого доступу (O(1) замість O(N))
  static final Map<String, AppCurrency> _currencyCache = {
    for (var c in supportedCurrencies) c.code: c,
  };

  static AppCurrency fromCode(String code) {
    // Миттєво дістаємо з Map, а не перебираємо список
    return _currencyCache[code.toUpperCase()] ?? supportedCurrencies.first;
  }

  /// Єдиний порядок валют для всіх списків/боттомшитів:
  /// спершу [topCodes] (популярні + гривня), далі решта за алфавітом коду.
  /// [pin] — код, який треба підняти в самий верх (напр. базова валюта).
  static List<AppCurrency> ordered({String? pin}) {
    final top = <AppCurrency>[
      for (final code in topCodes)
        if (_currencyCache[code] != null) _currencyCache[code]!,
    ];
    final topSet = topCodes.toSet();
    final rest =
        supportedCurrencies.where((c) => !topSet.contains(c.code)).toList()
          ..sort((a, b) => a.code.compareTo(b.code));

    final result = [...top, ...rest];

    if (pin != null) {
      final pinned = _currencyCache[pin];
      if (pinned != null) {
        result.removeWhere((c) => c.code == pin);
        result.insert(0, pinned);
      }
    }
    return result;
  }

  /// Те саме, що [ordered], але повертає лише коди.
  static List<String> orderedCodes({String? pin}) =>
      ordered(pin: pin).map((c) => c.code).toList();
}
