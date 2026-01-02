import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zecure/auth/login_screen.dart';
import 'package:zecure/screens/map_screen.dart';
import 'package:zecure/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';

class DesktopRegisterScreen extends StatefulWidget {
  const DesktopRegisterScreen({super.key});

  @override
  State<DesktopRegisterScreen> createState() => _DesktopRegisterScreenState();
}

class _DesktopRegisterScreenState extends State<DesktopRegisterScreen>
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
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _obscureConfirmPassword = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;

  // Registration type and affiliation
  String _registrationType = 'simple';
  String _userAffiliation = 'general_public';
  final _wmsuIdNumberController = TextEditingController();

  // OTP verification state
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

  // Current step in registration
  int _currentStep = 0;
  final _pageController = PageController();

  // ADD THESE NEW VARIABLES FOR CAROUSEL
  int _currentFeatureIndex = 0;
  Timer? _carouselTimer;
  bool _isCarouselPlaying = true;
  final PageController _featurePageController = PageController();

  // ADD THIS FEATURES LIST
  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.map_rounded,
      'title': 'Live Crime Map',
      'description':
          'View verified incidents in real-time on an interactive map. Stay informed about what\'s happening in your area.',
    },
    {
      'icon': Icons.report_rounded,
      'title': 'Report Incidents',
      'description':
          'Submit geo-located crime reports instantly. Your reports help keep the community informed and safe.',
    },
    {
      'icon': Icons.route_rounded,
      'title': 'Safe Path Routing',
      'description':
          'Navigate safer routes in Zamboanga City. Avoid high-risk areas and active crime zones automatically.',
    },
    {
      'icon': Icons.verified_rounded,
      'title': 'Police-Verified Data',
      'description':
          'Trust in officially confirmed reports. All incidents are verified by law enforcement before display.',
    },
    {
      'icon': Icons.forum_rounded,
      'title': 'Community Discussion',
      'description':
          'Share insights and context on verified incidents. Collaborate with neighbors to enhance safety awareness.',
    },
    {
      'icon': Icons.notifications_active_rounded,
      'title': 'Real-Time Alerts',
      'description':
          'Receive instant notifications about verified incidents near your location. Stay alert, stay safe.',
    },
  ];

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

    _contactNumberController.text = '+63';
    _fadeController.forward();
    _slideController.forward();

    _updateRegistrationType();

    // ADD THIS LINE
    _startCarousel();
  }

  void _updateRegistrationType() {
    if (_userAffiliation != 'general_public') {
      setState(() {
        _registrationType = 'verified';
      });
    }
  }

  // ADD THESE TWO NEW METHODS
  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_isCarouselPlaying && _featurePageController.hasClients) {
        int nextPage = (_currentFeatureIndex + 1) % _features.length;
        _featurePageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _toggleCarousel() {
    setState(() {
      _isCarouselPlaying = !_isCarouselPlaying;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
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
    _wmsuIdNumberController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _resendTimer?.cancel();

    // ADD THESE TWO LINES
    _carouselTimer?.cancel();
    _featurePageController.dispose();

    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
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

  bool _canProceedFromStep0() {
    return true;
  }

  bool _canProceedFromStep1() {
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _birthdayController.text.trim().isNotEmpty &&
        _selectedGender != null &&
        _contactNumberController.text.trim().isNotEmpty &&
        _contactNumberController.text.trim() != '+63'; // 👈 Add this check
  }

  bool _canProceedFromStep2() {
    bool basicFieldsFilled =
        _usernameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty &&
        _confirmPasswordController.text.trim().isNotEmpty;

    if (_userAffiliation != 'general_public') {
      return basicFieldsFilled &&
          _wmsuIdNumberController.text.trim().isNotEmpty;
    }

    return basicFieldsFilled;
  }

  void _nextStep() {
    // Trigger validation for current step
    if (_currentStep == 1 || _currentStep == 2) {
      // Validate the form to show errors on fields
      if (!_formKey.currentState!.validate()) {
        setState(() {
          _autovalidateMode =
              AutovalidateMode.onUserInteraction; // 👈 Enable auto-validation
        });
        return; // Stop here if validation fails
      }
    }

    bool canProceed = false;

    switch (_currentStep) {
      case 0:
        canProceed = _canProceedFromStep0();
        break;
      case 1:
        canProceed = _canProceedFromStep1();
        break;
      case 2:
        canProceed = _canProceedFromStep2();
        break;
    }

    if (_currentStep < 2 && canProceed) {
      setState(() {
        _currentStep++;
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
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
      _showSuccessSnackBar('Verification code sent again!');
      _startResendTimer();
    } catch (e) {
      _showErrorSnackBar('Failed to resend code. Please try again.');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      _showErrorSnackBar('Please agree to the Terms and Conditions');
      return;
    }

    if (_userAffiliation != 'general_public' &&
        _registrationType != 'verified') {
      _showErrorSnackBar('WMSU users must use verified registration');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService(Supabase.instance.client);

      String finalEmail = _emailController.text.trim();
      if (_userAffiliation == 'wmsu_student' ||
          _userAffiliation == 'wmsu_employee') {
        finalEmail = '${_emailController.text.trim()}@wmsu.edu.ph';
      }

      if (_registrationType == 'simple') {
        if (_userAffiliation == 'general_public') {
          await authService.signUpWithEmail(
            email: finalEmail,
            password: _passwordController.text.trim(),
            username: _usernameController.text.trim(),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            middleName: _middleNameController.text.trim().isNotEmpty
                ? _middleNameController.text.trim()
                : null,
            extName: _extNameController.text.trim().isNotEmpty
                ? _extNameController.text.trim()
                : null,
            bday: _selectedDate,
            gender: _selectedGender,
            contactNumber: _contactNumberController.text.trim(),
          );

          if (mounted) {
            _showSuccessSnackBar('Registration successful! Redirecting...');
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              }
            });
          }
        } else {
          _showErrorSnackBar('WMSU users must use verified registration');
          return;
        }
      } else {
        if (_userAffiliation == 'general_public') {
          await authService.signUpWithOTP(
            email: finalEmail,
            password: _passwordController.text.trim(),
            username: _usernameController.text.trim(),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            middleName: _middleNameController.text.trim().isNotEmpty
                ? _middleNameController.text.trim()
                : null,
            extName: _extNameController.text.trim().isNotEmpty
                ? _extNameController.text.trim()
                : null,
            bday: _selectedDate,
            gender: _selectedGender,
            contactNumber: _contactNumberController.text.trim(),
          );
        } else {
          await authService.signUpWMSUVerified(
            email: finalEmail,
            password: _passwordController.text.trim(),
            username: _usernameController.text.trim(),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            middleName: _middleNameController.text.trim().isNotEmpty
                ? _middleNameController.text.trim()
                : null,
            extName: _extNameController.text.trim().isNotEmpty
                ? _extNameController.text.trim()
                : null,
            bday: _selectedDate,
            gender: _selectedGender,
            contactNumber: _contactNumberController.text.trim(),
            userType: _userAffiliation,
            wmsuIdNumber: _wmsuIdNumberController.text.trim(),
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
    } on AuthException catch (error) {
      _showErrorSnackBar(error.message);
    } catch (error) {
      _showErrorSnackBar('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
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
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Show OTP verification modal
    if (_showOTPScreen) {
      return _buildOTPModal();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/LIGHT.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // Blue tinted overlay
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withOpacity(0.2),
          ),
          child: Row(
            children: [
              // Left Side - Enhanced Branding/Welcome Section
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(60),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Logo without container
                            Image.asset(
                              'assets/images/zecure.png',
                              height: 300,
                              width: 300,
                            ),
                            const SizedBox(height: 20),

                            // Main Title
                            Text(
                              'Join ZECURE',
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Tagline
                            Text(
                              'Your Safety, Our Priority',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Subtitle
                            Text(
                              'Zamboanga City\'s Community Safety Platform',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Feature Carousel
                            Container(
                              padding: const EdgeInsets.all(20),
                              height: 240,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Carousel
                                  Expanded(
                                    child: PageView.builder(
                                      controller: _featurePageController,
                                      onPageChanged: (index) {
                                        setState(() {
                                          _currentFeatureIndex = index;
                                        });
                                      },
                                      itemCount: _features.length,
                                      itemBuilder: (context, index) {
                                        final feature = _features[index];
                                        return Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                feature['icon'],
                                                color: Colors.blue.shade700,
                                                size: 36,
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              feature['title'],
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade900,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 10),
                                            Flexible(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                child: Text(
                                                  feature['description'],
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.grey.shade700,
                                                    height: 1.4,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Indicators and Controls
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Page Indicators
                                      ...List.generate(
                                        _features.length,
                                        (index) => Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: _currentFeatureIndex == index
                                              ? 20
                                              : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _currentFeatureIndex == index
                                                ? Colors.blue.shade600
                                                : Colors.grey.shade400,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Play/Pause Button
                                      InkWell(
                                        onTap: _toggleCarousel,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade600,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Icon(
                                            _isCarouselPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right Side - Registration Form
              Expanded(
                flex: 6,
                child: Container(
                  height: screenHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(-10, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Progress Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 35,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Step ${_currentStep + 1} of 3',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: (_currentStep + 1) / 3,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue.shade600,
                                      ),
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Form Content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 60),
                            child: Form(
                              key: _formKey,
                              autovalidateMode: _autovalidateMode,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getStepTitle(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getStepSubtitle(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 65),

                                  SizedBox(
                                    height: 520,
                                    child: PageView(
                                      controller: _pageController,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      children: [
                                        _buildStep0(),
                                        _buildStep1(),
                                        _buildStep2(),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 40),

                                  // Navigation Buttons
                                  Row(
                                    children: [
                                      if (_currentStep > 0)
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _previousStep,
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              side: BorderSide(
                                                color: Colors.blue.shade600,
                                                width: 2,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: Text(
                                              'Back',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_currentStep > 0)
                                        const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : (_currentStep < 2
                                                    ? _nextStep
                                                    : _register),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blue.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                )
                                              : Text(
                                                  _currentStep < 2
                                                      ? 'Continue'
                                                      : 'Create Account',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 35),

                                  // Sign In Link
                                  Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Already have an account? ",
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const LoginScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            'Sign In',
                                            style: GoogleFonts.poppins(
                                              color: Colors.blue.shade600,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
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

  Widget _buildOTPModal() {
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

          child: Center(
            child: Container(
              width: 500,
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      fontSize: 24,
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
                        width: 55,
                        height: 65,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextFormField(
                          controller: _otpControllers[index],
                          focusNode: _otpFocusNodes[index],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
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
                        padding: const EdgeInsets.symmetric(vertical: 18),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Verify Code',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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
            ),
          ),
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Account Type';
      case 1:
        return 'Basic Information';
      case 2:
        return 'Account Details';
      default:
        return '';
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Choose your registration type and affiliation';
      case 1:
        return 'Tell us about yourself';
      case 2:
        return 'Create your login credentials';
      default:
        return '';
    }
  }

  Widget _buildStep0() {
    return SingleChildScrollView(
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
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Simple',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: _registrationType == 'simple'
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Quick signup',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (_userAffiliation != 'general_public')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'General Public only',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
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
              const SizedBox(width: 16),
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
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verified',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: _registrationType == 'verified'
                                ? Colors.green.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Email verification',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_userAffiliation != 'general_public')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Required for WMSU',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
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
            const SizedBox(height: 12),
            Row(
              children: [
                // Left box for Simple
                if (_registrationType == 'simple')
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        '• Instant access\n• Basic features\n• Quick setup',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.6,
                        ),
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()), // Empty space on left

                const SizedBox(width: 12),

                // Right box for Verified
                if (_registrationType == 'verified')
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '• Password reset\n• Email notifications\n• Enhanced security',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.6,
                        ),
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()), // Empty space on right
              ],
            ),
          ],

          const SizedBox(height: 30),

          Text(
            'User Affiliation',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          // First row - General Public and WMSU Student
          Row(
            children: [
              Expanded(
                child: _buildAffiliationOption(
                  'general_public',
                  'General Public',
                  Icons.public_rounded,
                  'For community members',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAffiliationOption(
                  'wmsu_student',
                  'WMSU Student',
                  Icons.school_rounded,
                  'Requires WMSU student ID',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Second row - WMSU Parent and WMSU Employee
          Row(
            children: [
              Expanded(
                child: _buildAffiliationOption(
                  'wmsu_parent',
                  'WMSU Parent/Guardian',
                  Icons.family_restroom_rounded,
                  'Parent of WMSU student',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAffiliationOption(
                  'wmsu_employee',
                  'WMSU Employee',
                  Icons.badge_rounded,
                  'Faculty or staff member',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliationOption(
    String value,
    String title,
    IconData icon,
    String subtitle,
  ) {
    final isSelected = _userAffiliation == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _userAffiliation = value;
          _updateRegistrationType();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
              size: 28,
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
                      color: isSelected
                          ? Colors.blue.shade600
                          : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue.shade600, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'First Name',
                _firstNameController,
                Icons.person_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                'Last Name',
                _lastNameController,
                Icons.person_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'Middle Name (Optional)',
                _middleNameController,
                Icons.person_outline_rounded,
                isRequired: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 0,
              child: SizedBox(
                width: 120,
                child: _buildTextField(
                  'Ext. (Optional)',
                  _extNameController,
                  Icons.text_fields_rounded,
                  isRequired: false,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDateField(),
        const SizedBox(height: 16),
        _buildGenderDropdown(),
        const SizedBox(height: 16),

        // 👇 REPLACE the _buildTextField line with this full implementation:
        TextFormField(
          controller: _contactNumberController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Contact Number',
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
                Icons.phone_rounded,
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
              vertical: 16,
              horizontal: 16,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          onChanged: (value) {
            // Prevent deletion of +63 prefix
            if (!value.startsWith('+63')) {
              _contactNumberController.text = '+63';
              _contactNumberController.selection = TextSelection.fromPosition(
                TextPosition(offset: _contactNumberController.text.length),
              );
            }

            // Limit to 13 characters (+63 + 10 digits)
            if (value.length > 13) {
              _contactNumberController.text = value.substring(0, 13);
              _contactNumberController.selection = TextSelection.fromPosition(
                TextPosition(offset: _contactNumberController.text.length),
              );
            }
          },
          validator: (value) {
            // Check if empty or just +63
            if (value == null || value.isEmpty || value == '+63') {
              return 'Please enter your contact number';
            }

            // Check format and length
            if (!value.startsWith('+63') || value.length != 13) {
              return 'Must be in format +63xxxxxxxxxx';
            }

            // Check if remaining 10 characters are digits
            String digits = value.substring(3);
            if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
              return 'Please enter valid digits after +63';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        _buildTextField(
          'Username',
          _usernameController,
          Icons.account_circle_rounded,
        ),
        const SizedBox(height: 16),

        if (_userAffiliation == 'wmsu_student' ||
            _userAffiliation == 'wmsu_employee')
          _buildEmailFieldWithSuffix()
        else
          _buildTextField('Email', _emailController, Icons.email_rounded),

        const SizedBox(height: 16),
        _buildPasswordField(
          'Password',
          _passwordController,
          _obscurePassword,
          () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          'Confirm Password',
          _confirmPasswordController,
          _obscureConfirmPassword,
          () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
        ),
        const SizedBox(height: 16),

        if (_userAffiliation != 'general_public') ...[
          _buildTextField(
            'WMSU ID Number',
            _wmsuIdNumberController,
            Icons.badge_rounded,
          ),
          const SizedBox(height: 16),
        ],

        _buildTermsCheckbox(),
      ],
    );
  }

  Widget _buildEmailFieldWithSuffix() {
    return TextFormField(
      controller: _emailController,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Email',
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
            Icons.email_rounded,
            color: Colors.blue.shade600,
            size: 20,
          ),
        ),
        suffixText: '@wmsu.edu.ph',
        suffixStyle: GoogleFonts.poppins(
          color: Colors.grey.shade600,
          fontSize: 14,
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
          vertical: 18,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        return null;
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(fontSize: 14),
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
          vertical: 16,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Please enter your ${label.toLowerCase().replaceAll(' (optional)', '')}';
        }

        // Special validation for contact number
        if (label == 'Contact Number' && value != null && value.isNotEmpty) {
          if (value == '+63') {
            return 'Please enter your contact number';
          }
          if (!value.startsWith('+63') || value.length != 13) {
            return 'Must be in format +63xxxxxxxxxx';
          }
          String digits = value.substring(3);
          if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
            return 'Please enter valid digits after +63';
          }
        }

        return null;
      },
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscureText,
    VoidCallback onToggle,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.poppins(fontSize: 14),
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
            Icons.lock_rounded,
            color: Colors.blue.shade600,
            size: 20,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
          ),
          onPressed: onToggle,
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
          vertical: 16,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your ${label.toLowerCase()}';
        }
        if (label == 'Password' && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        if (label == 'Confirm Password' && value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _birthdayController,
      readOnly: true,
      onTap: () => _selectDate(context),
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Birthday',
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
            Icons.cake_rounded,
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
          vertical: 16,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your birthday';
        }
        return null;
      },
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
            Icons.people_rounded,
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
          vertical: 16,
          horizontal: 16,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      value: _selectedGender,
      style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
      items: const [
        DropdownMenuItem(value: 'Male', child: Text('Male')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
        DropdownMenuItem(value: 'LGBTQ+', child: Text('LGBTQ+')),
        DropdownMenuItem(value: 'Other', child: Text('Prefer not to say')),
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

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
          activeColor: Colors.blue.shade600,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms and Conditions',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _showTermsDialog();
                      },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by clicking outside
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 600),
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
                      const Icon(
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
                    padding: const EdgeInsets.all(24),
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
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),

                // Footer buttons
                Container(
                  padding: const EdgeInsets.all(24),
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
}
