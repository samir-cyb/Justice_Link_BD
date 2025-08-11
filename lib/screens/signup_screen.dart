import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:justice_link_user/services/auth_service.dart';
import 'package:justice_link_user/widgets/animated_input_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;

  String _fullName = '';
  String _occupation = '';
  String _area = '';
  String _email = '';
  String _password = '';
  String _phoneNumber = '';
  bool _isLoading = false;
  bool _showSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.easeInOut)),
    );

    _translateAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1, curve: Curves.easeOutBack)),
    );

    SchedulerBinding.instance.addPostFrameCallback((_) => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _formKey.currentState!.save();

      try {
        await _auth.signUpWithEmailAndPassword(
            _email, _password, _fullName, _occupation, _area, _phoneNumber);

        setState(() => _showSuccess = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } on Exception catch (e) {
        setState(() => _errorMessage = e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              // Background gradient
              Container(
                decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.5,
                      colors: [Colors.grey, Colors.black],
                    )),
              ),

              // Content
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
                          const Center(
                            child: Text(
                              'JUSTICE LINK BD',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          if (_showSuccess)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Text(
                                'Account created successfully!',
                                style: TextStyle(color: Colors.green),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                AnimatedInputField(
                                  labelText: 'Full Name',
                                  prefixIcon: Icons.person,
                                  validator: (value) =>
                                  value!.isEmpty ? 'Required' : null,
                                  onSaved: (value) => _fullName = value!,
                                ),
                                const SizedBox(height: 20),
                                AnimatedInputField(
                                  labelText: 'Occupation',
                                  prefixIcon: Icons.work,
                                  validator: (value) =>
                                  value!.isEmpty ? 'Required' : null,
                                  onSaved: (value) => _occupation = value!,
                                ),
                                const SizedBox(height: 20),
                                AnimatedInputField(
                                  labelText: 'Area',
                                  prefixIcon: Icons.location_on,
                                  validator: (value) =>
                                  value!.isEmpty ? 'Required' : null,
                                  onSaved: (value) => _area = value!,
                                ),
                                const SizedBox(height: 20),
                                AnimatedInputField(
                                  labelText: 'Email',
                                  prefixIcon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) =>
                                  value!.isEmpty ? 'Required' : null,
                                  onSaved: (value) => _email = value!,
                                ),
                                const SizedBox(height: 20),
                                AnimatedInputField(
                                  labelText: 'Phone Number',
                                  prefixIcon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return 'Required';
                                    }
                                    // Simple phone number validation
                                    if (!RegExp(r'^[0-9]{10,15}$').hasMatch(value)) {
                                      return 'Enter a valid phone number';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) => _phoneNumber = value!,
                                ),
                                const SizedBox(height: 20),
                                AnimatedInputField(
                                  labelText: 'Password',
                                  prefixIcon: Icons.lock,
                                  obscureText: true,
                                  validator: (value) => value!.length < 6
                                      ? 'Minimum 6 characters'
                                      : null,
                                  onSaved: (value) => _password = value!,
                                ),
                                const SizedBox(height: 30),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : const Text('SIGN UP'),
                                ),
                              ],
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
    );
  }
}