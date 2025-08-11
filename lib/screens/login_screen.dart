import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:justice_link_user/services/auth_service.dart';
import 'package:justice_link_user/widgets/animated_input_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;
  late AnimationController _popupController;
  late Animation<double> _popupScaleAnimation;
  late Animation<double> _popupOpacityAnimation;

  String _email = '';
  String _password = '';
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showWelcomePopup = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    // Main screen animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _translateAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1, curve: Curves.easeOutBack),
      ),
    );

    // Popup animation controller
    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _popupScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _popupController,
        curve: Curves.easeOutBack,
      ),
    );

    _popupOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _popupController,
        curve: Curves.easeIn,
      ),
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _popupController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _formKey.currentState!.save();

      final authService = Provider.of<AuthService>(context, listen: false);

      try {
        await authService.signInWithEmailAndPassword(_email, _password);
        if (authService.currentUser != null) {
          // Fetch user name from UserModel
          final userName = authService.currentUser?.fullName ?? 'User';

          if (mounted) {
            setState(() {
              _userName = userName;
              _showWelcomePopup = true;
            });

            // Start popup animation
            _popupController.forward();

            // Wait for popup animation and a brief delay before navigating
            await Future.delayed(const Duration(milliseconds: 2000));
            if (mounted) {
              _popupController.reverse().then((_) {
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/report');
                }
              });
            }
          }
        } else {
          setState(() {
            _errorMessage = 'Failed to load user data after login';
          });
        }
      } on AuthException catch (e) {
        String errorMessage = 'Login failed. Please try again.';
        if (e.message.contains('Invalid login credentials')) {
          errorMessage = 'Invalid email or password';
        } else if (e.message.contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage = 'Authentication error: ${e.message}';
        }
        setState(() {
          _errorMessage = errorMessage;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Unexpected error: ${e.toString()}';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _resetPassword() {
    if (_email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send password reset link to $_email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final authService = Provider.of<AuthService>(context, listen: false);
                await authService.sendPasswordResetEmail(_email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reset link sent to $_email')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to send reset link')),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topRight,
                        radius: 1.5,
                        colors: [
                          Colors.grey[900]!,
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                  ...List.generate(
                    20,
                        (index) => Positioned(
                      left: MediaQuery.of(context).size.width * 0.2 * index % MediaQuery.of(context).size.width,
                      top: 100 + 100 * (index % 5),
                      child: Opacity(
                        opacity: 0.2 + 0.8 * _controller.value,
                        child: Transform.scale(
                          scale: 0.5 + 0.5 * _controller.value,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Transform.translate(
                        offset: Offset(0, _translateAnimation.value),
                        child: Opacity(
                          opacity: _opacityAnimation.value,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 40),
                              Hero(
                                tag: 'auth-logo',
                                child: Center(
                                  child: Text(
                                    'JUSTICE LINK BD',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 60),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    AnimatedInputField(
                                      labelText: 'Email',
                                      prefixIcon: Icons.email,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) =>
                                      value!.isEmpty ? 'Please enter your email' : null,
                                      onSaved: (value) => _email = value!,
                                    ),
                                    const SizedBox(height: 20),
                                    AnimatedInputField(
                                      labelText: 'Password',
                                      prefixIcon: Icons.lock,
                                      obscureText: _obscurePassword,
                                      validator: (value) =>
                                      value!.isEmpty ? 'Please enter your password' : null,
                                      onSaved: (value) => _password = value!,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        onPressed: () {
                                          setState(() => _obscurePassword = !_obscurePassword);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _resetPassword,
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white.withOpacity(0.7),
                                        ),
                                        child: const Text('Forgot Password?'),
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 8,
                                          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        child: _isLoading
                                            ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                            : const Text(
                                          'LOGIN',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'New to Justice Link?',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(context, '/signup');
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(context).colorScheme.primary,
                                    ),
                                    child: const Text('Sign Up'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Welcome Popup
          if (_showWelcomePopup)
            AnimatedBuilder(
              animation: _popupController,
              builder: (context, _) {
                return Stack(
                  children: [
                    // Background overlay
                    ModalBarrier(
                      color: Colors.black.withOpacity(0.5 * _popupOpacityAnimation.value),
                      dismissible: false,
                    ),
                    Center(
                      child: Transform.scale(
                        scale: _popupScaleAnimation.value,
                        child: Opacity(
                          opacity: _popupOpacityAnimation.value,
                          child: Container(
                            width: 300,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Welcome, $_userName!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Successfully logged in to Justice Link BD',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}