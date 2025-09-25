import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);


//SIMPLE REGISTRATION
// Updated signUpWithEmail method
Future<AuthResponse> signUpWithEmail({
  required String email,
  required String password,
  required String username,
  required String firstName,
  required String lastName,
  String? middleName,
  String? extName,
  DateTime? bday,
  String? gender,
  String? contactNumber,
}) async {
  // Check if email already exists
  final existingEmail = await _supabase
      .from('users')
      .select('email')
      .eq('email', email)
      .maybeSingle();
      
  if (existingEmail != null) {
    throw const AuthException('Email already exists. Please use a different email address.');
  }

  // Check if username already exists
  final existingUser = await _supabase
      .from('users')
      .select('username')
      .eq('username', username)
      .maybeSingle();
      
  if (existingUser != null) {
    throw const AuthException('Username already exists. Please choose a different username.');
  }

  final response = await _supabase.auth.signUp(
    email: email,
    password: password,
    data: {
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'ext_name': extName,
      'bday': bday?.toIso8601String(),
      'gender': gender,
      'contact_number': contactNumber,
      'registration_type': 'simple',
    },
  );

  return response;
}

// Updated signUpWithOTP method
Future<AuthResponse> signUpWithOTP({
  required String email,
  required String password,
  required String username,
  required String firstName,
  required String lastName,
  String? middleName,
  String? extName,
  DateTime? bday,
  String? gender,
  String? contactNumber,
}) async {
  // Check if email already exists
  final existingEmail = await _supabase
      .from('users')
      .select('email')
      .eq('email', email)
      .maybeSingle();
      
  if (existingEmail != null) {
    throw const AuthException('Email already exists. Please use a different email address.');
  }

  // Check if username already exists
  final existingUser = await _supabase
      .from('users')
      .select('username')
      .eq('username', username)
      .maybeSingle();
      
  if (existingUser != null) {
    throw const AuthException('Username already exists. Please choose a different username.');
  }

  final response = await _supabase.auth.signUp(
    email: email,
    password: password,
    data: {
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'ext_name': extName,
      'bday': bday?.toIso8601String(),
      'gender': gender,
      'contact_number': contactNumber,
      'registration_type': 'verified',
    },
  );

  return response;
}

Future<bool> needsEmailVerification(String email) async {
  try {
    // Try to sign in to check if user exists and get their verification status
    final user = _supabase.auth.currentUser;
    if (user != null && user.email == email) {
      return user.emailConfirmedAt == null;
    }
    return false;
  } catch (e) {
    return false;
  }
}

// Replace resendEmailConfirmation with:
Future<ResendResponse> resendOTP({
  required String email,
}) async {
  return await _supabase.auth.resend(
    type: OtpType.signup,
    email: email,
  );
}

// Replace handleDeepLinkConfirmation with:
Future<AuthResponse> verifyOTP({
  required String email,
  required String otp,
}) async {
  try {
    final response = await _supabase.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: otp,
    );
    return response;
  } catch (e) {
    throw AuthException('OTP verification failed: ${e.toString()}');
  }
}

Future<AuthResponse> signInWithEmail({
  required String email,
  required String password,
}) async {
  return await _supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );
}

// FORGOT PASSWORD AND RESET

Future<void> resetPasswordWithOTP({
  required String email,
}) async {
  try {
    // First check if the email exists in our users table
    final existingUser = await _supabase
        .from('users')
        .select('email')
        .eq('email', email)
        .maybeSingle();
        
    if (existingUser == null) {
      throw const AuthException('No account found with this email address.');
    }

    // Only send OTP if user exists
    await _supabase.auth.resetPasswordForEmail(email);
  } catch (e) {
    // Log the actual error for debugging
    print('Password reset error: $e'); // Add this line
    rethrow;
  }
}


Future<AuthResponse> verifyPasswordResetOTP({
  required String email,
  required String otp,
}) async {
  try {
    final response = await _supabase.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: otp,
    );
    return response;
  } catch (e) {
    throw AuthException('OTP verification failed: ${e.toString()}');
  }
}

// Add this new method to handle reauthentication OTP verification:
Future<AuthResponse> verifyCurrentEmailOTP({
  required String email,
  required String otp,
}) async {
  try {
    // For reauthentication emails, we don't use verifyOTP at all
    // Instead, we use the reauthenticate method with the OTP
    
    // Method 1: Try using the session from reauthentication
    final response = await _supabase.auth.verifyOTP(
      type: OtpType.magiclink, // Reauthentication often uses magiclink type
      email: email,
      token: otp,
    );

    // After successful verification, update the registration type
    if (response.user != null) {
      await _supabase
          .from('users')
          .update({'registration_type': 'verified'})
          .eq('id', response.user!.id);
    }

    return response;
  } catch (e) {
    // If magiclink doesn't work, the reauthentication might use a different approach
    print('Reauthentication verification error: $e');
    throw AuthException('Email verification failed: ${e.toString()}');
  }
}

Future<void> updateEmailWithVerification({
  required String newEmail,
}) async {
  final user = _supabase.auth.currentUser;
  if (user == null) throw Exception('No user logged in');

  final currentEmail = user.email;

  // If it's the same email, use reauthentication instead
  if (currentEmail == newEmail) {
    await _supabase.auth.reauthenticate();
    return;
  }

  // Only check for existing email if it's a different email
  final existingUser = await _supabase
      .from('users')
      .select('email')
      .eq('email', newEmail)
      .maybeSingle();

  if (existingUser != null) {
    throw const AuthException('Email already exists. Please choose a different email.');
  }

  // Update email in auth (this will send verification automatically)
  await _supabase.auth.updateUser(
    UserAttributes(email: newEmail),
  );
}

// Add this method for resending reauthentication OTP:
Future<void> resendReauthenticationOTP({
  required String email,
}) async {
  await _supabase.auth.resend(
    type: OtpType.signup,
    email: email,
  );
}

Future<void> resendEmailChangeOTP({
  required String email,
}) async {
  await _supabase.auth.resend(
    type: OtpType.emailChange,
    email: email,
  );
}

Future<AuthResponse> verifyEmailChangeOTP({
  required String email,
  required String otp,
}) async {
  try {
    final response = await _supabase.auth.verifyOTP(
      type: OtpType.emailChange,
      email: email,
      token: otp,
    );
    
    // After successful verification, update registration type and email in users table
    if (response.user != null) {
      try {
        await _supabase
            .from('users')
            .update({
              'email': email,
              'registration_type': 'verified',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', response.user!.id);
      } catch (dbError) {
        // Log the database error but don't fail the entire operation
        print('Database update error after email verification: $dbError');
        // The email change in auth was successful, so we can continue
        // The users table update failing is not critical since the profile update handles it
      }
    }
    
    return response;
  } catch (e) {
    print('verifyEmailChangeOTP error: $e');
    throw AuthException('Email verification failed: ${e.toString()}');
  }
}

//CHANGE PASSWORD IN PROFILE PAGE
Future<void> updatePasswordWithSession({
  required String newPassword,
}) async {
  await _supabase.auth.updateUser(
    UserAttributes(password: newPassword),
  );
}

Future<ResendResponse> resendPasswordResetOTP({
  required String email,
}) async {
  // Check if user exists before resending
  final existingUser = await _supabase
      .from('users')
      .select('email')
      .eq('email', email)
      .maybeSingle();
      
  if (existingUser == null) {
    throw const AuthException('No account found with this email address.');
  }

  return await _supabase.auth.resend(
    type: OtpType.recovery,
    email: email,
  );
}

Future<Map<String, dynamic>?> checkUserStatus(String email) async {
  try {
    final response = await _supabase
        .from('users')
        .select('email, registration_type')
        .eq('email', email)
        .maybeSingle();
    
    if (response != null) {
      // Check if email is verified in auth.users
      // This is a workaround since we can't directly query auth.users
      final currentUser = _supabase.auth.currentUser;
      bool isVerified = false;
      
      // Try to determine verification status
      if (currentUser?.email == email) {
        isVerified = currentUser?.emailConfirmedAt != null;
      }
      
      return {
        'exists': true,
        'registration_type': response['registration_type'],
        'is_verified': isVerified,
      };
    }
    
    return {'exists': false};
  } catch (e) {
    return {'exists': false};
  }
}

Future<void> upgradeToVerifiedAccount({
  required String email,
}) async {
  // Send OTP for EMAIL VERIFICATION (not password reset)
  await _supabase.auth.resend(
    type: OtpType.signup,
    email: email,
  );
  
  // Don't update registration type here - only update after successful OTP verification
  // The registration type should be updated in the OTP verification handler
}

Future<void> sendVerificationToCurrentEmail() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user?.email == null) {
    throw Exception('No authenticated user found');
  }

  // Instead of reauthenticate(), use a magic link approach
  try {
    await _supabase.auth.signInWithOtp(
      email: user?.email!,
    );
  } catch (e) {
    // If that doesn't work, fall back to reauthenticate
    await _supabase.auth.reauthenticate();
  }
}

Future<void> updatePassword({
  required String currentPassword,
  required String newPassword,
}) async {
  final user = _supabase.auth.currentUser;
  if (user == null) throw Exception('No user logged in');
  
  if (user.email == null) throw Exception('User email not available');
  
  try {
    // First, verify the current password by attempting to sign in
    // This is the crucial step that was missing
    await _supabase.auth.signInWithPassword(
      email: user.email!,
      password: currentPassword,
    );
    
    // If sign-in succeeds, the current password is correct
    // Now update to the new password
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    
  } on AuthException catch (e) {
    // Handle specific auth errors
    if (e.message.contains('Invalid login credentials') || 
        e.message.contains('invalid_credentials') ||
        e.message.contains('Invalid') ||
        e.message.contains('credentials')) {
      throw const AuthException('Current password is incorrect');
    } else if (e.message.contains('New password should be different from the old password') ||
               e.message.contains('same_password')) {
      throw const AuthException('New password must be different from your current password');
    }
    rethrow;
  } catch (e) {
    // Convert any other errors to AuthException for consistency
    if (e.toString().contains('Invalid login credentials') || 
        e.toString().contains('invalid_credentials')) {
      throw const AuthException('Current password is incorrect');
    }
    throw AuthException('Failed to update password: ${e.toString()}');
  }
}

  Future<void> resetPassword({
    required String email,
  }) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://zecure.netlify.app/reset-password',
    );
  }

// Add this method to your AuthService class

Future<void> sendVerificationToExistingUser({
  required String email,
}) async {
  // For existing users who need email verification, we use the password reset flow
  // since Supabase doesn't allow signup OTPs for existing emails
  await _supabase.auth.resetPasswordForEmail(email);
}

Future<AuthResponse> verifyExistingUserEmail({
  required String email,
  required String otp,
}) async {
  try {
    // Verify using recovery OTP (password reset flow)
    final response = await _supabase.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: otp,
    );
    
    // After successful verification, update the registration type
    if (response.user != null) {
      await _supabase
          .from('users')
          .update({'registration_type': 'verified'})
          .eq('id', response.user!.id);
    }
    
    return response;
  } catch (e) {
    throw AuthException('Email verification failed: ${e.toString()}');
  }
}


  Future<void> updateProfile({
    String? username,
    String? firstName,
    String? lastName,
    String? middleName,
    String? extName,
    DateTime? bday,
    String? gender,
    String? contactNumber,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final updateData = <String, dynamic>{};
    
    if (username != null) updateData['username'] = username;
    if (firstName != null) updateData['first_name'] = firstName;
    if (lastName != null) updateData['last_name'] = lastName;
    if (middleName != null) updateData['middle_name'] = middleName;
    if (extName != null) updateData['ext_name'] = extName;
    if (bday != null) updateData['bday'] = bday.toIso8601String();
    if (gender != null) updateData['gender'] = gender;
    if (contactNumber != null) updateData['contact_number'] = contactNumber;

    if (updateData.isNotEmpty) {
      await _supabase
          .from('users')
          .update(updateData)
          .eq('id', user.id);
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    return response;
  }

  Future<bool> isAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      return response['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  Future<void> makeUserAdmin(String userId) async {
    if (!await isAdmin()) {
      throw Exception('Only admins can promote users');
    }

    await _supabase
        .from('users')
        .update({'role': 'admin'})
        .eq('id', userId);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  bool get isEmailVerified => _supabase.auth.currentUser?.emailConfirmedAt != null;

  String? get registrationType => _supabase.auth.currentUser?.userMetadata?['registration_type'];
}