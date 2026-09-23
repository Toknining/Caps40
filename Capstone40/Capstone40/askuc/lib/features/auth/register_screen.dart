import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService.registerStudent(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        studentId: _studentIdController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration saved to the database.'),
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.main,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed. Please try again.';

      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Please use a stronger password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'operation-not-allowed') {
        message =
            'Email/password registration is disabled in Firebase. Enable Email/Password in Firebase Console > Authentication > Sign-in method.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save registration: $e')),
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

  void _returnToLogin() {
    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasConfirmValue = _confirmPasswordController.text.isNotEmpty;
    final bool passwordsMatch = hasConfirmValue &&
        _passwordController.text == _confirmPasswordController.text;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 8),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Back to login',
                    onPressed: _isSubmitting ? null : _returnToLogin,
                    icon: const Icon(Icons.close),
                    color: const Color(0xFF34454F),
                  ),
                ),

                // ==================================================
                // ASKUC LOGO
                // ==================================================
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

                const SizedBox(height: 12),

                // ==================================================
                // TITLE
                // ==================================================
                const Center(
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 21,
                      fontStyle: FontStyle.normal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                // ==================================================
                // SUBTITLE
                // ==================================================
                const Center(
                  child: Text(
                    'Register your student account',
                    style: TextStyle(
                      color: Color(0xFF8A969E),
                      fontSize: 12,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),

                const SizedBox(height: 31),

                // ==================================================
                // FIRST NAME
                // ==================================================
                _fieldLabel('First Name'),

                const SizedBox(height: 7),

                _inputField(
                  controller: _firstNameController,
                  hintText: 'Enter your first name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your first name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // ==================================================
                // LAST NAME
                // ==================================================
                _fieldLabel('Last Name'),

                const SizedBox(height: 7),

                _inputField(
                  controller: _lastNameController,
                  hintText: 'Enter your last name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your last name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // ==================================================
                // STUDENT ID
                // ==================================================
                _fieldLabel('Student ID'),

                const SizedBox(height: 7),

                _inputField(
                  controller: _studentIdController,
                  hintText: 'Enter your student ID',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your student ID';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // ==================================================
                // EMAIL
                // ==================================================
                _fieldLabel('Email'),

                const SizedBox(height: 7),

                _inputField(
                  controller: _emailController,
                  hintText: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }

                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // ==================================================
                // PASSWORD
                // ==================================================
                _fieldLabel('Password'),

                const SizedBox(height: 7),

                _inputField(
                  controller: _passwordController,
                  hintText: 'Create a password',
                  obscureText: _obscurePassword,
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please create a password';
                    }

                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // ==================================================
                // CONFIRM PASSWORD
                // ==================================================
                _fieldLabel('Confirm Password'),

                const SizedBox(height: 7),

                _inputField(
                  controller: _confirmPasswordController,
                  hintText: 'Confirm your password',
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                      color: const Color(0xFF9AA6AE),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }

                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),

                if (hasConfirmValue) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        passwordsMatch ? Icons.check_circle : Icons.error,
                        size: 16,
                        color: passwordsMatch
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        passwordsMatch ? 'Passwords match' : 'Passwords do not match',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: passwordsMatch
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 21),

                // ==================================================
                // CREATE ACCOUNT BUTTON
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 46,

                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _createAccount,

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
                            'CREATE ACCOUNT',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.normal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // BACK TO LOGIN
                // ==================================================
                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                            color: Color(0xFF34454F),
                            fontSize: 12,
                            fontStyle: FontStyle.normal,
                          ),
                        ),

                        TextSpan(
                          text: 'Login',
                          style: const TextStyle(
                            color: Color(0xFF0866E8),
                            fontSize: 12,
                            fontStyle: FontStyle.normal,
                            fontWeight: FontWeight.w500,
                          ),

                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.login,
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
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
  // INPUT FIELD
  // ================================================================

  Widget _inputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,

      keyboardType: keyboardType,

      obscureText: obscureText,

      validator: validator,

      style: const TextStyle(fontSize: 12, color: Color(0xFF34454F)),

      decoration: InputDecoration(
        hintText: hintText,

        hintStyle: const TextStyle(
          color: Color(0xFFAFBBC2),
          fontSize: 11,
          fontStyle: FontStyle.normal,
        ),

        suffixIcon: suffixIcon,

        filled: true,

        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),

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
      ),
    );
  }
}
