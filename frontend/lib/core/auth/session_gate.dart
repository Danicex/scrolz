import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import '../utils/api_helper.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.child});
  final Widget child;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiHelper.onUnauthorized = _sync; // backend token expired: get a new one
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _sync() async {
    if (!mounted) return;
    setState(() => _error = null);
    final auth = ClerkAuth.of(context, listen: false);
    try {
      final clerkToken = await auth.sessionToken();
      final res = await ApiHelper.exchangeClerkToken(clerkToken.jwt);
      if (!mounted) return;
      setState(() {
        _ready = res.isSuccess;
        _error = res.error;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not reach Clerk: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return Scaffold(
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _sync, child: const Text('Retry')),
                ],
              ),
      ),
    );
  }
}