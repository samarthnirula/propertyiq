class CalcRequest {
  final double price;
  final double downPayment;
  final double interestRate;
  final double rent;
  final double monthlyExpenses;
  final double oneTimeExpenses;

  CalcRequest({
    required this.price,
    required this.downPayment,
    required this.interestRate,
    required this.rent,
    required this.monthlyExpenses,
    required this.oneTimeExpenses,
  });

  Map<String, dynamic> toJson() {
    return {
      "price": price,
      "down_payment": downPayment,
      "interest_rate": interestRate,
      "rent": rent,
      "monthly_expenses": monthlyExpenses,
      "one_time_expenses": oneTimeExpenses,
    };
  }
}

class CalcResponse {
  final double cashFlow;
  final double roi;
  final double capRate;
  final double mortgagePayment;
  final double? breakevenYears;

  CalcResponse({
    required this.cashFlow,
    required this.roi,
    required this.capRate,
    required this.mortgagePayment,
    required this.breakevenYears,
  });

  static double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory CalcResponse.fromJson(Map<String, dynamic> json) {
    return CalcResponse(
      cashFlow: _asDouble(
        json["cash_flow"] ??
            json["monthly_cash_flow"] ??
            json["cashFlow"],
      ),
      roi: _asDouble(
        json["roi"] ??
            json["cash_on_cash_return"],
      ),
      capRate: _asDouble(
        json["cap_rate"] ?? json["capRate"],
      ),
      mortgagePayment: _asDouble(
        json["mortgage_payment"] ??
            json["monthly_mortgage"] ??
            json["mortgagePayment"],
      ),
      breakevenYears: _asNullableDouble(
        json["breakeven_years"] ?? json["breakevenYears"],
      ),
    );
  }

  @override
  String toString() {
    return 'CalcResponse('
        'cashFlow: $cashFlow, '
        'roi: $roi, '
        'capRate: $capRate, '
        'mortgagePayment: $mortgagePayment, '
        'breakevenYears: $breakevenYears'
        ')';
  }
}