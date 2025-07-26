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
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
      },
    );

    if (response.user != null) {
      // Insert additional user data into the public.users table
      await _supabase.from('users').insert({
        'email': email,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'middle_name': middleName,
        'ext_name': extName,
        'bday': bday?.toIso8601String(),
        'gender': gender,
        'role': 'user',
      });
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
  // First verify the current password by signing in again
  final email = _supabase.auth.currentUser?.email;
  if (email == null) throw Exception('No user logged in');
  
  // Reauthenticate
  await _supabase.auth.signInWithPassword(
    email: email,
    password: currentPassword,
  );
  
  // Then update password
  await _supabase.auth.updateUser(
    UserAttributes(password: newPassword),
  );
}

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}

