import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

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
  // Check if username already exists
  final existingUser = await _supabase
      .from('users')
      .select('username')
      .eq('username', username)
      .maybeSingle();
      
  if (existingUser != null) {
    throw const AuthException('Username already exists. Please choose a different username.');
  }

  // The database trigger will automatically create the basic user record
  // We just need to pass the metadata for the trigger to use
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
    },
  );

  // If signup was successful and we have additional data not handled by trigger,
  // update the user record with the additional fields
  if (response.user != null && response.error == null) {
    try {
      // Wait a moment for the trigger to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Update with additional fields that might not be in the trigger
      await _supabase.from('users').update({
        'middle_name': middleName,
        'ext_name': extName,
        'bday': bday?.toIso8601String(),
        'gender': gender,
        'contact_number': contactNumber,
      }).eq('id', response.user!.id);
    } catch (e) {
      // If update fails, it's not critical since basic user was created by trigger
      print('Warning: Could not update additional user fields: $e');
    }
  }

  return response;
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

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _supabase.auth.currentUser?.email;
    if (email == null) throw Exception('No user logged in');
    
    // Store the current session to restore later
    final _ = _supabase.auth.currentSession;
    
    try {
      // Try to reauthenticate with the current password
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      
      // Check if authentication failed
      if (authResponse.user == null) {
        throw const AuthException('Invalid login credentials');
      }
      
      // Update password
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
    } catch (e) {
      // If it's an AuthException, preserve it
      if (e is AuthException) {
        rethrow;
      }
      
      // For other errors, check if it's likely a wrong password
      if (e.toString().contains('Invalid login credentials') || 
          e.toString().contains('invalid_credentials') ||
          e.toString().contains('Invalid') ||
          e.toString().contains('credentials')) {
        throw const AuthException('Invalid login credentials');
      }
      
      // For any other error, rethrow as is
      rethrow;
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
    // Only existing admins should be able to call this
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
}

extension on AuthResponse {
  get error => null;
}