import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/features/marketing/presentation/services/public_demo_access_service.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(widget.sourcePath),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
