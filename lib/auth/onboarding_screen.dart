import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Post-registration onboarding: creates user profile in Firestore and notifies admin.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _createProfile();
  }

  Future<void> _createProfile() async {
    setState(() => _isCreating = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef =
          FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        await docRef.set({
          'nombre': user.displayName ?? 'Usuario',
          'email': user.email ?? '',
          'fecha_creacion': FieldValue.serverTimestamp(),
          'rol': 'pendiente',
          'suscripciones_apps': {
            'tone_generator': false,
            'generador_tonos': false,
          },
        });

        // Notify admin
        await FirebaseFirestore.instance.collection('consultas_web').add({
          'nombre': user.displayName ?? 'Usuario',
          'email': user.email,
          'motivo': 'Nuevo Usuario - Tone Generator',
          'mensaje':
              '${user.displayName ?? "Un usuario"} (${user.email}) se registró en el Tone Generator y solicita acceso.',
          'tipo': 'nuevo_usuario',
          'fecha': FieldValue.serverTimestamp(),
          'leido': false,
          'eliminado': false,
        });
      }

      // Force a rebuild of the auth gate by triggering a token refresh
      await user.getIdToken(true);
      // The StreamBuilder in auth_gate will pick up the change
    } catch (e) {
      debugPrint("Error creating profile: $e");
    }

    if (mounted) setState(() => _isCreating = false);
  }

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
                  // Icon
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
                        Icons.graphic_eq_rounded,
                        color: Color(0xFF6C63FF),
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Creando tu perfil...",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isCreating)
                    const CircularProgressIndicator(color: Color(0xFF6C63FF))
                  else ...[
                    Text(
                      "Tu perfil fue creado. El administrador revisará tu acceso.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          // Force auth gate to re-check by refreshing
                          FirebaseAuth.instance.currentUser?.getIdToken(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Verificar acceso",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
