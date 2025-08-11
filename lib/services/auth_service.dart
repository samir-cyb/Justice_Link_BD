import 'package:flutter/foundation.dart';
import 'package:justice_link_user/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  UserModel? _currentUser;

  AuthService() {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        await _loadCurrentUser(session.user.id);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadCurrentUser(String uid) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('uid', uid)
          .maybeSingle();

      if (response != null) {
        _currentUser = UserModel.fromMap(response);
      } else {
        debugPrint('User not found in database');
        _currentUser = UserModel(
          uid: uid,
          email: _supabase.auth.currentUser?.email,
        );
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
      _currentUser = null;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> signUpWithEmailAndPassword(
      String email,
      String password,
      String fullName,
      String occupation,
      String area,
      String phoneNumber,
      ) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'occupation': occupation,
          'area': area,
          'phone_number': phoneNumber,
        },
      );

      if (response.user != null) {
        await _supabase.from('users').insert({
          'uid': response.user!.id,
          'email': email,
          'full_name': fullName,
          'occupation': occupation,
          'area': area,
          'phone_number': phoneNumber,
        });
        await _loadCurrentUser(response.user!.id);
      }
    } catch (e) {
      debugPrint('Signup error: $e');
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadCurrentUser(response.user!.id);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<void> updatePhoneNumber(String newPhoneNumber) async {
    try {
      if (_currentUser == null) throw Exception('User not logged in');

      await _supabase
          .from('users')
          .update({'phone_number': newPhoneNumber})
          .eq('uid', _currentUser!.uid);

      await _loadCurrentUser(_currentUser!.uid);
    } catch (e) {
      debugPrint('Update phone number error: $e');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      rethrow;
    }
  }

  UserModel? get currentUser => _currentUser;
}