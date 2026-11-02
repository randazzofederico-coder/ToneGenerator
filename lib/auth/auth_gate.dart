import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_repository.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import '../screens/tone_generator_screen.dart';
import '../widgets/disclaimer_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D1A),
            body: Center(
              child: Icon(Icons.graphic_eq_rounded,
                  size: 64, color: Color(0xFF6C63FF)),
            ),
          );
        }

        // No user → Login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // User logged in → check permissions
        return _PermissionChecker(user: snapshot.data!);
      },
    );
  }
}

class _PermissionChecker extends StatefulWidget {
  final User user;
  const _PermissionChecker({required this.user});

  @override
  State<_PermissionChecker> createState() => _PermissionCheckerState();
}

class _PermissionCheckerState extends State<_PermissionChecker> {
  bool _isLoading = true;
  bool _hasProfile = false;
  bool _hasAccess = false;
  String _rolStatus = '';
  bool _trialActive = false;
  int _trialDaysLeft = 0;
  bool _trialExpired = false;
  bool _trialUsed = false;

  // Offline state
  bool _isOffline = false;
  int _daysUntilExpiry = 30;
  bool _needsInternet = false;
  String _needsInternetReason = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      // --- ATTEMPT ONLINE CHECK (force server, not Firestore cache) ---
      final docSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.user.uid)
          .get(const GetOptions(source: Source.server));

      if (!docSnap.exists) {
        // No profile → needs onboarding
        await AuthRepository.instance.savePermissionCache(
          hasAccess: false,
          hasProfile: false,
          rol: 'pendiente',
          trialActive: false,
          trialDaysLeft: 0,
          trialExpired: false,
          trialUsed: false,
        );
        setState(() {
          _isLoading = false;
          _hasProfile = false;
          _isOffline = false;
        });
        return;
      }

      final data = docSnap.data()!;
      final suscripciones =
          data['suscripciones_apps'] as Map<String, dynamic>?;
      final hasToneGen = suscripciones?['generador_tonos'] == true ||
          suscripciones?['tone_generator'] == true;
      final rol = data['rol'] as String? ?? 'pendiente';

      // Check trial period
      bool trialActive = false;
      int trialDaysLeft = 0;
      bool trialExpired = false;
      bool trialUsed = false;

      final trialInicio = data['trial_tone_generator_inicio'];
      if (trialInicio != null) {
        trialUsed = true;
        final DateTime trialStart = (trialInicio as Timestamp).toDate();
        final DateTime trialEnd = trialStart.add(const Duration(days: 30));
        final DateTime now = DateTime.now();

        if (now.isBefore(trialEnd)) {
          trialActive = true;
          trialDaysLeft = trialEnd.difference(now).inDays;
        } else {
          trialExpired = true;
        }
      }

      final hasAccess = hasToneGen || rol == 'admin' || trialActive;

      // --- CACHE THE RESULT ---
      await AuthRepository.instance.savePermissionCache(
        hasAccess: hasAccess,
        hasProfile: true,
        rol: rol,
        trialActive: trialActive,
        trialDaysLeft: trialDaysLeft,
        trialExpired: trialExpired,
        trialUsed: trialUsed,
      );

      setState(() {
        _isLoading = false;
        _hasProfile = true;
        _hasAccess = hasAccess;
        _rolStatus = rol;
        _trialActive = trialActive;
        _trialDaysLeft = trialDaysLeft;
        _trialExpired = trialExpired;
        _trialUsed = trialUsed;
        _isOffline = false;
        _daysUntilExpiry = 30;
      });
    } catch (e) {
      // --- OFFLINE FALLBACK ---
      debugPrint("Firestore check failed (offline?): $e");
      _handleOfflineFallback();
    }
  }

  void _handleOfflineFallback() {
    final cache = AuthRepository.instance.loadPermissionCache();

    if (cache == null) {
      setState(() {
        _isLoading = false;
        _needsInternet = true;
        _needsInternetReason =
            'Necesitás conectarte a internet al menos una vez para verificar tu acceso.';
      });
      return;
    }

    if (cache.isExpired) {
      setState(() {
        _isLoading = false;
        _needsInternet = true;
        _needsInternetReason =
            'Han pasado más de 30 días desde tu última verificación. '
            'Conectate a internet para revalidar tu acceso.';
      });
      return;
    }

    if (!cache.hasProfile) {
      setState(() {
        _isLoading = false;
        _needsInternet = true;
        _needsInternetReason =
            'Tu perfil no fue creado todavía. '
            'Conectate a internet para completar el registro.';
      });
      return;
    }

    if (!cache.hasAccess) {
      setState(() {
        _isLoading = false;
        _needsInternet = true;
        _needsInternetReason =
            'Tu acceso no estaba habilitado en la última verificación. '
            'Conectate a internet para verificar si cambió tu estado.';
      });
      return;
    }

    // Cache valid + has access → enter offline mode
    setState(() {
      _isLoading = false;
      _hasProfile = true;
      _hasAccess = true;
      _rolStatus = cache.rol;
      _trialActive = cache.trialActive;
      _trialDaysLeft = cache.trialDaysLeft;
      _trialExpired = cache.trialExpired;
      _trialUsed = cache.trialUsed;
      _isOffline = true;
      _daysUntilExpiry = cache.daysUntilExpiry;
    });
  }

  Future<void> _signOut() async {
    await AuthRepository.instance.clearPermissionCache();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: Center(
          child: Icon(Icons.graphic_eq_rounded,
              size: 64, color: Color(0xFF6C63FF)),
        ),
      );
    }

    // Needs internet
    if (_needsInternet) {
      return _NeedsInternetScreen(
        reason: _needsInternetReason,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _needsInternet = false;
          });
          _checkPermissions();
        },
        onSignOut: _signOut,
      );
    }

    // No profile → Onboarding
    if (!_hasProfile) {
      return const OnboardingScreen();
    }

    // Has profile but no access → pending
    if (!_hasAccess) {
      return _PendingAccessScreen(
        rol: _rolStatus,
        trialExpired: _trialExpired,
        trialUsed: _trialUsed,
        onSignOut: _signOut,
        onRetry: () {
          setState(() => _isLoading = true);
          _checkPermissions();
        },
        onTrialActivated: () {
          setState(() => _isLoading = true);
          _checkPermissions();
        },
      );
    }

    // Access granted → App (with disclaimer gate)
    Widget home = const DisclaimerGate(child: ToneGeneratorScreen());

    // Offline warning banner
    if (_isOffline && _daysUntilExpiry <= 5) {
      return _OfflineWarningWrapper(
        daysLeft: _daysUntilExpiry,
        child: home,
      );
    }

    // Trial banner
    if (_trialActive) {
      return _TrialBannerWrapper(
        daysLeft: _trialDaysLeft,
        child: home,
      );
    }

    return home;
  }
}

// ---------------------------------------------------------------------------
// Offline warning banner
// ---------------------------------------------------------------------------
class _OfflineWarningWrapper extends StatelessWidget {
  final int daysLeft;
  final Widget child;

  const _OfflineWarningWrapper({required this.daysLeft, required this.child});

  @override
  Widget build(BuildContext context) {
    final dayText = daysLeft == 1 ? 'día' : 'días';
    final message = daysLeft == 0
        ? 'Conectate a internet hoy para revalidar tu acceso'
        : 'Conectate a internet para revalidar tu acceso · $daysLeft $dayText restantes';

    return Column(
      children: [
        Material(
          color: const Color(0xFF0D0D1A),
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A3800), Color(0xFFF59E0B)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Trial banner
// ---------------------------------------------------------------------------
class _TrialBannerWrapper extends StatelessWidget {
  final int daysLeft;
  final Widget child;

  const _TrialBannerWrapper({required this.daysLeft, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: const Color(0xFF0D0D1A),
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1E4E), Color(0xFF6C63FF)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Período de prueba · $daysLeft ${daysLeft == 1 ? 'día' : 'días'} restantes",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final uri =
                          Uri.parse('https://federicorandazzo.com.ar/apps/');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Suscribirse",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Needs internet screen
// ---------------------------------------------------------------------------
class _NeedsInternetScreen extends StatelessWidget {
  final String reason;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _NeedsInternetScreen({
    required this.reason,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (_, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            const Color(0xFFEF4444).withValues(alpha: 0.15),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: Color(0xFFF59E0B),
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Conexión necesaria",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text(
                        "Reintentar",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: onSignOut,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white30,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Cerrar sesión",
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending access screen
// ---------------------------------------------------------------------------
class _PendingAccessScreen extends StatefulWidget {
  final String rol;
  final bool trialExpired;
  final bool trialUsed;
  final VoidCallback onSignOut;
  final VoidCallback onRetry;
  final VoidCallback onTrialActivated;

  const _PendingAccessScreen({
    required this.rol,
    required this.trialExpired,
    required this.trialUsed,
    required this.onSignOut,
    required this.onRetry,
    required this.onTrialActivated,
  });

  @override
  State<_PendingAccessScreen> createState() => _PendingAccessScreenState();
}

class _PendingAccessScreenState extends State<_PendingAccessScreen> {
  bool _isActivatingTrial = false;

  Future<void> _activateTrial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isActivatingTrial = true);

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'trial_tone_generator_inicio': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('consultas_web').add({
        'nombre': user.displayName ?? 'Usuario',
        'email': user.email,
        'motivo': 'Trial Activado - Tone Generator',
        'mensaje':
            '${user.displayName ?? "Un usuario"} (${user.email}) activó el período de prueba de 30 días para el Tone Generator.',
        'tipo': 'trial_activado',
        'fecha': FieldValue.serverTimestamp(),
        'leido': false,
        'eliminado': false,
      });

      if (mounted) widget.onTrialActivated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al activar prueba: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isActivatingTrial = false);
      }
    }
  }

  Future<void> _openSubscription() async {
    final uri = Uri.parse('https://federicorandazzo.com.ar/apps/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTrial = !widget.trialUsed;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main card
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (_, value, child) =>
                            Transform.scale(scale: value, child: child),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6C63FF).withValues(alpha: 0.15),
                                const Color(0xFF00D2FF).withValues(alpha: 0.15),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mail_outline_rounded,
                            color: Color(0xFF6C63FF),
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        "Solicitud Enviada",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color:
                                    const Color(0xFF10B981).withValues(alpha: 0.8),
                                size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "El administrador fue notificado",
                              style: TextStyle(
                                color:
                                    const Color(0xFF10B981).withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        "Tu acceso será habilitado pronto.\n"
                        "Podés verificar de nuevo o activar el período de prueba.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Trial card
                if (canTrial) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Probá gratis por 30 días",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Acceso completo al Tone Generator durante 30 días.",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed:
                                _isActivatingTrial ? null : _activateTrial,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isActivatingTrial
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("Activar período de prueba"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (widget.trialExpired)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.timer_off,
                            color: Color(0xFFEF4444), size: 28),
                        const SizedBox(height: 8),
                        const Text(
                          "Período de prueba finalizado",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Contactá al administrador para continuar.",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Subscription card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Suscripción",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Obtené acceso completo con una suscripción.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _openSubscription,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6C63FF),
                            side: const BorderSide(color: Color(0xFF6C63FF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Ver opciones"),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Bottom actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text("Verificar"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: widget.onSignOut,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text("Cerrar sesión"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
