import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/features/marketing/presentation/services/public_demo_access_service.dart';
import 'package:pontocerto/firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicDemoAccessPage extends StatefulWidget {
  const PublicDemoAccessPage({
    super.key,
    required this.profile,
    required this.sourcePath,
  });

  final String profile;
  final String sourcePath;

  @override
  State<PublicDemoAccessPage> createState() => _PublicDemoAccessPageState();
}

class _PublicDemoAccessPageState extends State<PublicDemoAccessPage> {
  final _service = PublicDemoAccessService();
  String _message = 'Preparando acesso demo...';
  bool _opening = true;

  String get _projectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;

  static final Uri _firebaseTokensDoc = Uri.parse(
    'https://firebase.google.com/docs/auth/admin/create-custom-tokens',
  );

  Uri get _serviceAccountsConsole => Uri.parse(
        'https://console.cloud.google.com/iam-admin/serviceaccounts?project=$_projectId',
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _openUrl(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _open() async {
    try {
      final result = await _service.openDemo(
        profile: widget.profile,
        pagePath: widget.sourcePath,
      );
      if (!mounted) return;
      context.go(result.targetRoute);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _message = AppErrorMapper.messageFrom(
          error,
          fallback:
              'Nao foi possivel abrir o demo agora. Volte para a pagina de vendas e tente novamente.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_opening) const CircularProgressIndicator(),
                if (!_opening)
                  Icon(Icons.cloud_off_outlined, size: 48, color: Colors.blueGrey.shade600),
                const SizedBox(height: 16),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (!_opening) ...[
                  Text(
                    'Nao e bug do app: conceda Token Creator (roles/iam.serviceAccountTokenCreator) '
                    'a conta de servico das Cloud Functions sobre a firebase-adminsdk.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _openUrl(_firebaseTokensDoc),
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: const Text('Documentacao Firebase'),
                      ),
                      TextButton.icon(
                        onPressed: () => _openUrl(_serviceAccountsConsole),
                        icon: const Icon(Icons.dns_outlined, size: 18),
                        label: Text('Contas Google Cloud ($_projectId)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton(
                  onPressed: () => context.go(widget.sourcePath),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
