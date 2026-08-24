import 'category.dart';

class ReportSummary {
  final String periodFrom;
  final String periodTo;
  final int income;
  final int expense;
  final int net;

  ReportSummary({
    required this.periodFrom,
    required this.periodTo,
    required this.income,
    required this.expense,
    required this.net,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    return ReportSummary(
      periodFrom: period['from'] as String,
      periodTo: period['to'] as String,
      income: json['income'] as int,
      expense: json['expense'] as int,
      net: json['net'] as int,
    );
  }

  String get formattedIncome {
    return 'Rp${income.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  String get formattedExpense {
    return 'Rp${expense.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  String get formattedNet {
    return 'Rp${net.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }
}

class CategoryBreakdown {
  final Category category;
  final int total;
  final int count;

  CategoryBreakdown({
    required this.category,
    required this.total,
    required this.count,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      category: Category.fromJson(json['category'] as Map<String, dynamic>),
      total: json['total'] as int,
      count: json['count'] as int,
    );
  }

  String get formattedTotal {
    return 'Rp${total.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }
}

class ReportBreakdown {
  final String periodFrom;
  final String periodTo;
  final List<CategoryBreakdown> expenseByCategory;
  final List<CategoryBreakdown> incomeByCategory;

  ReportBreakdown({
    required this.periodFrom,
    required this.periodTo,
    required this.expenseByCategory,
    required this.incomeByCategory,
  });

  factory ReportBreakdown.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    return ReportBreakdown(
      periodFrom: period['from'] as String,
      periodTo: period['to'] as String,
      expenseByCategory: (json['expense_by_category'] as List<dynamic>?)
              ?.map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      incomeByCategory: (json['income_by_category'] as List<dynamic>?)
              ?.map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
