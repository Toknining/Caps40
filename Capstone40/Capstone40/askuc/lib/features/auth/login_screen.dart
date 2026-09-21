import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMePreference();
  }

  Future<void> _loadRememberMePreference() async {
    final rememberMe = await AuthService.shouldAutoLogin();
    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService.loginStudent(
        email: _emailController.text,
        password: _passwordController.text,
      );

      await AuthService.setRememberMe(_rememberMe);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.main,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please check your email and password.';

      if (e.code == 'student-not-found') {
        message = 'No student found for this ID.';
      } else if (e.code == 'student-email-missing') {
        message = 'This student profile is missing an email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'user-not-found') {
        message = 'No account found for this student ID.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid student ID.';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled.';
      } else if (e.code == 'operation-not-allowed') {
        message =
            'Email/password login is disabled in Firebase. Enable Email/Password in Firebase Console > Authentication > Sign-in method.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first.')),
      );
      return;
    }

    try {
      await AuthService.resetPasswordForEmail(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Unable to send password reset email.';

      if (e.code == 'user-not-found') {
        message = 'No account is registered for this email.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 8),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // ==================================================
                // ASKUC LOGO
                // ==================================================
                const SizedBox(height: 58),

                Center(
                  child: Text(
                    'AskUC',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 30,
                      fontStyle: FontStyle.normal,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // WELCOME BACK
                // ==================================================
                const Center(
                  child: Text(
                    'Welcome Back',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 21,
                      fontStyle: FontStyle.normal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                // ==================================================
                // SUBTITLE
                // ==================================================
                const Center(
                  child: Text(
                    'Login to your student account',
                    style: TextStyle(
                      color: Color(0xFF8A969E),
                      fontSize: 12,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),

                const SizedBox(height: 45),

                // ==================================================
                // EMAIL
                // ==================================================
                _fieldLabel('Email'),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _emailController,

                  keyboardType: TextInputType.emailAddress,

                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF34454F),
                  ),

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }

                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },

                  decoration: _inputDecoration(hintText: 'Enter your email'),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // PASSWORD
                // ==================================================
                _fieldLabel('Password'),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _passwordController,

                  obscureText: _obscurePassword,

                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF34454F),
                  ),

                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }

                    return null;
                  },

                  decoration: _inputDecoration(
                    hintText: 'Enter your password',

                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,

                        size: 19,

                        color: const Color(0xFF9AA6AE),
                      ),

                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                // ==================================================
                // FORGOT PASSWORD
                // ==================================================
                Align(
                  alignment: Alignment.centerRight,

                  child: TextButton(
                    onPressed: _forgotPassword,

                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(
                        top: 5,
                        bottom: 0,
                        left: 5,
                        right: 0,
                      ),

                      minimumSize: Size.zero,

                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),

                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF0866E8),
                        fontSize: 11,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // REMEMBER ME
                // ==================================================
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: const Color(0xFF0866E8),
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                    const Text(
                      'Remember me',
                      style: TextStyle(
                        color: Color(0xFF34454F),
                        fontSize: 11,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ==================================================
                // LOGIN BUTTON
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 46,

                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _login,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0866E8),

                      foregroundColor: Colors.white,

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),

                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.normal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // REGISTER
                // ==================================================
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Color(0xFF8A969E),
                        fontSize: 11,
                        fontStyle: FontStyle.normal,
                      ),

                      children: [
                        const TextSpan(text: "Don't have an account? "),

                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,

                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.register);
                            },

                            child: const Text(
                              'Register',
                              style: TextStyle(
                                color: Color(0xFF0866E8),
                                fontSize: 11,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // FIELD LABEL
  // ================================================================

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF34454F),
        fontSize: 11,
        fontStyle: FontStyle.normal,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ================================================================
  // INPUT DECORATION
  // ================================================================

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,

      hintStyle: const TextStyle(
        color: Color(0xFFAFBBC2),
        fontSize: 11,
        fontStyle: FontStyle.normal,
      ),

      suffixIcon: suffixIcon,

      filled: true,

      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),

        borderSide: const BorderSide(color: Color(0xFFD1E0E7), width: 1),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),

        borderSide: const BorderSide(color: Color(0xFF0866E8), width: 1.2),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),

        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),

        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }
}
