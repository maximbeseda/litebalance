import 'package:flutter/material.dart';

import '../database/app_database.dart';

class ImportRecognizer {
  // ==========================================
  // 1. СЛОВНИКИ ДЛЯ РОЗПІЗНАВАННЯ ІКОНОК
  // ==========================================
  static const Map<int, List<String>> _iconKeywords = {
    0xe532: [
      // Icons.restaurant
      'кафе', 'ресторан', 'їжа', 'харчування', 'food', 'cafe', 'dining',
      'meal', 'lunch', 'dinner', 'restaurant', 'essen', 'kaffee',
      'nourriture', 'repas', 'comida', 'cena', 'pranzo',
    ],
    0xe1d7: [
      // Icons.directions_car
      'авто', 'таксі', 'транспорт', 'пальне', 'бензин', 'car', 'taxi',
      'uber', 'lyft', 'gas', 'fuel', 'transit', 'transport', 'benzin',
      'tanken', 'auto', 'voiture', 'essence', 'coche', 'gasolina',
    ],
    0xe4a1: [
      // Icons.payments
      'зарплата', 'премія', 'аванс', 'бонус', 'salary', 'income', 'wage',
      'bonus', 'paycheck', 'gehalt', 'lohn', 'einkommen', 'salaire',
      'paie', 'salario', 'sueldo', 'ingreso',
    ],
    0xe5c3: [
      // Icons.shopping_basket
      'продукти', 'маркет', 'сільпо', 'атб', 'ашан', 'магазин', 'покупки',
      'groceries', 'shop', 'store', 'market', 'supermarket', 'lebensmittel',
      'supermarkt', 'einkaufen', 'courses', 'supermarché', 'compras',
      'supermercado',
    ],
    0xe3ed: [
      // Icons.medical_services
      'здоров', 'аптека', 'лікар', 'медицина', 'health', 'doctor',
      'pharmacy', 'medicine', 'hospital', 'gesundheit', 'arzt',
      'apotheke', 'medizin', 'santé', 'médecin', 'pharmacie',
      'salud', 'médico', 'farmacia',
    ],
    0xe041: [
      // Icons.account_balance_wallet
      'картка', 'банк', 'приват', 'моно', 'ощад', 'готівка', 'гаманець',
      'wallet', 'cash', 'card', 'bank', 'account', 'atm', 'bargeld',
      'karte', 'konto', 'brieftasche', 'espèces', 'carte', 'banque',
      'efectivo', 'tarjeta', 'banco',
    ],
    0xe314: [
      // Icons.home
      'комунал', 'дім', 'квартира', 'оренда', 'ремонт', 'home', 'rent',
      'house', 'utilities', 'bills', 'miete', 'haus', 'wohnung',
      'strom', 'maison', 'loyer', 'casa', 'alquiler', 'luz', 'agua',
    ],
  };

  static int getIconForName(String name) {
    final n = name.toLowerCase();
    for (var entry in _iconKeywords.entries) {
      if (entry.value.any((keyword) => n.contains(keyword))) {
        return entry.key;
      }
    }
    return Icons.category.codePoint;
  }

  // ==========================================
  // 2. СЛОВНИКИ ДЛЯ РОЗПІЗНАВАННЯ ТИПУ КАТЕГОРІЇ
  // ==========================================
  static const List<String> _incomeKeywords = [
    'зарплата',
    'дохід',
    'премія',
    'пай',
    'подарунок',
    'відсотки',
    'salary',
    'income',
    'bonus',
    'wage',
    'paycheck',
    'gift',
    'interest',
    'dividend',
    'gehalt',
    'lohn',
    'einkommen',
    'geschenk',
    'zinsen',
    'salaire',
    'revenu',
    'prime',
    'cadeau',
    'intérêts',
    'salario',
    'sueldo',
    'ingreso',
    'regalo',
    'intereses',
  ];

  static const List<String> _accountKeywords = [
    'картка',
    'банк',
    'приват',
    'моно',
    'ощад',
    'готівка',
    'usd',
    'eur',
    'gbp',
    'chf',
    'pln',
    'пф',
    'гаманець',
    'рахунок',
    'wallet',
    'card',
    'account',
    'cash',
    'bank',
    'bargeld',
    'konto',
    'karte',
    'espèces',
    'carte',
    'banque',
    'efectivo',
    'tarjeta',
    'banco',
  ];

  static const List<String> _expenseKeywords = [
    'продукти',
    'кафе',
    'транспорт',
    'ремонт',
    'їжа',
    'комунал',
    'покупки',
    'одяг',
    'food',
    'expense',
    'rent',
    'groceries',
    'shopping',
    'clothes',
    'bills',
    'utilities',
    'spend',
    'essen',
    'einkaufen',
    'miete',
    'kleidung',
    'rechnungen',
    'ausgabe',
    'courses',
    'loyer',
    'vêtements',
    'factures',
    'dépense',
    'comida',
    'compras',
    'alquiler',
    'ropa',
    'facturas',
    'gasto',
  ];

  static CategoryType guessType(String name, {required bool isFrom}) {
    final n = name.toLowerCase();

    if (_incomeKeywords.any((k) => n.contains(k))) {
      return CategoryType.income;
    }
    if (_accountKeywords.any((k) => n.contains(k))) {
      return CategoryType.account;
    }
    if (_expenseKeywords.any((k) => n.contains(k))) {
      return CategoryType.expense;
    }

    return isFrom ? CategoryType.account : CategoryType.expense;
  }

  // ==========================================
  // 3. РОЗПІЗНАВАННЯ НАЗВ КОЛОНОК З РІЗНИХ БАНКІВ
  // ==========================================
  static bool _containsAny(String header, List<String> keywords) {
    final h = header.toLowerCase();
    return keywords.any((k) => h.contains(k));
  }

  static bool isDate(String h) => _containsAny(h, [
    'дата',
    'date',
    'time',
    'день',
    'datum',
    'zeit',
    'temps',
    'fecha',
    'hora',
    'created',
  ]);

  static bool isFrom(String h) => _containsAny(h, [
    'звідки',
    'счет списания',
    'джерело',
    'від',
    'from',
    'source',
    'account',
    'wallet',
    'гаманець',
    'von',
    'quelle',
    'de',
    'desde',
    'origen',
    'счет',
    'рахунок',
    'sender',
  ]);

  static bool isTo(String h) => _containsAny(h, [
    'куди',
    'категорія',
    'счет зачисления',
    'категория',
    'to',
    'target',
    'category',
    'payee',
    'nach',
    'ziel',
    'kategorie',
    'à',
    'vers',
    'catégorie',
    'a',
    'hacia',
    'categoría',
    'destination',
    'beneficiary',
    'одержувач',
  ]);

  static bool isAmountFrom(String h) =>
      _containsAny(h, [
        'сума (звідки)',
        'amount (from)',
        'сумма списания',
        'сумма',
        'amount',
        'сума',
        'выход',
        'витрачено',
        'value',
        'sum',
        'withdrawal',
        'betrag',
        'summe',
        'ausgabe',
        'montant',
        'somme',
        'dépense',
        'importe',
        'cantidad',
        'suma',
        'gasto',
        'outflow',
      ]) &&
      !isAmountTo(h);

  static bool isCurrencyFrom(String h) =>
      _containsAny(h, [
        'валюта (звідки)',
        'валюта списания',
        'currency (from)',
        'валюта',
        'currency',
        'währung',
        'devise',
        'moneda',
      ]) &&
      !isCurrencyTo(h);

  static bool isAmountTo(String h) => _containsAny(h, [
    'сума (куди)',
    'amount (to)',
    'сумма (в валюте',
    'сумма в др',
    'сумма зачисления',
    'приход',
    'отримано',
    'deposit',
    'inflow',
    'target amount',
    'einnahme',
    'einzahlung',
    'dépôt',
    'revenu',
    'depósito',
    'ingreso',
    'credit',
  ]);

  static bool isCurrencyTo(String h) => _containsAny(h, [
    'валюта (куди)',
    'currency (to)',
    'валюта операции',
    'др.валюта',
    'валюта зачисления',
    'target currency',
    'zielwährung',
    'devise cible',
    'moneda de destino',
  ]);

  static bool isNote(String h) => _containsAny(h, [
    'коментар',
    'заметка',
    'comment',
    'описание',
    'note',
    'desc',
    'description',
    'memo',
    'notiz',
    'kommentar',
    'beschreibung',
    'commentaire',
    'nota',
    'comentario',
    'descripción',
    'примітка',
    'labels',
    'tags',
    'теги',
  ]);

  // ==========================================
  // 4. ПАРСИНГ ДАНИХ (СУМИ, ДАТИ, ВАЛЮТИ)
  // ==========================================

  /// Очищає рядок від сміття та повертає суму в копійках/центах
  static int parseAmount(String v) {
    try {
      String clean = v.replaceAll(RegExp(r'[^\d\.,-]'), '');
      if (clean.isEmpty) {
        return 0;
      }

      if (clean.contains('.') && clean.contains(',')) {
        final lastDot = clean.lastIndexOf('.');
        final lastComma = clean.lastIndexOf(',');
        if (lastDot > lastComma) {
          clean = clean.replaceAll(',', '');
        } else {
          clean = clean.replaceAll('.', '').replaceAll(',', '.');
        }
      } else if (clean.contains(',')) {
        final parts = clean.split(',');
        if (parts.length == 2 && parts[1].length != 3) {
          clean = clean.replaceAll(',', '.');
        } else {
          clean = clean.replaceAll(',', '');
        }
      }

      final value = double.parse(clean);
      return (value.abs() * 100).round();
    } catch (_) {
      return 0;
    }
  }

  /// Намагається безпечно розпарсити будь-яку дату
  static DateTime? parseDate(String v) {
    try {
      final clean = v.replaceAll('"', '').trim();
      final datePart = clean.split('T')[0].split(' ')[0];

      final parsedIso = DateTime.tryParse(clean);
      if (parsedIso != null) {
        return parsedIso;
      }

      final parts = datePart.split(RegExp(r'[\./-]'));
      if (parts.length == 3) {
        final p0 = int.parse(parts[0]);
        final p1 = int.parse(parts[1]);
        final p2 = int.parse(parts[2]);

        int year, month, day;

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

  /// Нормалізує валюту, підтримуючи 27+ популярних валют
  static String normalizeCurrency(String v, String defaultCurrency) {
    final clean = v.toLowerCase().replaceAll(RegExp(r'[\s\d\.,\-]'), '');
    if (clean.isEmpty) {
      return defaultCurrency;
    }

    if (['cad', 'c\$', 'канад'].any((k) => clean.contains(k))) {
      return 'CAD';
    }
    if (['aud', 'a\$', 'австрал'].any((k) => clean.contains(k))) {
      return 'AUD';
    }
    if (['nzd', 'nz\$', 'новозел'].any((k) => clean.contains(k))) {
      return 'NZD';
    }
    if (['mxn', 'mex\$', 'песо', 'peso'].any((k) => clean.contains(k))) {
      return 'MXN';
    }
    if (['brl', 'r\$', 'реал', 'real'].any((k) => clean.contains(k))) {
      return 'BRL';
    }

    if (['uah', 'грн', 'грив', '₴'].any((k) => clean.contains(k))) {
      return 'UAH';
    }
    if (['usd', 'дол', 'dol', '\$'].any((k) => clean.contains(k))) {
      return 'USD';
    }
    if (['eur', 'євро', 'евро', 'euro', '€'].any((k) => clean.contains(k))) {
      return 'EUR';
    }
    if (['gbp', 'фунт', 'pound', '£'].any((k) => clean.contains(k))) {
      return 'GBP';
    }
    if (['chf', 'франк', 'frank', '₣'].any((k) => clean.contains(k))) {
      return 'CHF';
    }
    if (['pln', 'zl', 'zł', 'злот', 'zloty'].any((k) => clean.contains(k))) {
      return 'PLN';
    }
    if (['czk', 'kč', 'kc', 'крон'].any((k) => clean.contains(k))) {
      return 'CZK';
    }
    if (['huf', 'ft', 'форинт', 'forint'].any((k) => clean.contains(k))) {
      return 'HUF';
    }
    if (['bgn', 'лв', 'лев', 'lev'].any((k) => clean.contains(k))) {
      return 'BGN';
    }
    if (['try', '₺', 'лір', 'лир', 'lira'].any((k) => clean.contains(k))) {
      return 'TRY';
    }
    if (['gel', '₾', 'лари', 'lari'].any((k) => clean.contains(k))) {
      return 'GEL';
    }
    if (['kzt', '₸', 'тенге', 'tenge'].any((k) => clean.contains(k))) {
      return 'KZT';
    }
    if (['ils', '₪', 'шекел', 'shekel'].any((k) => clean.contains(k))) {
      return 'ILS';
    }
    if ([
      'aed',
      'دإ',
      'د.إ',
      'дирхам',
      'dirham',
    ].any((k) => clean.contains(k))) {
      return 'AED';
    }
    if (['inr', '₹', 'рупі', 'rupee'].any((k) => clean.contains(k))) {
      return 'INR';
    }

    if (['ron', 'romanian'].any((k) => clean.contains(k))) {
      return 'RON';
    }
    if (['mdl', 'moldov'].any((k) => clean.contains(k))) {
      return 'MDL';
    }
    if (['lei', 'лей'].any((k) => clean.contains(k))) {
      return 'RON';
    }

    if (['sek', 'swedish', 'швед'].any((k) => clean.contains(k))) {
      return 'SEK';
    }
    if (['nok', 'norwegian', 'норвег'].any((k) => clean.contains(k))) {
      return 'NOK';
    }
    if (['dkk', 'danish', 'дансь'].any((k) => clean.contains(k))) {
      return 'DKK';
    }
    if (clean.contains('kr')) {
      return 'SEK';
    }

    if (['jpy', 'йен', 'иен', 'yen'].any((k) => clean.contains(k))) {
      return 'JPY';
    }
    if (['cny', 'юань', 'yuan'].any((k) => clean.contains(k))) {
      return 'CNY';
    }
    if (clean.contains('¥')) {
      return 'JPY';
    }

    const supportedIsoCodes = [
      'UAH',
      'USD',
      'EUR',
      'GBP',
      'CHF',
      'JPY',
      'PLN',
      'CZK',
      'RON',
      'HUF',
      'BGN',
      'MDL',
      'SEK',
      'NOK',
      'DKK',
      'TRY',
      'GEL',
      'KZT',
      'ILS',
      'AED',
      'CNY',
      'INR',
      'CAD',
      'AUD',
      'NZD',
      'BRL',
      'MXN',
    ];

    for (final isoCode in supportedIsoCodes) {
      if (clean.contains(isoCode.toLowerCase())) {
        return isoCode;
      }
    }

    return defaultCurrency;
  }

  /// Очищає коментарі від зайвих лапок і пробілів
  static String cleanNote(String v) {
    return v.replaceAll('"', '').trim();
  }
}
