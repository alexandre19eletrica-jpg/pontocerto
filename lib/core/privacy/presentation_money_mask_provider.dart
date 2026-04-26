import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPresentationHideMoney = 'presentation_hide_money_v1';

/// Oculta valores monetarios no Painel e Financeiro (apresentacoes, gravacoes).
class PresentationMoneyMaskNotifier extends Notifier<bool> {
  @override
  bool build() {
    Future<void>.microtask(_restore);
    return false;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_kPresentationHideMoney) ?? false;
    state = v;
  }

  Future<void> setHidden(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPresentationHideMoney, value);
  }

  Future<void> toggle() => setHidden(!state);
}

final presentationMoneyMaskProvider =
    NotifierProvider<PresentationMoneyMaskNotifier, bool>(
      PresentationMoneyMaskNotifier.new,
    );
