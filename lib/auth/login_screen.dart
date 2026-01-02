import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zecure/auth/responsive_register_screen.dart';
import 'package:zecure/main.dart';
import 'package:zecure/screens/map_screen.dart';
import 'package:zecure/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // OTP
  bool _showOTPVerification = false;
  String? _pendingVerificationEmail;
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResendOTP = false;

  //RESET PASSWORD
  bool _showForgotPassword = false;
  bool _showPasswordResetOTP = false;
  bool _showNewPasswordForm = false;
  String? _resetEmail;
  final _forgotPasswordEmailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _resetOtpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _resetOtpFocusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );
  Timer? _resetResendTimer;
  int _resetResendCountdown = 60;
  bool _canResendResetOTP = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final identifier = _emailOrUsernameController.text.trim();
      final password = _passwordController.text.trim();

      // Determine if identifier is email or username
      final isEmail = identifier.contains('@');
      String actualEmail = identifier;

      if (!isEmail) {
        // First get email associated with username
        final response = await Supabase.instance.client
            .from('users')
            .select('email')
            .eq('username', identifier)
            .single();

        if (response['email'] != null) {
          actualEmail = response['email'];
        } else {
          throw const AuthException('Username not found');
        }
      }

      // Try to sign in
      final authService = AuthService(Supabase.instance.client);

      try {
        await authService.signInWithEmail(
          email: actualEmail,
          password: password,
        );

        // If we get here, user is signed in successfully
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null && currentUser.emailConfirmedAt == null) {
          // Email not verified, show OTP screen
          setState(() {
            _showOTPVerification = true;
            _pendingVerificationEmail = actualEmail;
          });
          _startResendTimer();

          // Send new OTP
          await authService.resendOTP(email: actualEmail);

          _showSuccessSnackBar(
            'Please verify your email. We\'ve sent you a verification code.',
          );
        } else {
          // Email verified, go to app
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MapScreen()),
            );
          }
        }
      } on AuthException catch (authError) {
        // Check if the error is specifically about email not being confirmed
        if (authError.message.toLowerCase().contains('email not confirmed') ||
            authError.message.toLowerCase().contains('not confirmed')) {
          // Show OTP verification screen instead of error - NO ERROR MESSAGE
          setState(() {
            _showOTPVerification = true;
            _pendingVerificationEmail = actualEmail;
          });
          _startResendTimer();

          // Send OTP for verification
          await authService.resendOTP(email: actualEmail);

          _showSuccessSnackBar(
            'Please verify your email. We\'ve sent you a verification code.',
          );
        } else {
          // Other auth errors (wrong password, etc.) - ONLY show error if NOT transitioning to OTP
          if (!_showOTPVerification) {
            _showErrorSnackBar(authError.message);
          }
        }
      }
    } catch (error) {
      // ONLY show error if NOT transitioning to OTP screen
      if (!_showOTPVerification) {
        _showErrorSnackBar(
          'Invalid credentials. Please check your login details.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startResendTimer() {
    setState(() {
      _canResendOTP = false;
      _resendCountdown = 60;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        setState(() => _canResendOTP = true);
        timer.cancel();
      }
    });
  }

  Future<void> _verifyEmailOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showErrorSnackBar('Please enter the complete 6-digit code');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = AuthService(Supabase.instance.client);

      // Use the new verification method
      await authService.verifyExistingUserEmail(
        email: _pendingVerificationEmail!,
        otp: otp,
      );

      // Show success message and redirect to password reset
      _showSuccessSnackBar('Email verified! You can now reset your password.');

      // Reset form and show forgot password form
      setState(() {
        _showOTPVerification = false;
        _showNewPasswordForm = true;
        _resetEmail = _pendingVerificationEmail;
        _pendingVerificationEmail = null;
      });
    } catch (e) {
      _showErrorSnackBar('Invalid verification code. Please try again.');
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _otpFocusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendEmailOTP() async {
    try {
      final authService = AuthService(Supabase.instance.client);

      // Check if email looks like a dummy email
      if (_pendingVerificationEmail != null &&
          _isDummyEmail(_pendingVerificationEmail!)) {
        _showDummyEmailDialog();
        return;
      }

      await authService.sendVerificationToExistingUser(
        email: _pendingVerificationEmail!,
      );
      _showSuccessSnackBar(
        'Verification code sent again! Check your inbox and spam folder.',
      );
      _startResendTimer();
    } catch (e) {
      // Show the helpful dialog instead of just an error message
      _showDummyEmailDialog();
    }
  }

  // Add this helper method to detect dummy emails
  bool _isDummyEmail(String email) {
    final dummyPatterns = [
      'test@gmail.com',
      'dummy@gmail.com',
      'fake@gmail.com',
      'example@gmail.com',
      'user@gmail.com',
      'admin@gmail.com',
      'test@gmail.com',
      'dummy@gmail.com',
      'fake@gmail.com',
    ];

    final lowerEmail = email.toLowerCase();

    // Check exact matches
    if (dummyPatterns.contains(lowerEmail)) {
      return true;
    }

    // Check patterns
    if (lowerEmail.contains('test') && lowerEmail.contains('@test')) {
      return true;
    }

    if (lowerEmail.contains('dummy') && lowerEmail.contains('@dummy')) {
      return true;
    }

    if (lowerEmail.contains('fake') && lowerEmail.contains('@fake')) {
      return true;
    }

    // Check for obviously fake patterns
    if (RegExp(
      r'^(test|dummy|fake|example)\d*@(test|dummy|fake|example)\d*\.(com|org|net)$',
    ).hasMatch(lowerEmail)) {
      return true;
    }

    return false;
  }

  Widget _buildOTPVerificationScreen(bool isWeb) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWeb ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.mark_email_read_rounded,
            size: 80,
            color: Colors.blue.shade600,
          ),
          const SizedBox(height: 20),
          Text(
            'Verify Your Email',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter the 6-digit code sent to:',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            _pendingVerificationEmail ?? '',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade600,
            ),
          ),

          // Add helpful tip
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Check your spam folder if you don\'t see the email. Dummy emails won\'t receive codes.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // OTP Input Fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return Container(
                width: 45,
                height: 55,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextFormField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      _otpFocusNodes[index + 1].requestFocus();
                    } else if (value.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyEmailOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Verify Email',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Enhanced resend section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: _canResendOTP ? _resendEmailOTP : null,
                child: Text(
                  _canResendOTP
                      ? 'Resend Code'
                      : 'Resend in ${_resendCountdown}s',
                  style: GoogleFonts.poppins(
                    color: _canResendOTP
                        ? Colors.blue.shade600
                        : Colors.grey.shade500,
                  ),
                ),
              ),
              Text(
                '|',
                style: GoogleFonts.poppins(color: Colors.grey.shade400),
              ),
              TextButton(
                onPressed: _showDummyEmailDialog,
                child: Text(
                  'Need Help?',
                  style: GoogleFonts.poppins(
                    color: Colors.blue.shade600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _showOTPVerification = false;
                _pendingVerificationEmail = null;
              });
              _resendTimer?.cancel();
              // Sign out the user since they haven't completed verification
              Supabase.instance.client.auth.signOut();
            },
            child: Text(
              'Use Different Email',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetOTP() async {
    if (_forgotPasswordEmailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final email = _forgotPasswordEmailController.text.trim();
      final authService = AuthService(Supabase.instance.client);

      // Check user status first
      final userStatus = await authService.checkUserStatus(email);

      if (!userStatus?['exists']) {
        _showErrorSnackBar('No account found with this email address.');
        return;
      }

      // If user exists but has simple registration and isn't verified
      if (userStatus?['registration_type'] == 'simple' &&
          !userStatus?['is_verified']) {
        _showUpgradeToVerifiedDialog(email);
        return;
      }

      // Proceed with normal password reset
      await authService.resetPasswordWithOTP(email: email);

      setState(() {
        _showForgotPassword = false;
        _showPasswordResetOTP = true;
        _resetEmail = email;
      });

      _startResetResendTimer();
      _showSuccessSnackBar('Password reset code sent to your email!');
    } catch (e) {
      _showErrorSnackBar('Failed to send reset code. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPasswordResetOTP() async {
    final otp = _resetOtpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showErrorSnackBar('Please enter the complete 6-digit code');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = AuthService(Supabase.instance.client);
      await authService.verifyPasswordResetOTP(email: _resetEmail!, otp: otp);

      setState(() {
        _showPasswordResetOTP = false;
        _showNewPasswordForm = true;
      });

      _showSuccessSnackBar('Code verified! Please set your new password.');
    } catch (e) {
      _showErrorSnackBar('Invalid verification code. Please try again.');
      for (var controller in _resetOtpControllers) {
        controller.clear();
      }
      _resetOtpFocusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateNewPassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorSnackBar('Please fill in both password fields');
      return;
    }

    if (newPassword.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters long');
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorSnackBar('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = AuthService(Supabase.instance.client);
      await authService.updatePasswordWithSession(newPassword: newPassword);

      // Reset all forms
      _resetAllForms();

      _showSuccessSnackBar(
        'Password updated successfully! Please sign in with your new password.',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to update password. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendPasswordResetOTP() async {
    try {
      final authService = AuthService(Supabase.instance.client);
      await authService.resendPasswordResetOTP(email: _resetEmail!);
      _showSuccessSnackBar('Reset code sent again!');
      _startResetResendTimer();
    } catch (e) {
      _showErrorSnackBar('Failed to resend code. Please try again.');
    }
  }

  void _startResetResendTimer() {
    setState(() {
      _canResendResetOTP = false;
      _resetResendCountdown = 60;
    });

    _resetResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resetResendCountdown > 0) {
        setState(() => _resetResendCountdown--);
      } else {
        setState(() => _canResendResetOTP = true);
        timer.cancel();
      }
    });
  }

  void _resetAllForms() {
    setState(() {
      _showForgotPassword = false;
      _showPasswordResetOTP = false;
      _showNewPasswordForm = false;
      _resetEmail = null;
    });

    _forgotPasswordEmailController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    for (var controller in _resetOtpControllers) {
      controller.clear();
    }

    _resetResendTimer?.cancel();
  }

  void _showUpgradeToVerifiedDialog(String email) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final double maxWidth = isWeb
        ? 500
        : screenWidth * 0.92; // Same as your login form

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isWeb ? (screenWidth - maxWidth) / 2 : 16,
            vertical: 40,
          ),
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxWidth: maxWidth, // Match your form width exactly
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isWeb ? 28 : 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: 60,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Account Not Verified',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your account was created with simple registration and email is not verified. To reset your password, you need to verify your email first.',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Would you like to verify your email now?',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Divider
                Divider(color: Colors.grey.shade200, thickness: 1, height: 1),

                // Action buttons
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isWeb ? 28 : 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _upgradeToVerified(email);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: Colors.blue.shade200,
                          ),
                          child: Text(
                            'Verify Email',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _upgradeToVerified(String email) async {
    // Check for dummy email before attempting
    if (_isDummyEmail(email)) {
      _showErrorSnackBar(
        'Please use a valid email address. Dummy emails cannot receive verification codes.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = AuthService(Supabase.instance.client);
      await authService.sendVerificationToExistingUser(email: email);

      setState(() {
        _showForgotPassword = false;
        _showOTPVerification = true;
        _pendingVerificationEmail = email;
      });

      _startResendTimer();
      _showSuccessSnackBar(
        'Verification code sent! Check your inbox and spam folder.',
      );
    } catch (e) {
      String errorMessage = 'Failed to send verification code. ';

      if (e.toString().toLowerCase().contains('rate limit')) {
        errorMessage += 'Too many requests. Please wait before trying again.';
      } else if (e.toString().toLowerCase().contains('user not found') ||
          e.toString().toLowerCase().contains('invalid')) {
        errorMessage +=
            'Account not found. Please ensure you\'re using a real email address.';
      } else {
        errorMessage +=
            'Please ensure you\'re using a real email address and check your internet connection.';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Add this method to your login_screen.dart
  void _showDummyEmailDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final bool isWeb = screenWidth > 600;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isWeb ? 120 : 24, // reduce padding = wider dialog
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.blue.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Email Verification Issue',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: isWeb ? 18 : 16,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWeb ? 500 : screenWidth * 0.9, // wider on mobile
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unable to send verification code. This might be because:',
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 12),
                _buildIssueItem('You\'re using a dummy/test email address'),
                _buildIssueItem('The email address doesn\'t exist'),
                _buildIssueItem('Your email provider is blocking the message'),
                _buildIssueItem('You\'ve exceeded the rate limit'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solutions:',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Use a real email address (Gmail, Yahoo, etc.)\n'
                        '• Check your spam/junk folder\n'
                        '• Wait a few minutes before trying again\n'
                        '• Try a different email address if possible',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Try Different Email',
                style: GoogleFonts.poppins(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Optionally retry
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Got It',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIssueItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 8, right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordForm(bool isWeb) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWeb ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.lock_reset_rounded, size: 80, color: Colors.blue.shade600),
          const SizedBox(height: 20),
          Text(
            'Reset Password',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your email address and we\'ll send you a verification code to reset your password.',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          _buildInputField(
            controller: _forgotPasswordEmailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendPasswordResetOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Send Reset Code',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() => _showForgotPassword = false);
            },
            child: Text(
              'Back to Login',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordResetOTPForm(bool isWeb) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWeb ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.security_rounded, size: 80, color: Colors.blue.shade600),
          const SizedBox(height: 20),
          Text(
            'Enter Reset Code',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter the 6-digit code sent to:',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            _resetEmail ?? '',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return Container(
                width: 45,
                height: 55,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextFormField(
                  controller: _resetOtpControllers[index],
                  focusNode: _resetOtpFocusNodes[index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      _resetOtpFocusNodes[index + 1].requestFocus();
                    } else if (value.isEmpty && index > 0) {
                      _resetOtpFocusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyPasswordResetOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Verify Code',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: _canResendResetOTP ? _resendPasswordResetOTP : null,
            child: Text(
              _canResendResetOTP
                  ? 'Resend Code'
                  : 'Resend in ${_resetResendCountdown}s',
              style: GoogleFonts.poppins(
                color: _canResendResetOTP
                    ? Colors.red.shade600
                    : Colors.grey.shade500,
              ),
            ),
          ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: _resetAllForms,
            child: Text(
              'Back to Login',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPasswordForm(bool isWeb) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWeb ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.lock_open_rounded, size: 80, color: Colors.blue.shade600),
          const SizedBox(height: 20),
          Text(
            'Set New Password',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create a strong new password for your account',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          _buildInputField(
            controller: _newPasswordController,
            label: 'New Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter new password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 18),

          _buildInputField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updateNewPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Update Password',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: _resetAllForms,
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive margins for desktop
    EdgeInsets snackBarMargin;
    if (isWeb) {
      // Center the snackbar and constrain its width to match the form
      final double maxWidth = 500; // Same as your form max width
      final double horizontalMargin = (screenWidth - maxWidth) / 2;
      snackBarMargin = EdgeInsets.fromLTRB(
        horizontalMargin.clamp(
          32.0,
          double.infinity,
        ), // Minimum 32px from edges
        16,
        horizontalMargin.clamp(32.0, double.infinity),
        16,
      );
    } else {
      // Keep mobile margins as before
      snackBarMargin = const EdgeInsets.all(16);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: snackBarMargin,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive margins for desktop - match your form width
    EdgeInsets snackBarMargin;
    if (isWeb) {
      final double maxWidth = 500; // Same as your form max width
      final double horizontalMargin = (screenWidth - maxWidth) / 2;
      snackBarMargin = EdgeInsets.fromLTRB(
        horizontalMargin.clamp(32.0, double.infinity),
        16,
        horizontalMargin.clamp(32.0, double.infinity),
        16,
      );
    } else {
      snackBarMargin = const EdgeInsets.all(16);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: snackBarMargin,
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    _forgotPasswordEmailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    _resetResendTimer?.cancel();

    // Dispose OTP controllers and focus nodes
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    for (var controller in _resetOtpControllers) {
      controller.dispose();
    }
    for (var focusNode in _resetOtpFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // If we're in any sub-screen, go back to main login
    if (_showOTPVerification ||
        _showForgotPassword ||
        _showPasswordResetOTP ||
        _showNewPasswordForm) {
      setState(() {
        _showOTPVerification = false;
        _showForgotPassword = false;
        _showPasswordResetOTP = false;
        _showNewPasswordForm = false;
        _pendingVerificationEmail = null;
        _resetEmail = null;
      });

      // Cancel any active timers
      _resendTimer?.cancel();
      _resetResendTimer?.cancel();

      // Clear form fields
      _resetAllForms();

      return false; // Don't pop the route
    }

    // If we're on the main login screen, show exit confirmation
    return await _showExitConfirmation();
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Exit App',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to exit Zecure?',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text('Exit', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final double maxWidth = isWeb ? 500 : screenWidth * 0.92;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/LIGHT.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            // Blue tinted overlay to match your theme
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withOpacity(0.2),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWeb ? 32.0 : 16.0,
                            vertical: 16.0,
                          ),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Center(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: maxWidth,
                                  ),
                                  // Replace the existing Column children with:
                                  child: _showOTPVerification
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildHeader(isWeb),
                                            SizedBox(height: isWeb ? 32 : 24),
                                            _buildOTPVerificationScreen(isWeb),
                                            const SizedBox(height: 16),
                                          ],
                                        )
                                      : _showForgotPassword
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildHeader(isWeb),
                                            SizedBox(height: isWeb ? 32 : 24),
                                            _buildForgotPasswordForm(isWeb),
                                            const SizedBox(height: 16),
                                          ],
                                        )
                                      : _showPasswordResetOTP
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildHeader(isWeb),
                                            SizedBox(height: isWeb ? 32 : 24),
                                            _buildPasswordResetOTPForm(isWeb),
                                            const SizedBox(height: 16),
                                          ],
                                        )
                                      : _showNewPasswordForm
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildHeader(isWeb),
                                            SizedBox(height: isWeb ? 32 : 24),
                                            _buildNewPasswordForm(isWeb),
                                            const SizedBox(height: 16),
                                          ],
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildHeader(isWeb),
                                            SizedBox(height: isWeb ? 32 : 24),
                                            _buildLoginForm(isWeb),
                                            SizedBox(height: isWeb ? 24 : 20),
                                            _buildActionButtons(isWeb),
                                            SizedBox(height: isWeb ? 20 : 16),
                                            _buildFooter(isWeb),
                                            const SizedBox(height: 16),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWeb) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: isWeb ? 40 : 8),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Home icon (top-left)
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ResponsiveLandingScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.home_rounded,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Centered logo (independent of icon)
              Padding(
                padding: const EdgeInsets.only(top: 4), // aligns top visually
                child: Image.asset(
                  'assets/images/zecure.png',
                  height: isWeb ? 150 : 130,
                  width: isWeb ? 150 : 130,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: isWeb ? 150 : 130,
                    width: isWeb ? 150 : 130,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(isWeb ? 40 : 35),
                    ),
                    child: Icon(
                      Icons.security_rounded,
                      size: isWeb ? 40 : 35,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isWeb ? 20 : 16),
        Text(
          'Welcome Back!',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 28 : 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to access your Zecure account',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 16 : 14,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm(bool isWeb) {
    return Container(
      width: double.infinity, // Take full available width
      padding: EdgeInsets.all(isWeb ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email/Username Field
            _buildInputField(
              controller: _emailOrUsernameController,
              label: 'Email or Username',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email or username';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            // Password Field
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() => _showForgotPassword = true);
                },
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.poppins(
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade600, size: 20),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: GoogleFonts.poppins(),
      validator: validator,
    );
  }

  Widget _buildActionButtons(bool isWeb) {
    return Column(
      children: [
        // Login Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: Colors.blue.shade200,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login_rounded),
                      const SizedBox(width: 8),
                      Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 14),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),

        const SizedBox(height: 14),

        // Guest Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade600,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.explore_rounded),
                const SizedBox(width: 8),
                Text(
                  'Continue as Guest',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isWeb) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            "Don't have an account? ",
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ResponsiveRegisterScreen(),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Create Account',
            style: GoogleFonts.poppins(
              color: Colors.blue.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
