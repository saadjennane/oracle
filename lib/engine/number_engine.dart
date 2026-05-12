/// Engine for Number preset calculations (Rainman, Birthday, Today).

enum NumberMode {
  rainman,
  birthday,
  today;

  String toJson() => name;

  static NumberMode fromJson(String? value) {
    if (value == null) return NumberMode.rainman;
    return NumberMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NumberMode.rainman,
    );
  }

  String displayName({bool french = true}) {
    switch (this) {
      case NumberMode.rainman:
        return 'Rainman';
      case NumberMode.birthday:
        return french ? 'Anniversaire' : 'Birthday';
      case NumberMode.today:
        return french ? 'Aujourd\'hui' : 'Today';
    }
  }
}

class NumberEngine {
  /// Count operands in a formula (each _ or group of X's = 1 operand to input)
  static int countOperands(String formula) {
    return RegExp(r'_|X+').allMatches(formula).length;
  }

  /// Calculate Rainman result from formula and values.
  /// Substitutes _ and XX patterns with values, then evaluates the expression.
  /// Supports mixed formulas like "12345 - XXXX" or "XX * XX + 42"
  static double calculateRainman(String formula, List<double> values) {
    // Substitute operands with values
    var expression = formula.trim();
    int valueIndex = 0;
    expression = expression.replaceAllMapped(RegExp(r'_|X+'), (match) {
      if (valueIndex < values.length) {
        final val = values[valueIndex++];
        return val == val.toInt() ? val.toInt().toString() : val.toString();
      }
      return '0';
    });

    // Evaluate the expression with operator precedence
    return _evaluateExpression(expression);
  }

  /// Evaluate a simple arithmetic expression string with +, -, *, /.
  /// Respects operator precedence (* and / before + and -).
  ///
  /// Returns `double.nan` when the expression is malformed (no numbers,
  /// dangling operator, or mismatched operands) so the caller can show an
  /// explicit error instead of treating it as a silent zero. Division by
  /// zero returns `double.infinity` (Dart default) — also distinguishable
  /// from a real numeric result.
  static double _evaluateExpression(String expr) {
    // Tokenize: extract numbers and operators
    final tokens = <String>[];
    final regex = RegExp(r'(\d+\.?\d*)|([+\-*/])');
    for (final match in regex.allMatches(expr.replaceAll(' ', ''))) {
      tokens.add(match.group(0)!);
    }

    // Parse into nums and ops
    final nums = <double>[];
    final ops = <String>[];
    for (final token in tokens) {
      final num = double.tryParse(token);
      if (num != null) {
        nums.add(num);
      } else {
        ops.add(token);
      }
    }

    // Empty / malformed → NaN so the UI surfaces an error.
    if (nums.isEmpty) return double.nan;
    if (ops.length != nums.length - 1) return double.nan;

    // First pass: handle * and /
    int i = 0;
    while (i < ops.length) {
      if (ops[i] == '*' || ops[i] == '/') {
        if (ops[i] == '*') {
          nums[i] = nums[i] * nums[i + 1];
        } else {
          // Let division by zero surface as Infinity rather than
          // collapsing silently to 0 — caller treats it as Error.
          nums[i] = nums[i] / nums[i + 1];
        }
        nums.removeAt(i + 1);
        ops.removeAt(i);
      } else {
        i++;
      }
    }

    // Second pass: handle + and -
    double result = nums[0];
    for (int j = 0; j < ops.length; j++) {
      if (ops[j] == '+') {
        result += nums[j + 1];
      } else if (ops[j] == '-') {
        result -= nums[j + 1];
      }
    }

    return result;
  }

  /// Calculate Birthday result
  /// Returns (dayOfWeek, daysSince)
  static BirthdayResult calculateBirthday(int day, int month, int year) {
    final birthDate = DateTime(year, month, day);
    final now = DateTime.now();
    final diff = now.difference(birthDate).inDays;

    const daysFR = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const daysEN = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return BirthdayResult(
      dayOfWeekFR: daysFR[birthDate.weekday - 1],
      dayOfWeekEN: daysEN[birthDate.weekday - 1],
      daysSince: diff,
    );
  }

  /// Format today's date as a number
  /// includeTime: false → 40426 (4 avril 2026)
  /// includeTime: true → 404261638 (4 avril 2026, 16h38)
  static String formatTodayDate({
    bool includeTime = false,
    int minutesOffset = 0,
  }) {
    var now = DateTime.now();
    if (minutesOffset != 0) {
      now = now.add(Duration(minutes: minutesOffset));
    }

    final day = now.day;
    final month = now.month;
    final year = now.year % 100; // 2026 → 26

    if (includeTime) {
      final hour = now.hour;
      final minute = now.minute;
      return '$day${month.toString().padLeft(2, '0')}$year$hour${minute.toString().padLeft(2, '0')}';
    } else {
      return '$day${month.toString().padLeft(2, '0')}$year';
    }
  }

  /// Calculate Today complement
  /// date_formatted - spectator_number = complement
  static int calculateTodayComplement({
    required int spectatorNumber,
    bool includeTime = false,
    int minutesOffset = 0,
  }) {
    final dateStr = formatTodayDate(includeTime: includeTime, minutesOffset: minutesOffset);
    final dateNumber = int.parse(dateStr);
    return dateNumber - spectatorNumber;
  }

  /// Extract numbers from a text (for audio parsing)
  static List<int> extractNumbers(String text) {
    final regex = RegExp(r'\d+');
    return regex.allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
  }

  /// Try to parse a date from text (DD/MM/YYYY or DD MM YYYY patterns)
  static DateTime? parseDateFromText(String text) {
    // Try DD/MM/YYYY
    final slashPattern = RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})');
    final slashMatch = slashPattern.firstMatch(text);
    if (slashMatch != null) {
      final day = int.parse(slashMatch.group(1)!);
      final month = int.parse(slashMatch.group(2)!);
      var year = int.parse(slashMatch.group(3)!);
      if (year < 100) year += 1900;
      if (year < 1900) year += 100;
      return DateTime(year, month, day);
    }

    // Try extracting 3 numbers as day, month, year
    final numbers = extractNumbers(text);
    if (numbers.length >= 3) {
      final day = numbers[0];
      final month = numbers[1];
      var year = numbers[2];
      if (year < 100) year += 1900;
      if (year < 1900) year += 100;
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }
}

class BirthdayResult {
  final String dayOfWeekFR;
  final String dayOfWeekEN;
  final int daysSince;

  BirthdayResult({
    required this.dayOfWeekFR,
    required this.dayOfWeekEN,
    required this.daysSince,
  });
}
