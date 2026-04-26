import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinanceCompetence {
  const FinanceCompetence({
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  FinanceCompetence previous() {
    if (month == 1) return FinanceCompetence(year: year - 1, month: 12);
    return FinanceCompetence(year: year, month: month - 1);
  }

  FinanceCompetence next() {
    if (month == 12) return FinanceCompetence(year: year + 1, month: 1);
    return FinanceCompetence(year: year, month: month + 1);
  }
}

class FinanceFiltersController extends StateNotifier<FinanceCompetence> {
  FinanceFiltersController()
      : super(
          FinanceCompetence(
            year: DateTime.now().year,
            month: DateTime.now().month,
          ),
        );

  void goPreviousMonth() => state = state.previous();
  void goNextMonth() => state = state.next();

  void setCompetence({required int year, required int month}) {
    if (month < 1 || month > 12) return;
    state = FinanceCompetence(year: year, month: month);
  }
}

final financeFiltersProvider =
    StateNotifierProvider<FinanceFiltersController, FinanceCompetence>(
  (ref) => FinanceFiltersController(),
);
