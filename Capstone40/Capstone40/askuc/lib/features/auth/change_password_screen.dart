import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
      TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _changePassword() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully.')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF20262D)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(
            color: Color(0xFF20262D),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update your account password',
                style: TextStyle(color: Color(0xFF8A969E), fontSize: 10),
              ),

              const SizedBox(height: 20),

              _passwordField(
                controller: _currentPasswordController,
                label: 'Current Password',
                obscureText: _hideCurrentPassword,
                onToggle: () {
                  setState(() {
                    _hideCurrentPassword = !_hideCurrentPassword;
                  });
                },
              ),

              const SizedBox(height: 12),

              _passwordField(
                controller: _newPasswordController,
                label: 'New Password',
                obscureText: _hideNewPassword,
                onToggle: () {
                  setState(() {
                    _hideNewPassword = !_hideNewPassword;
                  });
                },
              ),

              const SizedBox(height: 12),

              _passwordField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                obscureText: _hideConfirmPassword,
                onToggle: () {
                  setState(() {
                    _hideConfirmPassword = !_hideConfirmPassword;
                  });
                },
                confirm: true,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0866E8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    bool confirm = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Color(0xFF20262D), fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8A969E), fontSize: 11),
        filled: true,
        fillColor: Colors.white,

        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: const Color(0xFF8A969E),
            size: 19,
          ),
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE7EC)),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE7EC)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0866E8)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label is required';
        }

        if (confirm && value != _newPasswordController.text) {
          return 'Passwords do not match';
        }

        if (!confirm && label == 'New Password' && value.length < 6) {
          return 'Password must be at least 6 characters';
        }

        return null;
      },
    );
  }
}
