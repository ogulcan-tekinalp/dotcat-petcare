import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../home/presentation/home_screen.dart';

// Google Logo Widget - Basit G harfi
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Google'ın mavi rengi
    paint.color = const Color(0xFF4285F4);
    paint.style = PaintingStyle.fill;
    
    // Basit G harfi şekli
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;
    
    // Dış daire (mavi)
    canvas.drawCircle(center, radius, paint);
    
    // İç beyaz daire
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, paint);
    
    // G harfinin çizgisi (mavi)
    paint.color = const Color(0xFF4285F4);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size.width * 0.12;
    paint.strokeCap = StrokeCap.round;
    
    // G harfinin yatay çizgisi
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.4, center.dy),
      paint,
    );
    
    // G harfinin dikey çizgisi
    canvas.drawLine(
      Offset(center.dx + radius * 0.4, center.dy),
      Offset(center.dx + radius * 0.4, center.dy + radius * 0.3),
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  
  // Email/Password için form controller'ları
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signInWithGoogle();
      
      if (result != null && mounted) {
        _goToHome();
      } else if (mounted) {
        setState(() => _error = AppLocalizations.get('login_cancelled'));
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppLocalizations.get('login_error'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signInAnonymously();
      
      if (result != null && mounted) {
        _goToHome();
      } else if (mounted) {
        setState(() => _error = AppLocalizations.get('login_error'));
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppLocalizations.get('login_error'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isLoading = true; _error = null; });

    try {
      final authService = ref.read(authServiceProvider);
      UserCredential? result;
      
      if (_isSignUp) {
        result = await authService.signUpWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        result = await authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      
      if (result != null && mounted) {
        _goToHome();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMsg;
        switch (e.code) {
          case 'user-not-found':
            errorMsg = AppLocalizations.get('user_not_found');
            break;
          case 'wrong-password':
            errorMsg = AppLocalizations.get('wrong_password');
            break;
          case 'email-already-in-use':
            errorMsg = AppLocalizations.get('email_already_in_use');
            break;
          case 'weak-password':
            errorMsg = AppLocalizations.get('weak_password');
            break;
          case 'invalid-email':
            errorMsg = AppLocalizations.get('invalid_email');
            break;
          default:
            errorMsg = e.message ?? AppLocalizations.get('login_error');
        }
        setState(() => _error = errorMsg);
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppLocalizations.get('login_error'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  void _goToHome() {
    Navigator.pushReplacement(
      context,
      PageTransitions.fade(page: const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.grey.shade50,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  
                  // Logo - büyük ve arkaplansız
                  Image.asset('assets/images/logo.png', height: 120),
                  const SizedBox(height: 24),
                  
                  // App Name
                  const Text('PetCare', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  
                  // Tagline
                  Text(
                    AppLocalizations.get('login_tagline'),
                    style: TextStyle(fontSize: 16, color: context.textSecondary, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Error
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 14))),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Google Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeightLg,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: AppSpacing.iconSm,
                              height: AppSpacing.iconSm,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/google.png',
                                  width: 20,
                                  height: 20,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback: Google renklerinde basit G ikonu
                                    return Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4285F4),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'G',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  AppLocalizations.get('sign_in_google'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Divider
                  Row(children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(AppLocalizations.get('or'), style: TextStyle(color: context.textSecondary, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ]),
                  
                  const SizedBox(height: 16),
                  
                  // Email/Password Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _emailController,
                          label: AppLocalizations.get('email'),
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          errorText: _emailController.text.isNotEmpty && !_emailController.text.contains('@')
                              ? AppLocalizations.get('invalid_email')
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _passwordController,
                          label: AppLocalizations.get('password'),
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outlined,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: _isSignUp ? AppLocalizations.get('sign_up') : AppLocalizations.get('sign_in'),
                          onPressed: _signInWithEmailPassword,
                          variant: ButtonVariant.filled,
                          isLoading: _isLoading,
                          height: AppSpacing.buttonHeightLg,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _isSignUp = !_isSignUp),
                          child: Text(
                            _isSignUp 
                              ? AppLocalizations.get('already_have_account') + ' ' + AppLocalizations.get('sign_in')
                              : AppLocalizations.get('dont_have_account') + ' ' + AppLocalizations.get('sign_up'),
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Divider
                  Row(children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(AppLocalizations.get('or'), style: TextStyle(color: context.textSecondary, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ]),
                  
                  const SizedBox(height: 16),
                  
                  // Anonymous Sign In Button
                  AppButton(
                    label: AppLocalizations.get('sign_in_anonymous'),
                    onPressed: _signInAnonymously,
                    variant: ButtonVariant.outlined,
                    isLoading: _isLoading,
                    height: AppSpacing.buttonHeightLg,
                  ),
                  
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
