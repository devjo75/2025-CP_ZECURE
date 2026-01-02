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
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResendOTP = false;

  String _registrationType = 'simple'; // 'simple' or 'verified'

  // =====================================================
  // WMSU-SPECIFIC STATE VARIABLES
  // =====================================================

  // User affiliation selection
  String _userAffiliation =
      'general_public'; // 'general_public', 'wmsu_student', 'wmsu_parent', 'wmsu_employee'

  // WMSU common fields
  final _wmsuIdNumberController = TextEditingController();

  // Student-specific fields
  String?
  _selectedEducationLevel; // 'primary', 'secondary', 'senior_high', 'college', 'graduate_studies'
  final _wmsuYearLevelController = TextEditingController();
  String? _selectedCollege;
  final _wmsuDepartmentController = TextEditingController();
  String? _selectedTrackStrand;
  final _wmsuSectionController = TextEditingController();

  // Parent-specific fields
  List<String> _linkedStudentIds = [];

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
    _contactNumberController.text = '+63';
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // Default to 18 years ago
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
            horizontal: isWeb ? MediaQuery.of(context).size.width * 0.25 : 20,
            vertical: 40,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: 600,
              maxWidth: isWeb ? 600 : double.infinity,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWeb ? 24 : 20),
                    child: Text(
                      '''Welcome to Zecure

By creating an account and using Zecure, you agree to the following terms and conditions:

1. SERVICE DESCRIPTION
Zecure is a cross-platform crime reporting and mapping system designed to enhance public safety in Zamboanga City by:
- Providing a centralized platform for submitting geo-located crime and incident reports
- Enabling police verification of submitted reports before public display
- Displaying verified crime incidents and safe spots on an interactive map
- Offering discussion threads attached to verified reports for community engagement
- Providing safe route recommendations that avoid high-risk areas
- Delivering real-time push notifications about verified incidents near your location
- Allowing citizens to mark and share safe spot locations

2. USER RESPONSIBILITIES
You agree to:
- Provide accurate and truthful information during registration and when submitting reports
- Use standardized crime classification and severity selection when reporting incidents
- Report incidents truthfully and in good faith
- Use the platform responsibly and in accordance with local laws
- Respect the privacy and safety of other users
- Not misuse the platform for illegal activities, false reporting, or harassment
- Participate constructively in discussion threads attached to verified reports
- Not submit duplicate reports for the same incident

3. DATA COLLECTION AND PRIVACY
- We collect personal information necessary for account creation and service provision
- Crime and incident data is collected from user reports and historical crime data
- Your location data is used to provide geo-located reporting, safe route planning, and proximity-based alerts
- We implement security measures to protect your personal information
- User-reported data undergoes police verification before public display
- Verified reports and related discussions may be visible to all users
- Relevant information may be shared with law enforcement agencies when necessary

4. REPORTING AND VERIFICATION PROCESS
- All submitted crime reports require police verification before appearing on the public map
- Police officers have the authority to approve, reject, or modify submitted reports
- The system includes duplicate detection to prevent multiple reports of the same incident
- Only police-verified incidents will be displayed on the public crime map
- Report accuracy depends on the quality of citizen submissions and police verification

5. PLATFORM LIMITATIONS
Please understand that Zecure:
- Does not predict future crimes or prevent criminal activities
- Relies on user reports and police verification, which may have delays
- Requires internet connectivity for real-time features and notifications
- Map accuracy depends entirely on police verification and citizen report accuracy
- May not capture all criminal activities or safety concerns in Zamboanga City
- Effectiveness depends on active citizen participation in reporting and safe spot marking
- Is currently available on Web and Android only (iOS not supported)

6. COMMUNITY PARTICIPATION FEATURES
By using Zecure, you can:
- Submit geo-located crime and incident reports with standardized classifications
- Participate in structured discussion threads attached to verified reports
- Share contextual information, additional details, and related experiences
- Mark and verify safe spot locations for community benefit
- Receive real-time notifications about verified incidents near your location
- Access safe route recommendations based on verified crime data
- View an interactive map of police-verified incidents and safe spots

7. COOPERATION WITH AUTHORITIES
- All reports are reviewed and verified by police officers before public display
- Relevant information will be shared with law enforcement agencies
- Users are encouraged to report serious crimes directly to police through official channels (911)
- The platform supplements but does not replace traditional emergency services
- Emergency situations should always be reported to proper authorities immediately

8. SAFE ROUTE FEATURE
- Safe route recommendations avoid areas with high crime rates and active incidents
- Route suggestions are based on verified crime data and may change in real-time
- Users are responsible for their own safety decisions when following route recommendations
- The system cannot guarantee complete safety along any suggested route

9. DISCUSSION THREADS AND COMMUNITY ENGAGEMENT
- Discussion threads are tied to verified reports for focused, relevant conversations
- Users must maintain respectful and constructive discourse in all discussions
- False information, harassment, or inappropriate content in discussions may result in account suspension
- Police and community members can provide official updates through discussion threads

10. LIABILITY AND DISCLAIMERS
- Zecure is provided "as is" without warranties
- We are not liable for decisions made based on platform information
- Users are responsible for their own safety and security
- Emergency situations should always be reported to proper authorities
- The platform does not guarantee crime prevention or personal safety

11. TERMS MODIFICATIONS
We reserve the right to modify these terms. Users will be notified of significant changes and continued use implies acceptance of the updated terms.

12. ACCOUNT TERMINATION
We may suspend or terminate accounts that:
- Submit false or misleading reports
- Violate these terms and conditions
- Engage in harmful activities or harassment
- Misuse the platform for illegal purposes

13. CONTACT INFORMATION
For questions about these terms or the platform, please contact our support team through the application.

14. GEOGRAPHIC COVERAGE
This service is specifically designed for Zamboanga City. Crime data, safe routes, and incident reporting are focused on this coverage area.

By clicking "I Agree," you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions. You understand that Zecure is a community-driven platform that relies on police verification and citizen participation to enhance public safety in Zamboanga City.''',
                      style: GoogleFonts.poppins(
                        fontSize: isWeb ? 14 : 13,
                        height: 1.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),

                // Footer buttons
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
              // Simple Registration
              Expanded(
                child: Opacity(
                  opacity: _userAffiliation != 'general_public' ? 0.5 : 1.0,
                  child: GestureDetector(
                    onTap: _userAffiliation == 'general_public'
                        ? () => setState(() => _registrationType = 'simple')
                        : null,
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
                          if (_userAffiliation != 'general_public')
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'General Public only',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.red.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Verified Registration
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
                        if (_userAffiliation != 'general_public')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Required for WMSU',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_registrationType == 'simple' ||
              _registrationType == 'verified') ...[
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
      _showErrorSnackBar(
        'Please agree to the Terms and Conditions to continue',
      );
      return;
    }

    // Validate registration type for WMSU users
    if (_userAffiliation != 'general_public' &&
        _registrationType != 'verified') {
      _showErrorSnackBar('WMSU users must use verified registration');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = AuthService(Supabase.instance.client);

      // Prepare email - append @wmsu.edu.ph for WMSU students and employees
      String finalEmail = _emailController.text.trim();
      if (_userAffiliation == 'wmsu_student' ||
          _userAffiliation == 'wmsu_employee') {
        finalEmail = '${_emailController.text.trim()}@wmsu.edu.ph';
      }

      // Prepare WMSU-specific data
      String? wmsuIdNumber;
      String? wmsuEducationLevel;
      String? wmsuYearLevel;
      String? wmsuCollege;
      String? wmsuDepartment;
      String? wmsuTrackStrand;
      String? wmsuSection;
      List<String>? linkedStudentIds;

      // Populate WMSU fields based on affiliation
      if (_userAffiliation == 'wmsu_student') {
        wmsuIdNumber = _wmsuIdNumberController.text.trim();
        wmsuEducationLevel = _selectedEducationLevel;
        wmsuYearLevel = _wmsuYearLevelController.text.trim();

        if (_selectedEducationLevel == 'college' ||
            _selectedEducationLevel == 'graduate_studies') {
          wmsuCollege = _selectedCollege;
          wmsuDepartment = _wmsuDepartmentController.text.trim().isEmpty
              ? null
              : _wmsuDepartmentController.text.trim();
        }

        if (_selectedEducationLevel == 'senior_high') {
          wmsuTrackStrand = _selectedTrackStrand;
        }

        if (_selectedEducationLevel == 'primary' ||
            _selectedEducationLevel == 'secondary') {
          wmsuSection = _wmsuSectionController.text.trim().isEmpty
              ? null
              : _wmsuSectionController.text.trim();
        }
      } else if (_userAffiliation == 'wmsu_parent') {
        wmsuIdNumber = _wmsuIdNumberController.text.trim();
        linkedStudentIds = _linkedStudentIds.isEmpty ? null : _linkedStudentIds;
      } else if (_userAffiliation == 'wmsu_employee') {
        wmsuIdNumber = _wmsuIdNumberController.text.trim();
        wmsuDepartment = _wmsuDepartmentController.text.trim();
      }

      // Choose registration type (simple or verified)
      if (_registrationType == 'simple') {
        // Only for general public
        if (_userAffiliation == 'general_public') {
          await authService.signUpWithEmail(
            email: finalEmail,
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
            contactNumber: _contactNumberController.text.trim(),
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MapScreen()),
            );
          }
        } else {
          _showErrorSnackBar('WMSU users must use verified registration');
          return;
        }
      } else {
        // Verified registration
        if (_userAffiliation == 'general_public') {
          await authService.signUpWithOTP(
            email: finalEmail,
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
            contactNumber: _contactNumberController.text.trim(),
          );
        } else {
          // For WMSU users with verification
          await authService.signUpWMSUVerified(
            email: finalEmail,
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
            contactNumber: _contactNumberController.text.trim(),
            userType: _userAffiliation,
            wmsuIdNumber: wmsuIdNumber!,
            wmsuEducationLevel: wmsuEducationLevel,
            wmsuYearLevel: wmsuYearLevel,
            wmsuCollege: wmsuCollege,
            wmsuDepartment: wmsuDepartment,
            wmsuTrackStrand: wmsuTrackStrand,
            wmsuSection: wmsuSection,
            linkedStudentIds: linkedStudentIds,
          );
        }

        if (mounted) {
          setState(() {
            _showOTPScreen = true;
            _pendingEmail = finalEmail;
          });
          _startResendTimer();
        }
      }
    } on AuthException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (error) {
      print('Registration error: $error');
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
      await authService.verifyOTP(email: _pendingEmail!, otp: otp);

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
          Icon(Icons.security_rounded, size: 80, color: Colors.blue.shade600),
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
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
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
              _canResendOTP ? 'Resend Code' : 'Resend in ${_resendCountdown}s',
              style: GoogleFonts.poppins(
                color: _canResendOTP
                    ? Colors.blue.shade600
                    : Colors.grey.shade500,
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
    _wmsuIdNumberController.dispose();
    _wmsuYearLevelController.dispose();
    _wmsuDepartmentController.dispose();
    _wmsuSectionController.dispose();

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
          child: Icon(icon, color: Colors.blue.shade600, size: 20),
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      value: _selectedGender,
      style: GoogleFonts.poppins(color: Colors.black),
      items: const [
        DropdownMenuItem(value: 'Male', child: Text('Male')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
        DropdownMenuItem(value: 'LGBTQ+', child: Text('LGBTQ+')),
        DropdownMenuItem(value: 'Others', child: Text('Prefer not to say')),
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
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withOpacity(0.2),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
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
                                _showOTPScreen
                                    ? _buildOTPScreen(isWeb)
                                    : _buildRegistrationForm(isWeb),
                                SizedBox(height: isWeb ? 20 : 16),
                                if (!_showOTPScreen) _buildFooter(isWeb),
                                const SizedBox(height: 16),
                              ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
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
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
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
          ? BoxConstraints(maxHeight: 700)
          : null, // Increased height
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Registration Type Selector (existing)
              _buildRegistrationTypeSelector(),

              // USER AFFILIATION SELECTOR (NEW)
              _buildUserAffiliationSelector(),

              // Show WMSU-specific fields based on affiliation
              if (_userAffiliation == 'wmsu_student') _buildWMSUStudentFields(),
              if (_userAffiliation == 'wmsu_parent') _buildWMSUParentFields(),
              if (_userAffiliation == 'wmsu_employee')
                _buildWMSUEmployeeFields(),

              // Personal Information Section
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
                label: 'Contact Number',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (!value.startsWith('+63')) {
                    _contactNumberController.text = '+63';
                    _contactNumberController.selection =
                        TextSelection.fromPosition(
                          TextPosition(
                            offset: _contactNumberController.text.length,
                          ),
                        );
                  }

                  if (value.length > 13) {
                    _contactNumberController.text = value.substring(0, 13);
                    _contactNumberController.selection =
                        TextSelection.fromPosition(
                          TextPosition(
                            offset: _contactNumberController.text.length,
                          ),
                        );
                  }
                },
                validator: (value) {
                  // First check if empty
                  if (value == null || value.isEmpty || value == '+63') {
                    return 'Please enter your contact number';
                  }

                  // Then validate format
                  if (!value.startsWith('+63') || value.length != 13) {
                    return 'Must be in format +63xxxxxxxxxx (11 digits total)';
                  }

                  String digits = value.substring(3);
                  if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
                    return 'Please enter valid digits after +63';
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

              // Email field - different for WMSU vs General Public
              if (_userAffiliation == 'wmsu_student' ||
                  _userAffiliation == 'wmsu_employee')
                // WMSU Email with fixed domain
                _buildWMSUEmailField()
              else
                // Regular email for general public
                _buildInputField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

              // Info box for WMSU users
              if (_userAffiliation == 'wmsu_student' ||
                  _userAffiliation == 'wmsu_employee') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enter your WMSU email address. @wmsu.edu.ph will be added automatically.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              _buildInputField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                isPassword: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
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
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
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

  Widget _buildWMSUEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _emailController.text.contains('@')
                  ? Colors.red.shade400
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey.shade50,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.email_outlined,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),

                // Expanded input field (username only)
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'sl201101795',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 8,
                      ),
                      isDense: true,
                      errorStyle: const TextStyle(
                        height: 0,
                      ), // Hide inline error
                    ),
                    style: GoogleFonts.poppins(fontSize: 14),
                    onChanged: (value) {
                      setState(() {}); // Trigger rebuild to show error
                      // Remove @ symbol and anything after it
                      if (value.contains('@')) {
                        String cleanValue = value.split('@')[0];
                        _emailController.value = TextEditingValue(
                          text: cleanValue,
                          selection: TextSelection.collapsed(
                            offset: cleanValue.length,
                          ),
                        );
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.contains('@')) {
                        return 'Invalid';
                      }
                      // Validate email username format
                      if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(value)) {
                        return 'Invalid';
                      }
                      if (value.length < 3) {
                        return 'Too short';
                      }
                      return null;
                    },
                  ),
                ),

                // Fixed non-editable domain
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(right: 16, left: 4),
                  child: Text(
                    '@wmsu.edu.ph',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Custom error message below the field
        if (_emailController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (_emailController.text.contains('@'))
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Do not include @wmsu.edu.ph, it will be added automatically',
                    style: GoogleFonts.poppins(
                      color: Colors.red.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else if (!RegExp(
            r'^[a-zA-Z0-9._-]+$',
          ).hasMatch(_emailController.text))
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Only letters, numbers, dots, and underscores allowed',
                    style: GoogleFonts.poppins(
                      color: Colors.red.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else if (_emailController.text.length < 3)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Email must be at least 3 characters',
                    style: GoogleFonts.poppins(
                      color: Colors.red.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
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

  // =====================================================
  // USER AFFILIATION SELECTOR
  // =====================================================

  Widget _buildUserAffiliationSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Affiliation',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          // General Public Option
          _buildAffiliationOption(
            value: 'general_public',
            icon: Icons.people_outline_rounded,
            title: 'General Public',
            subtitle: 'Standard user account',
            color: Colors.blue,
          ),

          const SizedBox(height: 8),

          // WMSU Student Option
          _buildAffiliationOption(
            value: 'wmsu_student',
            icon: Icons.school_rounded,
            title: 'WMSU Student',
            subtitle: 'Primary to Graduate level',
            color: Colors.green,
          ),

          const SizedBox(height: 8),

          // WMSU Parent Option
          _buildAffiliationOption(
            value: 'wmsu_parent',
            icon: Icons.family_restroom_rounded,
            title: 'WMSU Parent',
            subtitle: 'Track your children',
            color: Colors.orange,
          ),

          const SizedBox(height: 8),

          // WMSU Employee Option
          _buildAffiliationOption(
            value: 'wmsu_employee',
            icon: Icons.badge_rounded,
            title: 'WMSU Employee',
            subtitle: 'Faculty or staff',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliationOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final bool isSelected = _userAffiliation == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _userAffiliation = value;

          // Automatically switch to verified registration for WMSU users
          if (value != 'general_public') {
            _registrationType = 'verified';
          }

          // Clear email controller when switching to/from WMSU users
          _emailController.clear(); // ADD THIS LINE
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? color : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  // Add verification requirement notice for WMSU users
                  if (value != 'general_public')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Requires email verification',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.orange.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // WMSU STUDENT FIELDS
  // =====================================================

  Widget _buildWMSUStudentFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),

        // WMSU ID Number
        _buildInputField(
          controller: _wmsuIdNumberController,
          label: 'WMSU Student ID',
          icon: Icons.badge_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your student ID';
            }
            return null;
          },
        ),

        const SizedBox(height: 14),

        // Education Level Dropdown
        _buildEducationLevelDropdown(),

        const SizedBox(height: 14),

        // Year Level
        _buildInputField(
          controller: _wmsuYearLevelController,
          label: _getYearLevelLabel(),
          icon: Icons.calendar_today_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your year/grade level';
            }
            return null;
          },
        ),

        // Show additional fields based on education level
        if (_selectedEducationLevel == 'senior_high') ...[
          const SizedBox(height: 14),
          _buildTrackStrandDropdown(),
        ],

        if (_selectedEducationLevel == 'college' ||
            _selectedEducationLevel == 'graduate_studies') ...[
          const SizedBox(height: 14),
          _buildCollegeDropdown(),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _wmsuDepartmentController,
            label: 'Program/Course (Optional)',
            icon: Icons.school_outlined,
          ),
        ],

        if (_selectedEducationLevel == 'primary' ||
            _selectedEducationLevel == 'secondary') ...[
          const SizedBox(height: 14),
          _buildInputField(
            controller: _wmsuSectionController,
            label: 'Section (Optional)',
            icon: Icons.group_outlined,
          ),
        ],
      ],
    );
  }

  // =====================================================
  // WMSU PARENT FIELDS
  // =====================================================

  Widget _buildWMSUParentFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),

        // Parent ID
        _buildInputField(
          controller: _wmsuIdNumberController,
          label: 'Parent ID Number',
          icon: Icons.badge_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your parent ID';
            }
            return null;
          },
        ),

        const SizedBox(height: 14),

        // Info box about linking students
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can link your children\'s accounts after registration',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =====================================================
  // WMSU EMPLOYEE FIELDS
  // =====================================================

  Widget _buildWMSUEmployeeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),

        // Employee ID
        _buildInputField(
          controller: _wmsuIdNumberController,
          label: 'Employee ID Number',
          icon: Icons.badge_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your employee ID';
            }
            return null;
          },
        ),

        const SizedBox(height: 14),

        // Department/Office
        _buildInputField(
          controller: _wmsuDepartmentController,
          label: 'Department/Office',
          icon: Icons.business_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your department';
            }
            return null;
          },
        ),
      ],
    );
  }

  // =====================================================
  // DROPDOWN BUILDERS
  // =====================================================

  Widget _buildEducationLevelDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Education Level',
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
            Icons.school_outlined,
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      value: _selectedEducationLevel,
      style: GoogleFonts.poppins(color: Colors.black),
      items: [
        DropdownMenuItem(value: 'primary', child: Text('Primary (Elementary)')),
        DropdownMenuItem(
          value: 'secondary',
          child: Text('Secondary (Junior High)'),
        ),
        DropdownMenuItem(
          value: 'senior_high',
          child: Text('Senior High School'),
        ),
        DropdownMenuItem(
          value: 'college',
          child: Text('College (Undergraduate)'),
        ),
        DropdownMenuItem(
          value: 'graduate_studies',
          child: Text('Graduate Studies'),
        ),
      ],
      onChanged: (value) => setState(() {
        _selectedEducationLevel = value;
        // Clear dependent fields when education level changes
        _selectedCollege = null;
        _selectedTrackStrand = null;
        _wmsuYearLevelController.clear();
      }),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your education level';
        }
        return null;
      },
    );
  }

  Widget _buildCollegeDropdown() {
    final authService = AuthService(Supabase.instance.client);
    final colleges = authService.getWMSUColleges();

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'College/School',
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
            Icons.account_balance_rounded,
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      value: _selectedCollege,
      style: GoogleFonts.poppins(color: Colors.black),
      items: colleges.map((college) {
        return DropdownMenuItem(value: college, child: Text(college));
      }).toList(),
      onChanged: (value) => setState(() => _selectedCollege = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your college';
        }
        return null;
      },
    );
  }

  Widget _buildTrackStrandDropdown() {
    final authService = AuthService(Supabase.instance.client);
    final tracks = authService.getSeniorHighTracks();

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Track/Strand',
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
            Icons.route_rounded,
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      value: _selectedTrackStrand,
      style: GoogleFonts.poppins(color: Colors.black, fontSize: 13),
      items: tracks.map((track) {
        return DropdownMenuItem(
          value: track.split(' - ')[0], // Store just "STEM", "HUMSS", etc.
          child: Text(track),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedTrackStrand = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your track/strand';
        }
        return null;
      },
    );
  }

  // Helper method to get appropriate year level label
  String _getYearLevelLabel() {
    switch (_selectedEducationLevel) {
      case 'primary':
      case 'secondary':
        return 'Grade Level (e.g., Grade 5)';
      case 'senior_high':
        return 'Grade Level (Grade 11 or 12)';
      case 'college':
        return 'Year Level (e.g., 3rd Year)';
      case 'graduate_studies':
        return 'Year Level (e.g., Year 2)';
      default:
        return 'Year/Grade Level';
    }
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
              MaterialPageRoute(builder: (context) => const LoginScreen()),
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
