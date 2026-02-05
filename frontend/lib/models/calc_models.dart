class CalcRequest {
  final double price;
  final double downPayment;
  final double interestRate;
  final double rent;

  // NEW
  final double monthlyExpenses;   // recurring monthly operating expenses
  final double oneTimeExpenses;   // one-time upfront cost (closing/repairs/etc.)

  final int loanYears;

  CalcRequest({
    required this.price,
    required this.downPayment,
    required this.interestRate,
    required this.rent,
    required this.monthlyExpenses,
    required this.oneTimeExpenses,
    this.loanYears = 30,
  });

  Map<String, dynamic> toJson() => {
        "price": price,
        "down_payment": downPayment,
        "interest_rate": interestRate,
        "rent": rent,
        "monthly_expenses": monthlyExpenses,
        "expenses": oneTimeExpenses, // keep key name "expenses" for one-time cost
        "loan_years": loanYears,
      };
}

class CalcResponse {
  final double mortgagePayment;
  final double cashFlow;
  final double capRate;
  final double roi;
  final double? breakevenYears;

  CalcResponse({
    required this.mortgagePayment,
    required this.cashFlow,
    required this.capRate,
    required this.roi,
    required this.breakevenYears,
  });

  factory CalcResponse.fromJson(Map<String, dynamic> json) {
    return CalcResponse(
      mortgagePayment: (json["mortgage_payment"] as num).toDouble(),
      cashFlow: (json["cash_flow"] as num).toDouble(),
      capRate: (json["cap_rate"] as num).toDouble(),
      roi: (json["roi"] as num).toDouble(),
      breakevenYears: json["breakeven_years"] == null
          ? null
          : (json["breakeven_years"] as num).toDouble(),
    );
  }
}
