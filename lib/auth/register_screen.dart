import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zecure/auth/login_screen.dart';
import 'package:zecure/screens/map_screen.dart';
import 'package:zecure/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _extNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _birthdayController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _obscureConfirmPassword = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Add these to your existing state variables:
bool _showOTPScreen = false;
String? _pendingEmail;
final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
Timer? _resendTimer;
int _resendCountdown = 60;
bool _canResendOTP = false;

  String _registrationType = 'simple'; // 'simple' or 'verified'

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

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    _contactNumberController.text = '+63';
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

void _showTermsAndConditions() {
  final bool isWeb = MediaQuery.of(context).size.width > 600;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isWeb ? 
            MediaQuery.of(context).size.width * 0.25 : // 50% width on web
            20, // Keep mobile padding
          vertical: 40,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: 600,
            maxWidth: isWeb ? 600 : double.infinity, // Max width constraint for web
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - keep existing code
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Terms and Conditions',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content - keep existing scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isWeb ? 24 : 20), // Slightly more padding on web
                  child: Text(
                    '''Welcome to Zecure

By creating an account and using Zecure, you agree to the following terms and conditions:

1. SERVICE DESCRIPTION
Zecure is an AI-powered crime monitoring platform designed to enhance public safety in Zamboanga City by:
- Collecting and analyzing crime-related data from public sources
- Identifying crime hotspots and patterns in real-time
- Providing safety alerts and recommendations to users
- Enabling community reporting of incidents and safe locations
- Offering route recommendations based on safety data

2. USER RESPONSIBILITIES
You agree to:
- Provide accurate and truthful information during registration
- Use the platform responsibly and in accordance with local laws
- Report incidents truthfully and in good faith
- Respect the privacy and safety of other users
- Not misuse the platform for illegal activities or false reporting

3. DATA COLLECTION AND PRIVACY
- We collect personal information necessary for account creation and service provision
- Crime-related data is gathered from publicly available sources
- Your location data may be used to provide relevant safety information
- We implement security measures to protect your personal information
- User-reported data may be shared with relevant authorities when necessary

4. PLATFORM LIMITATIONS
Please understand that Zecure:
- Provides predictive analysis but cannot prevent crimes
- Relies on publicly available data which may have limitations
- Requires internet connectivity for full functionality
- May not capture all criminal activities or safety concerns
- Accuracy depends on data quality and user participation

5. COMMUNITY PARTICIPATION
By using Zecure, you may:
- Report incidents and safety concerns
- Mark and verify safe locations
- Contribute to community safety awareness
- Receive alerts about potential safety risks in your area

6. COOPERATION WITH AUTHORITIES
- Relevant information may be shared with law enforcement agencies
- Users are encouraged to report serious crimes directly to police
- The platform supplements but does not replace traditional emergency services

7. LIABILITY AND DISCLAIMERS
- Zecure is provided "as is" without warranties
- We are not liable for decisions made based on platform information
- Users are responsible for their own safety and security
- Emergency situations should always be reported to proper authorities

8. TERMS MODIFICATIONS
We reserve the right to modify these terms. Users will be notified of significant changes and continued use implies acceptance.

9. ACCOUNT TERMINATION
We may suspend or terminate accounts that violate these terms or engage in harmful activities.

10. CONTACT INFORMATION
For questions about these terms or the platform, please contact our support team.

By clicking "I Agree," you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.''',
                    style: GoogleFonts.poppins(
                      fontSize: isWeb ? 14 : 13, // Slightly larger text on web
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              
              // Footer buttons - keep existing
              Container(
                padding: EdgeInsets.all(isWeb ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _agreedToTerms = true);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'I Agree',
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


Widget _buildRegistrationTypeSelector() {
  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registration Type',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _registrationType = 'simple'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _registrationType == 'simple' 
                        ? Colors.blue.shade50 
                        : Colors.grey.shade50,
                    border: Border.all(
                      color: _registrationType == 'simple' 
                          ? Colors.blue.shade600 
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        color: _registrationType == 'simple' 
                            ? Colors.blue.shade600 
                            : Colors.grey.shade600,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Simple',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _registrationType == 'simple' 
                              ? Colors.blue.shade600 
                              : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Quick signup',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _registrationType = 'verified'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _registrationType == 'verified' 
                        ? Colors.green.shade50 
                        : Colors.grey.shade50,
                    border: Border.all(
                      color: _registrationType == 'verified' 
                          ? Colors.green.shade600 
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: _registrationType == 'verified' 
                            ? Colors.green.shade600 
                            : Colors.grey.shade600,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Verified',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _registrationType == 'verified' 
                              ? Colors.green.shade600 
                              : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Email verification',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_registrationType == 'simple' || _registrationType == 'verified') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _registrationType == 'simple'
                    ? Text(
                        '• Instant access\n• Basic features\n• Quick setup',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.left,
                      )
                    : const SizedBox(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _registrationType == 'verified'
                    ? Text(
                        '• Password reset\n• Email notifications\n• Enhanced security',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.left,
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

 Future<void> _register() async {
  if (!_formKey.currentState!.validate()) return;
  
  if (!_agreedToTerms) {
    _showErrorSnackBar('Please agree to the Terms and Conditions to continue');
    return;
  }

  setState(() => _isLoading = true);
  try {
    final authService = AuthService(Supabase.instance.client);
    
    if (_registrationType == 'simple') {
      await authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        middleName: _middleNameController.text.trim().isEmpty 
            ? null 
            : _middleNameController.text.trim(),
        extName: _extNameController.text.trim().isEmpty 
            ? null 
            : _extNameController.text.trim(),
        bday: _selectedDate,
        gender: _selectedGender,
        contactNumber: _contactNumberController.text.trim().isEmpty
            ? null
            : _contactNumberController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
      }
    } else {
      // Updated verified registration with OTP
      await authService.signUpWithOTP(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        middleName: _middleNameController.text.trim().isEmpty 
            ? null 
            : _middleNameController.text.trim(),
        extName: _extNameController.text.trim().isEmpty 
            ? null 
            : _extNameController.text.trim(),
        bday: _selectedDate,
        gender: _selectedGender,
        contactNumber: _contactNumberController.text.trim().isEmpty
            ? null
            : _contactNumberController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _showOTPScreen = true;
          _pendingEmail = _emailController.text.trim();
        });
        _startResendTimer();
      }
    }
  } on AuthException catch (e) {
    // Handle specific AuthException errors with proper messages
    _showErrorSnackBar(e.message);
  } catch (error) {
    // Handle any other unexpected errors
    print('Registration error: $error'); // For debugging
    _showErrorSnackBar('Registration failed. Please try again.');
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

Future<void> _verifyOTP() async {
  final otp = _otpControllers.map((c) => c.text).join();
  if (otp.length != 6) {
    _showErrorSnackBar('Please enter the complete 6-digit code');
    return;
  }

  setState(() => _isLoading = true);
  try {
    final authService = AuthService(Supabase.instance.client);
    await authService.verifyOTP(
      email: _pendingEmail!,
      otp: otp,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MapScreen()),
      );
    }
  } catch (e) {
    _showErrorSnackBar('Invalid verification code. Please try again.');
    // Clear OTP fields
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes[0].requestFocus();
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

Future<void> _resendOTP() async {
  try {
    final authService = AuthService(Supabase.instance.client);
    await authService.resendOTP(email: _pendingEmail!);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification code sent again!'),
        backgroundColor: Colors.green,
      ),
    );
    _startResendTimer();
  } catch (e) {
    _showErrorSnackBar('Failed to resend code. Please try again.');
  }
}

Widget _buildOTPScreen(bool isWeb) {
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
          Icons.security_rounded,
          size: 80,
          color: Colors.blue.shade600,
        ),
        const SizedBox(height: 20),
        Text(
          'Enter Verification Code',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a 6-digit code to:',
          style: GoogleFonts.poppins(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _pendingEmail ?? '',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade600,
          ),
        ),
        const SizedBox(height: 30),
        
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
            onPressed: _isLoading ? null : _verifyOTP,
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
          onPressed: _canResendOTP ? _resendOTP : null,
          child: Text(
            _canResendOTP 
                ? 'Resend Code' 
                : 'Resend in ${_resendCountdown}s',
            style: GoogleFonts.poppins(
              color: _canResendOTP ? Colors.blue.shade600 : Colors.grey.shade500,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _showOTPScreen = false;
              _pendingEmail = null;
            });
            _resendTimer?.cancel();
          },
          child: Text(
            'Back to Registration',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    ),
  );
}


void _showErrorSnackBar(String message) {
  final bool isWeb = MediaQuery.of(context).size.width > 600;
  final screenWidth = MediaQuery.of(context).size.width;
  final double maxWidth = isWeb ? 550 : screenWidth * 0.92;
  
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
      margin: EdgeInsets.only(
        left: isWeb ? (screenWidth - maxWidth) / 2 : 16,
        right: isWeb ? (screenWidth - maxWidth) / 2 : 16,
        bottom: 16,
      ),
    ),
  );
}


  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _extNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactNumberController.dispose();
    _birthdayController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    TextInputType? keyboardType, // Add this
    void Function(String)? onChanged, // Add this
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType, // Add this
      onChanged: onChanged, // Add this
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
          child: Icon(
            icon,
            color: Colors.blue.shade600,
            size: 20,
          ),
        ),
        suffixIcon: suffixIcon,
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
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: GoogleFonts.poppins(),
      validator: validator,
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Gender',
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
          child: Icon(
            Icons.transgender_rounded,
            color: Colors.blue.shade600,
            size: 20,
          ),
        ),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      value: _selectedGender,
      style: GoogleFonts.poppins(color: Colors.black),
      items: const [
        DropdownMenuItem(value: 'Male', child: Text('Male')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
        DropdownMenuItem(value: 'LGBTQ+', child: Text('LGBTQ+')),
        DropdownMenuItem(value: 'Others', child: Text('Others')),
      ],
      onChanged: (value) => setState(() => _selectedGender = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your gender';
        }
        return null;
      },
    );
  }

@override
Widget build(BuildContext context) {
  final bool isWeb = MediaQuery.of(context).size.width > 600;
  final screenWidth = MediaQuery.of(context).size.width;
  
  // Expanded max width for better screen utilization
  final double maxWidth = isWeb ? 550 : screenWidth * 0.92;

return Scaffold(
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
                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: maxWidth),
                              child: Column(
                                children: [
                                  _buildHeader(isWeb),
                                  SizedBox(height: isWeb ? 28 : 24),
                                  // Show email verification screen or registration form
                              _showOTPScreen 
                                ? _buildOTPScreen(isWeb)
                                : _buildRegistrationForm(isWeb),
                                  SizedBox(height: isWeb ? 20 : 16),
                                  // Only show footer when not showing email verification
                                  if (!_showOTPScreen) _buildFooter(isWeb),
                                  const SizedBox(height: 16), // Extra bottom padding
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
    );
  }

  Widget _buildTermsCheckbox() {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Checkbox(
        value: _agreedToTerms,
        onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
        activeColor: Colors.blue.shade600,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms and Conditions',
                    style: GoogleFonts.poppins(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = _showTermsAndConditions,
                  ),
                  const TextSpan(text: ' of Zecure'),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildHeader(bool isWeb) {
  return Column(
    children: [
      // 🌐 Web layout (same as before)
      if (isWeb)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Stack(
            children: [
              // Back Button (left)
              Positioned(
                left: 0,
                top: 8,
                child: IconButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Centered Logo + Text
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/zecure.png',
                      height: 150,
                      width: 150,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(35),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          size: 35,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create Your Account',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join the Zecure community and help make Zamboanga safer',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      else
        // 📱 Mobile Layout (fixed alignment)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Back button (top-left)
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Centered logo
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Image.asset(
                      'assets/images/zecure.png',
                      height: 130,
                      width: 130,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 130,
                        width: 130,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(35),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          size: 35,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Texts
              Text(
                'Create Your Account',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Join the Zecure community and help make Zamboanga safer',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
    ],
  );
}


 Widget _buildRegistrationForm(bool isWeb) {
  return Container(
    width: double.infinity,
    constraints: isWeb 
      ? BoxConstraints(maxHeight: 600) // Fixed height for web
      : null, // No height constraint for mobile
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
    child: SingleChildScrollView( // Make entire form scrollable
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Personal Information Section - Now single column for both web and mobile
            _buildRegistrationTypeSelector(),
            _buildSectionTitle('Personal Information'),
            const SizedBox(height: 14),
            
            // Single column layout for personal information (same as mobile)
            _buildInputField(
              controller: _firstNameController,
              label: 'First Name',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _lastNameController,
              label: 'Last Name',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your last name';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _middleNameController,
              label: 'Middle Name (Optional)',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _extNameController,
              label: 'Ext Name (Optional)',
              icon: Icons.credit_card_outlined,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _birthdayController,
              label: 'Birthday',
              icon: Icons.calendar_today_rounded,
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (value) {
                if (_selectedDate == null) {
                  return 'Please select your birthday';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildGenderDropdown(),
            
            const SizedBox(height: 20),
            
            // Contact Information Section
            _buildSectionTitle('Contact Information'),
            const SizedBox(height: 14),
            
            _buildInputField(
              controller: _contactNumberController,
              label: 'Contact Number (Optional)',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                if (!value.startsWith('+63')) {
                  _contactNumberController.text = '+63';
                  _contactNumberController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _contactNumberController.text.length),
                  );
                }
                
                if (value.length > 13) {
                  _contactNumberController.text = value.substring(0, 13);
                  _contactNumberController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _contactNumberController.text.length),
                  );
                }
              },
              validator: (value) {
                if (value != null && value.isNotEmpty && value != '+63') {
                  if (!value.startsWith('+63') || value.length != 13) {
                    return 'Must be in format +63xxxxxxxxxx (11 digits total)';
                  }
                  String digits = value.substring(3);
                  if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
                    return 'Please enter valid digits after +63';
                  }
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // Account Information Section
            _buildSectionTitle('Account Information'),
            const SizedBox(height: 14),
            
            _buildInputField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.alternate_email_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a username';
                }
                if (value.length < 4) {
                  return 'Username must be at least 4 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 14),
            
            _buildInputField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 14),
            
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 14),
            
            _buildInputField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline_rounded,
              isPassword: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
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

            const SizedBox(height: 20),
            _buildTermsCheckbox(),
            
            const SizedBox(height: 28),
            
            // Register Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
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
                          const Icon(Icons.person_add_rounded),
                          const SizedBox(width: 8),
                          Text(
                            'Create Account',
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
        ),
      ),
    ),
  );
}

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildFooter(bool isWeb) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            "Already have an account? ",
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Sign In',
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