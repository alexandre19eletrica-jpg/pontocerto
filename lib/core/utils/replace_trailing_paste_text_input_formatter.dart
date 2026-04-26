import 'package:flutter/services.dart';

/// Se o utilizador cola um bloco grande no **fim** do texto (sem selecionar tudo o que ja existia),
/// o [TextField] poe a colagem no final e o conteudo antigo fica a frente, parecendo "duplicar".
/// Esta regra **substitui o campo inteiro** por apenas o trecho colado, quando a insercao
/// a partir do fim do que ja existia for grande o suficiente (ex.: codigo do Meta de novo).
class ReplaceTrailingBlockPasteTextInputFormatter extends TextInputFormatter {
  const ReplaceTrailingBlockPasteTextInputFormatter({
    this.minInsertLength = 60,
  });

  final int minInsertLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text.isEmpty) {
      return newValue;
    }
    if (newValue.text.length <= oldValue.text.length) {
      return newValue;
    }
    if (!newValue.text.startsWith(oldValue.text)) {
      // Colagem no meio ou selecao substituida: comportamento normal.
      return newValue;
    }
    final delta = newValue.text.length - oldValue.text.length;
    if (delta < minInsertLength) {
      return newValue;
    }
    final onlyPasted = newValue.text.substring(oldValue.text.length);
    return TextEditingValue(
      text: onlyPasted,
      selection: TextSelection.collapsed(offset: onlyPasted.length),
    );
  }
}
