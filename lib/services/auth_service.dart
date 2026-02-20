import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:justice_link_user/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  UserModel? _currentUser;
  bool _isLoading = false;

  AuthService() {
    _initializeAuthListener();
    _loadInitialUser();
  }

  /// Load user on startup if session exists
  Future<void> _loadInitialUser() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      await _loadCurrentUser(session.user.id);
    }
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

  /// Check if current session is valid - MODIFIED FOR PERSISTENT SESSION
  Future<AuthStatus> checkSessionValidity() async {
    final session = _supabase.auth.currentSession;

    if (session == null) {
      // Check if we have saved credentials for auto-login
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (rememberMe && savedEmail != null && savedPassword != null) {
        try {
          // Try to auto-login
          final response = await _supabase.auth.signInWithPassword(
            email: savedEmail,
            password: savedPassword,
          );

          if (response.user != null) {
            await _loadCurrentUser(response.user!.id);
            return AuthStatus.valid;
          }
        } catch (e) {
          developer.log('Auto-login failed: $e');
          // Clear saved credentials if auto-login fails
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
          await prefs.setBool('remember_me', false);
        }
      }

      return AuthStatus.noSession;
    }

    try {
      final decodedToken = JwtDecoder.decode(session.accessToken);
      final expiryTimestamp = decodedToken['exp'] as int?;

      if (expiryTimestamp == null) {
        await signOut();
        return AuthStatus.invalid;
      }

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp * 1000);
      final now = DateTime.now();
      final difference = expiryDate.difference(now);

      if (difference.isNegative) {
        // Session expired, try to refresh
        final refreshed = await refreshSession();
        if (refreshed) {
          return AuthStatus.valid;
        }
        await signOut();
        return AuthStatus.expired;
      }

      // Session is valid, no need to check 7-day limit for persistent login
      // Just refresh if it's getting close to expiry
      if (difference.inDays < 1) {
        await refreshSession();
      }

      return AuthStatus.valid;
    } catch (e) {
      developer.log('Error checking session: $e');
      await signOut();
      return AuthStatus.invalid;
    }
  }

  /// Refresh session to extend another 7 days
  Future<bool> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();
      if (response.user != null) {
        await _loadCurrentUser(response.user!.id);
        developer.log('✅ Session refreshed successfully');
        return true;
      }
      return false;
    } catch (e) {
      developer.log('❌ Session refresh failed: $e');
      return false;
    }
  }

  Future<void> signUpWithEmailAndPassword(
      String email,
      String password,
      String fullName,
      String occupation,
      String area,
      String phoneNumber,
      String address,  // ADDED: address parameter
      ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'occupation': occupation,
          'area': area,
          'phone_number': phoneNumber,
          'address': address,  // ADDED: address in metadata
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
          'address': address,  // ADDED: address in database insert
        });
        await _loadCurrentUser(response.user!.id);
      }
    } catch (e) {
      debugPrint('Signup error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();

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
    } finally {
      _isLoading = false;
      notifyListeners();
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
      // Clear saved credentials on logout
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);

      await _supabase.auth.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      rethrow;
    }
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
}

/// Enum for session status checking
enum AuthStatus {
  valid,      // Session good
  expired,    // Session expired
  tooOld,     // Session valid but > 7 days (not used with persistent login)
  noSession,  // No session found
  invalid,    // Token decode error or other issue
}