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
    AppCurrency(code: 'ARS', symbol: 'AR\$'),
    AppCurrency(code: 'CLP', symbol: 'CL\$'),
    AppCurrency(code: 'COP', symbol: 'CO\$'),
    AppCurrency(code: 'PEN', symbol: 'S/'),
    AppCurrency(code: 'EGP', symbol: 'E£'),
    AppCurrency(code: 'NGN', symbol: '₦'),
    AppCurrency(code: 'MAD', symbol: 'DH'),
  ];

  /// Популярні валюти + гривня, що завжди йдуть зверху списків (у цьому порядку).
  static const List<String> topCodes = ['UAH', 'USD', 'EUR', 'GBP', 'PLN'];

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
