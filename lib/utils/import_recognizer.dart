import 'package:flutter/material.dart';

import '../database/app_database.dart';

class ImportRecognizer {
  // ==========================================
  // 1. СЛОВНИКИ ДЛЯ РОЗПІЗНАВАННЯ ІКОНОК
  // ==========================================
  // ВАЖЛИВО: коди мають збігатися з поточними Material Icons (як у пікері
  // app_constants.groupedIcons). Старі коди «поплили» після міграції шрифту
  // Material Icons (напр. 0xe4a1 тепер = pets, 0xe314 = history), тож тут —
  // актуальні. Порядок має значення: перший збіг перемагає, тому специфічні
  // концепти йдуть раніше за загальні.
  static const Map<int, List<String>> _iconKeywords = {
    0xe178: [
      // Icons.coffee — кафе
      'кафе', 'кава', 'cafe', 'café', 'kafe', 'coffee', 'kaffee', 'kawiarnia',
      'kahve', 'カフェ', 'コーヒー', 'कैफे', 'مقهى', 'قهوة', '咖啡',
    ],
    0xe532: [
      // Icons.restaurant — ресторани / їжа
      'ресторан', 'їжа', 'харчування', 'food', 'dining', 'meal', 'lunch',
      'dinner', 'restaurant', 'restaurante', 'restoran', 'restauracje',
      'essen', 'comida', 'repas',
      'レストラン', 'रेस्तरां', 'مطاعم', 'مطعم', '餐厅', '餐饮',
    ],
    0xe59c: [
      // Icons.shopping_cart — продукти
      'продукти', 'маркет', 'сільпо', 'атб', 'ашан', 'groceries', 'supermarket',
      'lebensmittel', 'courses', 'supermercado', 'mercado', 'market',
      'spożywcze', 'belanja harian', '食料品', 'किराना', 'البقالة', '日用杂货',
    ],
    0xe394: [
      // Icons.local_gas_station — пальне
      'пальне', 'бензин', 'fuel', 'gas', 'benzin', 'tanken', 'essence',
      'gasolina', 'combustível', 'paliwo', 'yakıt', 'bensin', 'ガソリン',
      'ईंधन', 'الوقود', '油费',
    ],
    0xe1d7: [
      // Icons.directions_car — транспорт
      'авто', 'таксі', 'транспорт', 'car', 'taxi', 'transit', 'transport',
      'transporte', 'ulaşım', 'transportasi', '交通', '交通費', 'परिवहन',
      'المواصلات', 'مواصلات',
    ],
    0xe11c: [
      // Icons.business_center — фріланс / підробіток
      'фріланс', 'freelanc', 'freiberuf', 'serbest', 'side project', 'nebenproje',
      'nebeneinkommen', '副業', '自由职业', 'फ्रीलांस', 'دخل حر', 'مشروع جانبي',
    ],
    0xe67f: [
      // Icons.trending_up — інвестиції / дивіденди
      'дивіденд', 'відсотки', 'dividend', 'dividen', 'dividende', 'dividendo',
      'dywidend', 'temettü', '配当', '股息', 'लाभांश', 'أرباح', 'invest',
    ],
    0xe482: [
      // Icons.payments — зарплата / дохід
      'зарплата', 'премія', 'дохід', 'salary', 'income', 'wage', 'paycheck',
      'gehalt', 'lohn', 'einkommen', 'salaire', 'revenu', 'salario', 'sueldo',
      'ingreso', 'salário', 'renda', 'pensja', 'maaş', 'gelir', 'gaji',
      '給料', '給与', '収入', '工资', '月薪', 'वेतन', 'आय', 'راتب', 'دخل',
    ],
    0xe13e: [
      // Icons.card_giftcard — подарунки
      'подарунк', 'gift', 'geschenk', 'cadeau', 'regalo', 'presente',
      'prezent', 'hediye', 'hadiah', '贈り物', 'उपहार', 'هدية', 'هدايا', '礼物',
    ],
    0xf079: [
      // Icons.electric_bolt — комуналка / рахунки
      'комунал', 'utilities', 'bills', 'nebenkosten', 'factures', 'facturas',
      'faturas', 'faturalar', 'rachunki', 'tagihan', '光熱費', 'बिल',
      'الفواتير', '水电费', 'strom',
    ],
    0xe318: [
      // Icons.home — оренда / житло
      'дім', 'квартира', 'оренда', 'home', 'rent', 'house', 'miete', 'loyer',
      'alquiler', 'aluguel', 'czynsz', 'kira', 'sewa', 'maison', 'casa',
      '家賃', 'किराया', 'الإيجار', 'إيجار', '房租', '房屋',
    ],
    0xe6e7: [
      // Icons.wifi — інтернет
      'інтернет', 'internet', 'wifi', 'インターネット', 'इंटरनेट', 'الإنترنت',
      'إنترنت', '网络', '宽带',
    ],
    0xe5c6: [
      // Icons.smartphone — мобільний звʼязок
      'мобільний', 'mobile', 'handy', 'móvil', 'celular', 'telefon', 'ponsel',
      '携帯', 'モバイル', 'मोबाइल', 'الهاتف', 'هاتف', '手机',
    ],
    0xe15d: [
      // Icons.checkroom — одяг
      'одяг', 'clothing', 'clothes', 'kleidung', 'vêtements', 'ropa', 'roupas',
      'odzież', 'giyim', 'pakaian', '衣類', 'कपड़े', 'الملابس', 'ملابس', '服装',
    ],
    0xe39a: [
      // Icons.local_mall — покупки (після продуктів, щоб pl «Zakupy
      // spożywcze» / id «Belanja harian» лишились продуктами)
      'покупки', 'shopping', 'einkaufen', 'achats', 'compras', 'zakupy',
      'alışveriş', 'belanja', '買い物', 'खरीदारी', 'التسوق', 'تسوق', '购物',
    ],
    0xe297: [
      // Icons.flight — подорожі
      'подорож', 'travel', 'trip', 'reisen', 'voyage', 'viaje', 'viagem',
      'viagens', 'viajes', 'podróże', 'seyahat', 'perjalanan', '旅行', 'यात्रा',
      'السفر', 'سفر',
    ],
    0xe654: [
      // Icons.theater_comedy — розваги
      'розваги', 'entertainment', 'unterhaltung', 'loisirs', 'ocio', 'lazer',
      'rozrywka', 'eğlence', 'hiburan', '娯楽', 'मनोरंजन', 'الترفيه', 'ترفيه',
      '娱乐',
    ],
    0xe618: [
      // Icons.subscriptions — підписки
      'підписк', 'subscription', 'abos', 'abonnement', 'suscripcion',
      'assinatura', 'subskrypcje', 'abonelik', 'langganan', 'サブスク',
      'सदस्यता', 'الاشتراكات', 'اشتراك', '订阅', 'netflix', 'spotify',
    ],
    0xe3d9: [
      // Icons.medication — аптека
      'аптека', 'pharmacy', 'apotheke', 'pharmacie', 'farmacia', 'farmácia',
      'apteka', 'eczane', 'apotek', '薬局', 'फार्मेसी', 'الصيدلية', 'صيدلية',
      '药店',
    ],
    0xe3d8: [
      // Icons.medical_services — здоровʼя
      'здоров', 'лікар', 'медицина', 'health', 'doctor', 'gesundheit', 'santé',
      'salud', 'saúde', 'zdrowie', 'sağlık', 'kesehatan', '健康', 'स्वास्थ्य',
      'الصحة', 'صحة',
    ],
    0xe553: [
      // Icons.savings — заощадження
      'ощад', 'заощадж', 'savings', 'sparkonto', 'épargne', 'ahorro',
      'poupança', 'oszczędno', 'tasarruf', 'tabungan', '貯金', 'बचत', 'توفير',
      'ادخار', '储蓄',
    ],
    0xe19f: [
      // Icons.credit_card — картка (перед банком, щоб «银行卡» → картка)
      'картка', 'card', 'karte', 'carte', 'tarjeta', 'cartão', 'karta', 'kart',
      'kartu', 'カード', 'कार्ड', 'بطاقة', '银行卡', '信用卡',
    ],
    0xe040: [
      // Icons.account_balance — банк
      'банк', 'приват', 'моно', 'bank', 'banque', 'banco', 'banka', 'bankası',
      '銀行', 'बैंक', 'بنك', '银行',
    ],
    0xe3f8: [
      // Icons.money — готівка
      'готівка', 'cash', 'bargeld', 'espèces', 'efectivo', 'dinheiro',
      'gotówka', 'nakit', 'tunai', '現金', 'नकद', 'نقد', '现金',
    ],
    0xe041: [
      // Icons.account_balance_wallet — загальний рахунок / гаманець
      'гаманець', 'рахунок', 'wallet', 'account', 'konto', 'rekening', 'hesap',
      'compte', 'cuenta', 'conta', '口座', 'खाता', 'حساب', '账户',
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
    'подарунк',
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
    // --- Розширене мовне покриття (авто-класифікація при імпорті) ---
    // pt
    'salário', 'renda', 'rendimento', 'presente', 'dividendo',
    // it
    'stipendio', 'reddito', 'entrata', 'dividendi',
    // nl
    'salaris', 'inkomen', 'cadeau',
    // pl
    'pensja', 'wynagrodzenie', 'dochód', 'wypłata', 'prezent',
    // cs / sk
    'mzda', 'příjem', 'dárek', 'príjem', 'darček',
    // ro
    'salariu', 'venit', 'cadou',
    // hu
    'fizetés', 'jövedelem', 'bér', 'ajándék',
    // el
    'μισθός', 'εισόδημα', 'δώρο',
    // bg
    'заплата', 'доход', 'приход', 'подарък',
    // sv / da
    'lön', 'inkomst', 'løn', 'indkomst', 'gave',
    // fi
    'palkka', 'tulot', 'lahja',
    // hr / bs / sr / mk
    'plaća', 'prihod', 'dohodak', 'poklon', 'plata', 'подарок',
    // tr / az
    'maaş', 'gelir', 'ücret', 'hediye', 'gəlir', 'hədiyyə',
    // zh
    '工资', '薪水', '收入', '礼物', '分红',
    // ja
    '給料', '給与', '収入', '賞与', 'ボーナス',
    // ko
    '급여', '월급', '소득', '수입', '보너스',
    // id / ms
    'gaji', 'pendapatan', 'upah', 'hadiah',
    // vi
    'lương', 'thu nhập', 'quà',
    // fil
    'sahod', 'suweldo', 'kita', 'regalo',
    // hi / ne
    'वेतन', 'आय', 'तनख्वाह', 'उपहार', 'तलब', 'आम्दानी',
    // bn
    'বেতন', 'আয়', 'উপহার',
    // th
    'เงินเดือน', 'รายได้', 'ของขวัญ',
    // sw
    'mshahara', 'mapato', 'zawadi',
    // sq
    'paga', 'të ardhura', 'dhuratë',
    // kk / mn
    'жалақы', 'табыс', 'сыйлық', 'цалин', 'орлого', 'бэлэг',
    // hy
    'աշխատավարձ', 'եկամուտ', 'նվեր',
    // ka
    'ხელფასი', 'შემოსავალი', 'საჩუქარი',
    // am
    'ደሞዝ', 'ገቢ', 'ስጦታ',
    // si
    'වැටුප', 'ආදායම', 'තෑග්ග',
    // my
    'လစာ', 'ဝင်ငွေ', 'လက်ဆောင်',
    // km
    'ប្រាក់ខែ', 'ចំណូល', 'អំណោយ',
    // lo
    'ເງິນເດືອນ', 'ລາຍຮັບ', 'ຂອງຂວັນ',
    // ar / fa / ur / he (RTL)
    'راتب', 'دخل', 'أجر', 'هدية', 'حقوق', 'درآمد', 'هدیه',
    'تنخواہ', 'آمدنی', 'تحفہ', 'משכורת', 'הכנסה', 'מתנה',
    // Додаткові форми (мн. / інші правописи), виявлені при валідації семплів.
    'dividen', 'dywidend', '贈り物', 'أرباح', 'هدايا',
    'freelance', 'фріланс', 'дивіденд',
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
    // --- Розширене мовне покриття (авто-класифікація при імпорті) ---
    // pt
    'dinheiro', 'cartão', 'conta', 'poupança', 'carteira',
    // it
    'contanti', 'carta', 'banca', 'conto', 'risparmi', 'portafoglio',
    // nl
    'contant', 'kaart', 'rekening', 'spaar', 'portemonnee',
    // pl
    'gotówka', 'karta', 'konto', 'oszczędności', 'portfel',
    // cs / sk
    'hotovost', 'banka', 'účet', 'spoření', 'peněženka', 'hotovosť',
    'úspory', 'peňaženka',
    // ro
    'numerar', 'card', 'bancă', 'cont', 'economii', 'portofel',
    // hu
    'készpénz', 'kártya', 'számla', 'megtakarítás',
    // el
    'μετρητά', 'κάρτα', 'τράπεζα', 'λογαριασμός', 'αποταμίευση',
    // bg
    'кеш', 'сметка', 'спестявания',
    // sv / da
    'kontanter', 'kort', 'sparande', 'plånbok', 'opsparing', 'pung',
    // fi (без 'tili' — збігається з "utilities")
    'käteinen', 'kortti', 'pankki', 'säästö', 'lompakko',
    // hr / bs / sr / mk
    'gotovina', 'kartica', 'račun', 'štednja', 'novčanik',
    'готовина', 'картица', 'рачун', 'штедња', 'новчаник',
    'картичка', 'штедење', 'паричник',
    // tr / az
    'nakit', 'kart', 'hesap', 'tasarruf', 'cüzdan', 'nağd', 'əmanət',
    // zh (без одиночного '卡')
    '现金', '银行卡', '信用卡', '账户', '储蓄', '钱包',
    // ja
    '現金', 'カード', '銀行', '口座', '貯金', '財布',
    // ko
    '현금', '카드', '은행', '계좌', '저축', '지갑',
    // id / ms
    'tunai', 'kartu', 'rekening', 'tabungan', 'dompet', 'akaun', 'simpanan',
    // vi
    'tiền mặt', 'thẻ', 'ngân hàng', 'tài khoản', 'tiết kiệm',
    // fil (без 'pera' — збігається з "opera")
    'kard', 'bangko', 'ipon', 'pitaka',
    // hi / ne
    'नकद', 'कार्ड', 'बैंक', 'खाता', 'बचत', 'बटुआ', 'नगद',
    // bn
    'নগদ', 'কার্ড', 'ব্যাংক', 'অ্যাকাউন্ট', 'সঞ্চয়',
    // th
    'เงินสด', 'บัตร', 'ธนาคาร', 'บัญชี', 'เงินออม',
    // sw
    'taslimu', 'kadi', 'benki', 'akaunti', 'akiba',
    // sq (без 'para' — збігається з "propaganda"/"para")
    'kartë', 'bankë', 'llogari', 'kursim', 'portofol',
    // kk / mn
    'қолма-қол', 'жинақ', 'әмиян', 'бэлэн', 'данс', 'хадгаламж', 'түрийвч',
    // hy
    'կանխիկ', 'քարտ', 'բանկ', 'հաշիվ', 'խնայողություն', 'դրամապանակ',
    // ka
    'ნაღდი', 'ბარათი', 'ბანკი', 'ანგარიში', 'დანაზოგი', 'საფულე',
    // am
    'ካርድ', 'ባንክ', 'ሒሳብ', 'ቁጠባ',
    // si
    'මුදල්', 'කාඩ්', 'බැංකු', 'ගිණුම', 'ඉතුරුම්',
    // my
    'ငွေသား', 'ကတ်', 'ဘဏ်', 'အကောင့်', 'စုငွေ',
    // km
    'សាច់ប្រាក់', 'កាត', 'ធនាគារ', 'គណនី', 'សន្សំ',
    // lo
    'ເງິນສົດ', 'ບັດ', 'ທະນາຄານ', 'ບັນຊີ', 'ເງິນຝາກ',
    // ar / fa / ur / he (RTL)
    'نقد', 'بطاقة', 'بنك', 'حساب', 'ادخار', 'محفظة', 'کارت', 'بانک',
    'پس‌انداز', 'کارڈ', 'بینک', 'اکاؤنٹ', 'بچت', 'بٹوہ',
    'מזומן', 'כרטיס', 'בנק', 'חשבון', 'חיסכון', 'ארנק',
    // Додаткові форми, виявлені при валідації семплів.
    'compte', 'épargne', 'cuenta', 'ahorro', '银行',
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
