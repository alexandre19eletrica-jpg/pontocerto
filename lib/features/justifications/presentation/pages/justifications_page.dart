import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/media/firebase_media_upload.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/justifications/domain/justification.dart';
import 'package:pontocerto/features/justifications/presentation/justifications_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class JustificationsPage extends ConsumerWidget {
  const JustificationsPage({super.key});

  static const int _maxInlineImageBytes = 5 * 1024 * 1024;

  Widget _surface({
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    final isEmployee = sessao.role == Role.employee;
    final lista = ref.watch(justificationsProvider);
    final pendentes = lista.where((j) => j.status == JustificationStatus.pending).length;
    final aprovadas = lista.where((j) => j.status == JustificationStatus.approved).length;
    final rejeitadas = lista.where((j) => j.status == JustificationStatus.rejected).length;

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Justificativas',
        subtitle: 'Acompanhe pedidos pendentes, aprovados e rejeitados sem repetir informacoes.',
        chips: [
          AppHeaderChip('Pendentes $pendentes'),
          AppHeaderChip('Aprovadas $aprovadas'),
          AppHeaderChip('Rejeitadas $rejeitadas'),
        ],
      ),
      beforeLogout: isEmployee
          ? [
              IconButton(
                onPressed: () => _abrirDialogoNovo(context, ref),
                icon: const Icon(Icons.add),
                tooltip: 'Nova justificativa',
              ),
            ]
          : const [],
    );

    final content = lista.isEmpty
            ? const Center(child: Text('Nenhuma justificativa encontrada.'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                children: [
                  _surface(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.summarize_outlined),
                      title: const Text('Resumo'),
                      subtitle: Text(
                        'Total: ${lista.length} | Pendentes: $pendentes | Aprovadas: $aprovadas | Rejeitadas: $rejeitadas',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in lista)
                    _surface(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text('${_formatDate(item.date)} - ${_status(item.status)}'),
                        subtitle: Text(
                          '${item.reason}\nComprovante: ${item.comprovanteNomeArquivo ?? 'Arquivo enviado'}',
                        ),
                        isThreeLine: true,
                        onTap: () => _abrirComprovante(context, item.comprovanteUrl),
                        trailing: isEmployee
                            ? null
                            : Wrap(
                                spacing: 6,
                                children: [
                                  if (item.status == JustificationStatus.pending)
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          await ref.read(justificationsProvider.notifier).approve(item.id);
                                          if (!context.mounted) return;
                                          _msg(context, 'Justificativa aprovada.');
                                        } catch (_) {
                                          if (!context.mounted) return;
                                          _msg(context, 'Erro ao aprovar justificativa.');
                                        }
                                      },
                                      child: const Text('Aprovar'),
                                    ),
                                  if (item.status == JustificationStatus.pending)
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          await ref.read(justificationsProvider.notifier).reject(item.id);
                                          if (!context.mounted) return;
                                          _msg(context, 'Justificativa rejeitada.');
                                        } catch (_) {
                                          if (!context.mounted) return;
                                          _msg(context, 'Erro ao rejeitar justificativa.');
                                        }
                                      },
                                      child: const Text('Rejeitar'),
                                    ),
                                  IconButton(
                                    onPressed: () async {
                                      try {
                                        await ref.read(justificationsProvider.notifier).remove(item.id);
                                        try {
                                          if (item.comprovanteUrl.isNotEmpty) {
                                            await FirebaseStorage.instance.refFromURL(item.comprovanteUrl).delete();
                                          }
                                        } catch (_) {
                                          // Nao bloqueia exclusao do registro se falhar no storage.
                                        }
                                        if (!context.mounted) return;
                                        _msg(context, 'Justificativa excluida.');
                                      } catch (_) {
                                        if (!context.mounted) return;
                                        _msg(context, 'Erro ao excluir justificativa.');
                                      }
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Excluir',
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              );

    return AppGradientBackground(
      child: AppPageLayout(child: content),
    );
  }

  Future<void> _abrirDialogoNovo(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();
    DateTime dataSelecionada = DateTime.now();
    XFile? comprovante;
    String? nomeComprovante;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Nova justificativa de falta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Data: ${_formatDate(dataSelecionada)}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dataSelecionada,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setStateDialog(() => dataSelecionada = picked);
                    },
                    child: const Text('Selecionar'),
                  ),
                ],
              ),
              TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Motivo'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nomeComprovante == null
                          ? 'Comprovante: nenhum arquivo selecionado'
                          : 'Comprovante: $nomeComprovante',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final opcao = await showModalBottomSheet<ImageSource>(
                        context: context,
                        builder: (_) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('Foto da camera'),
                                onTap: () => Navigator.of(context).pop(ImageSource.camera),
                              ),
                              ListTile(
                                title: const Text('Foto da galeria'),
                                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (opcao == null) return;
                      final arquivo = await ImagePicker().pickImage(
                        source: opcao,
                        imageQuality: 85,
                      );
                      if (arquivo == null) return;
                      setStateDialog(() {
                        comprovante = arquivo;
                        nomeComprovante = arquivo.name;
                      });
                    },
                    child: const Text('Selecionar foto'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  _msg(context, 'Informe o motivo da justificativa.');
                  return;
                }
                if (comprovante == null) {
                  _msg(context, 'Envie a foto do comprovante para continuar.');
                  return;
                }
                try {
                  final sessao = ref.read(sessionProvider);
                  if (sessao == null) {
                    _msg(context, 'Sessao nao encontrada.');
                    return;
                  }
                  final id = DateTime.now().microsecondsSinceEpoch.toString();
                  final nomeArquivo = '$id.jpg';
                  final companyId = await _resolverCompanyId(sessao);
                  final caminhoStorage = 'companies/$companyId/justifications/$nomeArquivo';
                  final comprovanteUrl = await FirebaseMediaUpload.uploadXFileWithBucketFallback(
                    caminhoStorage: caminhoStorage,
                    source: comprovante!,
                    contentType: 'image/jpeg',
                  );

                  await ref.read(justificationsProvider.notifier).create(
                        date: dataSelecionada,
                        reason: reason,
                        comprovanteUrl: comprovanteUrl,
                        comprovanteNomeArquivo: nomeArquivo,
                      );
                } on FirebaseException catch (e) {
                  if (!context.mounted) return;
                  final detalhe = (e.message ?? '').trim();
                  _msg(context, 'Erro ao salvar justificativa: ${e.code}${detalhe.isEmpty ? '' : ' - $detalhe'}');
                  return;
                } catch (_) {
                  if (!context.mounted) return;
                  _msg(context, 'Erro ao salvar justificativa.');
                  return;
                }

                if (!context.mounted) return;
                Navigator.of(context).pop();
                _msg(context, 'Justificativa enviada com sucesso.');
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );

    reasonController.dispose();
  }

  static String _formatDate(DateTime data) {
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    return '$d/$m/${data.year}';
  }

  String _status(JustificationStatus status) {
    return switch (status) {
      JustificationStatus.pending => 'Pendente',
      JustificationStatus.approved => 'Aprovada',
      JustificationStatus.rejected => 'Rejeitada',
    };
  }

  static Future<String> _resolverCompanyId(Session sessao) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final companyId = doc.data()?['companyId']?.toString().trim();
      if (companyId != null && companyId.isNotEmpty) return companyId;
    } catch (_) {
      // fallback na sessao.
    }
    return sessao.companyId;
  }

  static void _msg(BuildContext context, String texto) {
    if (!context.mounted) return;
    context.showUserMessage(texto);
  }

  static void _abrirComprovante(BuildContext context, String url) {
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: FutureBuilder<ImageProvider>(
          future: _resolverImagemProvider(url),
          builder: (_, snapshot) {
            if (snapshot.hasData) {
              return Image(image: snapshot.data!, fit: BoxFit.contain);
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nao foi possivel abrir o comprovante.'),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  static Future<ImageProvider> _resolverImagemProvider(String origem) async {
    if (origem.startsWith('http://') || origem.startsWith('https://')) {
      return NetworkImage(origem);
    }
    if (!origem.startsWith('gs://')) {
      return NetworkImage(origem);
    }
    final ref = FirebaseStorage.instance.refFromURL(origem);
    try {
      final url = await ref.getDownloadURL();
      return NetworkImage(url);
    } catch (_) {
      final metadata = await ref.getMetadata();
      final size = metadata.size ?? 0;
      if (size > _maxInlineImageBytes) {
        throw Exception('Comprovante acima do limite para visualizacao inline.');
      }
      final Uint8List? bytes = await ref.getData(_maxInlineImageBytes);
      if (bytes == null) throw Exception('Comprovante indisponivel.');
      return MemoryImage(bytes);
    }
  }
}

