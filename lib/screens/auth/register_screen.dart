import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zecure/screens/auth/login_screen.dart';
import 'package:zecure/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
  
  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

Future<void> _register() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);
  try {
    final authService = AuthService(Supabase.instance.client);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please login.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } on AuthException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    super.dispose();
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;
    final double formWidth = isWeb ? 600 : double.infinity;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              width: formWidth,
              padding: isWeb 
                  ? const EdgeInsets.symmetric(horizontal: 40, vertical: 32)
                  : null,
              decoration: isWeb
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!isWeb) const SizedBox(height: 40),
                    // Logo
                    Image.asset(
                      'assets/images/zecure.png',
                      height: isWeb ? 120 : 150,
                      width: isWeb ? 120 : 150,
                    ),
                    const SizedBox(height: 24),
                    // Title
                    Text(
                      'Create an Account',
                      style: GoogleFonts.poppins(
                        fontSize: isWeb ? 24 : 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

if (isWeb) ...[
  // Web View - Single Column Layout with internal scrolling
  ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.8,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFormField(
            controller: _firstNameController,
            labelText: 'First Name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your first name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildFormField(
            controller: _lastNameController,
            labelText: 'Last Name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your last name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildFormField(
            controller: _middleNameController,
            labelText: 'Middle Name (Optional)',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            controller: _extNameController,
            labelText: 'Ext Name (Optional)',
            icon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            controller: TextEditingController(),
            labelText: 'Birthday',
            icon: Icons.calendar_today,
            readOnly: true,
            onTap: () => _selectDate(context),
            validator: (value) {
              if (_selectedDate == null) {
                return 'Please select your birthday';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Gender',
              prefixIcon: const Icon(Icons.transgender),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            ),
            value: _selectedGender,
            items: const [
              DropdownMenuItem(
                value: 'Male',
                child: Text('Male'),
              ),
              DropdownMenuItem(
                value: 'Female',
                child: Text('Female'),
              ),
              DropdownMenuItem(
                value: 'LGBTQ+',
                child: Text('LGBTQ+'),
              ),
              DropdownMenuItem(
                value: 'Others',
                child: Text('Others'),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedGender = value);
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your gender';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildFormField(
            controller: _contactNumberController,
            labelText: 'Contact Number',
            icon: Icons.phone,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^\+?[\d\s\-]{10,}$').hasMatch(value)) {
                  return 'Please enter a valid phone number';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildFormField(
            controller: _usernameController,
            labelText: 'Username',
            icon: Icons.alternate_email,
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
          const SizedBox(height: 16),
          _buildFormField(
            controller: _emailController,
            labelText: 'Email',
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
          const SizedBox(height: 16),
          _buildFormField(
            controller: _passwordController,
            labelText: 'Password',
            icon: Icons.lock_outlined,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
          const SizedBox(height: 16),
          _buildFormField(
            controller: _confirmPasswordController,
            labelText: 'Confirm Password',
            icon: Icons.lock_outlined,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
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
          const SizedBox(height: 24),
        ],
      ),
    ),
  ),
] else ...[
                      // Mobile View - Single Column Layout
                      _buildFormField(
                        controller: _firstNameController,
                        labelText: 'First Name',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        controller: _lastNameController,
                        labelText: 'Last Name',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        controller: _middleNameController,
                        labelText: 'Middle Name (Optional)',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        controller: _extNameController,
                        labelText: 'Ext Name (Optional)',
                        icon: Icons.credit_card_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
    controller: TextEditingController(),
    labelText: 'Birthday',
    icon: Icons.calendar_today,
    readOnly: true,
    onTap: () => _selectDate(context),
    validator: (value) {
      if (_selectedDate == null) {
        return 'Please select your birthday';
      }
      return null;
    },
  ),
  const SizedBox(height: 16),
  DropdownButtonFormField<String>(
    decoration: InputDecoration(
      labelText: 'Gender',
      prefixIcon: const Icon(Icons.transgender),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    value: _selectedGender,
    items: const [
      DropdownMenuItem(
        value: 'Male',
        child: Text('Male'),
      ),
      DropdownMenuItem(
        value: 'Female',
        child: Text('Female'),
      ),
      DropdownMenuItem(
        value: 'LGBTQ+',
        child: Text('LGBTQ+'),
      ),
      DropdownMenuItem(
        value: 'Others',
        child: Text('Others'),
      ),
    ],
    onChanged: (value) {
      setState(() => _selectedGender = value);
    },
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Please select your gender';
      }
      return null;
    },
  ),
  const SizedBox(height: 16),
  _buildFormField(
    controller: _contactNumberController,
    labelText: 'Contact Number',
    icon: Icons.phone,
    validator: (value) {
      if (value != null && value.isNotEmpty) {
        if (!RegExp(r'^\+?[\d\s\-]{10,}$').hasMatch(value)) {
          return 'Please enter a valid phone number';
        }
      }
      return null;
    },
  ),
  const SizedBox(height: 16),
                      _buildFormField(
                        controller: _usernameController,
                        labelText: 'Username',
                        icon: Icons.alternate_email,
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
                      const SizedBox(height: 16),
                      _buildFormField(
                        controller: _emailController,
                        labelText: 'Email',
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
                      const SizedBox(height: 16),
                      _buildFormField(
                        controller: _passwordController,
                        labelText: 'Password',
                        icon: Icons.lock_outlined,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                      const SizedBox(height: 16),
                      _buildFormField(
                        controller: _confirmPasswordController,
                        labelText: 'Confirm Password',
                        icon: Icons.lock_outlined,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
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
                    ],
                    const SizedBox(height: 24),
                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                'Register',
                                style: GoogleFonts.poppins(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account?",
                          style: GoogleFonts.poppins(),
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
                          child: Text(
                            'Login',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}