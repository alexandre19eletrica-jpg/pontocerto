import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/features/platform_admin/presentation/services/platform_admin_service.dart';

/// Painel governança: reunir e-mails da base e disparar mensagem simples (texto plano → HTML seguro).
class GovernanceBulkEmailPanel extends StatefulWidget {
  const GovernanceBulkEmailPanel({super.key, required this.service});

  final PlatformAdminService service;

  @override
  State<GovernanceBulkEmailPanel> createState() => _GovernanceBulkEmailPanelState();
}

class _GovernanceBulkEmailPanelState extends State<GovernanceBulkEmailPanel> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  List<GovernanceAudienceEmailRow> _rows = [];
  final Set<String> _excludedEmails = {};
  bool _pulling = false;
  bool _sending = false;

  static Widget _editableContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pullEmails() async {
    setState(() => _pulling = true);
    try {
      final rows = await widget.service.collectGovernanceAudienceEmails();
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
        _excludedEmails.clear();
      });
      context.showUserSuccess('${rows.length} e-mail(s) reunidos.');
    } catch (e, st) {
      debugPrint('collectGovernanceAudienceEmails: $e\n$st');
      if (mounted) {
        context.showUserError('Não foi possível puxar os e-mails.');
      }
    } finally {
      if (mounted) {
        setState(() => _pulling = false);
      }
    }
  }

  List<String> _recipientList() {
    final out = <String>[];
    for (final r in _rows) {
      final e = r.email.trim().toLowerCase();
      if (e.isEmpty || _excludedEmails.contains(e)) {
        continue;
      }
      out.add(e);
    }
    return out;
  }

  Future<void> _send() async {
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final recipients = _recipientList();

    if (subject.isEmpty) {
      context.showUserError('Informe o assunto.');
      return;
    }
    if (body.isEmpty) {
      context.showUserError('Cole ou digite o texto do e-mail.');
      return;
    }
    if (recipients.isEmpty) {
      context.showUserError('Nenhum destinatário selecionado (verifique exclusões).');
      return;
    }

    setState(() => _sending = true);
    try {
      const chunk = 40;
      var totalSent = 0;
      var totalFailed = 0;
      final errorSamples = <String>[];

      for (var i = 0; i < recipients.length; i += chunk) {
        final part = recipients.sublist(i, min(i + chunk, recipients.length));
        final map = await widget.service.sendGovernanceAudienceEmail(
          subject: subject,
          bodyText: body,
          recipients: part,
        );
        totalSent += (map['sent'] as num?)?.toInt() ?? 0;
        totalFailed += (map['failed'] as num?)?.toInt() ?? 0;
        final errs = map['errors'];
        if (errs is List && errorSamples.length < 4) {
          for (final e in errs) {
            if (errorSamples.length >= 4) {
              break;
            }
            errorSamples.add(e.toString());
          }
        }
      }

      if (!mounted) {
        return;
      }

      if (totalFailed == 0) {
        context.showUserSuccess('Enviado: $totalSent mensagem(ns).');
      } else {
        final tail = errorSamples.isEmpty ? '' : ' Ex.: ${errorSamples.first}';
        context.showUserMessage(
          'Envio parcial: $totalSent ok, $totalFailed falha(s).$tail',
          kind: AppUserMessageKind.warning,
        );
      }
    } catch (e, st) {
      debugPrint('sendGovernanceAudienceEmail: $e\n$st');
      if (mounted) {
        context.showUserError('Falha ao enviar (verifique configuração SMTP/SendGrid).');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _clearExclusions() {
    setState(_excludedEmails.clear);
  }

  void _excludeAll() {
    setState(() {
      _excludedEmails
        ..clear()
        ..addAll(_rows.map((r) => r.email.trim().toLowerCase()).where((e) => e.isNotEmpty));
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipients = _recipientList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Os endereços vêm de empresas na carteira, pré-cadastro leve, escritórios em teste, '
          'cadastro completo (Passo C), convites trial e fluxos equivalentes já usados na governança.',
          style: TextStyle(color: AppBrandColors.softText, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _pulling ? null : _pullEmails,
              icon: _pulling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_pulling ? 'Carregando…' : 'Puxar e-mails'),
            ),
            TextButton(
              onPressed: _rows.isEmpty ? null : _clearExclusions,
              child: const Text('Limpar exclusões'),
            ),
            TextButton(
              onPressed: _rows.isEmpty ? null : _excludeAll,
              child: const Text('Excluir todos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subjectCtrl,
          enabled: !_sending,
          decoration: const InputDecoration(
            labelText: 'Assunto',
            hintText: 'Assunto do e-mail',
          ),
          contextMenuBuilder: _editableContextMenu,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyCtrl,
          enabled: !_sending,
          decoration: const InputDecoration(
            labelText: 'Texto do e-mail',
            hintText: 'Cole aqui o texto (será enviado como mensagem simples)',
            alignLabelWithHint: true,
          ),
          contextMenuBuilder: _editableContextMenu,
          minLines: 6,
          maxLines: 18,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_rows.length} na lista · ${recipients.length} receberão este envio · '
                '${_excludedEmails.length} excluídos',
                style: TextStyle(
                  color: AppBrandColors.softText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: (_sending || _pulling) ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? 'Enviando…' : 'Enviar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Marcado = esse endereço não recebe o disparo. '
          'O servidor aceita até 80 destinatários por chamada; este painel envia em lotes de 40.',
          style: TextStyle(color: AppBrandColors.softText, fontSize: 12, height: 1.3),
        ),
        const SizedBox(height: 8),
        if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Toque em “Puxar e-mails” para carregar a lista.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppBrandColors.softText),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = _rows[index];
              final emailKey = row.email.trim().toLowerCase();
              final excluded = _excludedEmails.contains(emailKey);
              return CheckboxListTile(
                value: excluded,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _excludedEmails.add(emailKey);
                    } else {
                      _excludedEmails.remove(emailKey);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(row.email, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  row.sources.join(' · '),
                  style: TextStyle(fontSize: 12, color: AppBrandColors.softText, height: 1.25),
                ),
                secondary: Icon(
                  excluded ? Icons.remove_circle_outline : Icons.mail_outline,
                  color: excluded ? Colors.orange.shade800 : AppBrandColors.softText,
                ),
              );
            },
          ),
      ],
    );
  }
}
