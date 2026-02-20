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
  final SupabaseClient _supabase = Supabase.instance.client;

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;

  String _fullName = '';
  String _occupation = '';
  String _area = '';
  String _email = '';
  String _password = '';
  String _phoneNumber = '';
  String _address = '';  // ADDED: address field
  bool _isLoading = false;
  bool _showSuccess = false;
  String? _errorMessage;

  // For area search
  List<Map<String, dynamic>> _allAreas = [];
  List<Map<String, dynamic>> _filteredAreas = [];
  bool _isLoadingAreas = false;
  final TextEditingController _areaSearchController = TextEditingController();
  final FocusNode _areaFocusNode = FocusNode();
  bool _showAreaDropdown = false;

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

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      _loadAreas();
    });

    _areaFocusNode.addListener(() {
      if (!_areaFocusNode.hasFocus) {
        setState(() {
          _showAreaDropdown = false;
        });
      }
    });
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoadingAreas = true);
    try {
      // Fetch both Bangla and English columns
      final response = await _supabase
          .from('ason')
          .select('area_name, division, area_name_en, division_en')
          .order('area_name');

      setState(() {
        _allAreas = List<Map<String, dynamic>>.from(response);
        _filteredAreas = _allAreas;
        _isLoadingAreas = false;
      });
    } catch (e) {
      setState(() => _isLoadingAreas = false);
      _showError('Failed to load areas. Please try again.');
    }
  }

  void _filterAreas(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAreas = _allAreas;
      } else {
        _filteredAreas = _allAreas.where((area) {
          final areaName = area['area_name'].toString().toLowerCase();
          final division = area['division'].toString().toLowerCase();
          // Also search in English columns (handle null values)
          final areaNameEn = (area['area_name_en'] ?? '').toString().toLowerCase();
          final divisionEn = (area['division_en'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();

          return areaName.contains(searchLower) ||
              division.contains(searchLower) ||
              areaNameEn.contains(searchLower) ||
              divisionEn.contains(searchLower);
        }).toList();
      }
      _showAreaDropdown = true;
    });
  }

  void _selectArea(Map<String, dynamic> area) {
    setState(() {
      // Store the Bangla name as the selected area
      _area = area['area_name'];
      // Display Bangla name in the field, or English if Bangla is empty
      _areaSearchController.text = area['area_name'] ?? area['area_name_en'] ?? '';
      _showAreaDropdown = false;
    });
    _areaFocusNode.unfocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _areaSearchController.dispose();
    _areaFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_area.isEmpty) {
        _showError('Please select an area');
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _formKey.currentState!.save();

      try {
        await _auth.signUpWithEmailAndPassword(
            _email, _password, _fullName, _occupation, _area, _phoneNumber, _address);  // ADDED: _address parameter

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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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

              // Back button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: IconButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    tooltip: 'Back to Login',
                  ),
                ),
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
                          const SizedBox(height: 60),
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

                                // Area Search Field
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _showAreaDropdown
                                              ? Colors.blueAccent
                                              : Colors.white24,
                                          width: 1,
                                        ),
                                      ),
                                      child: TextFormField(
                                        controller: _areaSearchController,
                                        focusNode: _areaFocusNode,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          labelText: 'Search Area',
                                          labelStyle: TextStyle(
                                            color: _area.isEmpty ? Colors.white54 : Colors.blueAccent,
                                          ),
                                          prefixIcon: const Icon(Icons.location_on, color: Colors.white54),
                                          suffixIcon: _isLoadingAreas
                                              ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white54,
                                              ),
                                            ),
                                          )
                                              : IconButton(
                                            icon: const Icon(Icons.clear, color: Colors.white54),
                                            onPressed: () {
                                              _areaSearchController.clear();
                                              _filterAreas('');
                                              setState(() {
                                                _area = '';
                                              });
                                            },
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        ),
                                        onChanged: _filterAreas,
                                        onTap: () {
                                          setState(() {
                                            _showAreaDropdown = true;
                                          });
                                        },
                                      ),
                                    ),

                                    // Dropdown for area suggestions
                                    if (_showAreaDropdown && _filteredAreas.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E2A38),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _filteredAreas.length > 50 ? 50 : _filteredAreas.length,
                                            itemBuilder: (context, index) {
                                              final area = _filteredAreas[index];
                                              return ListTile(
                                                dense: true,
                                                title: Text(
                                                  // Show Bangla name with English in parentheses if available
                                                  area['area_name_en'] != null
                                                      ? '${area['area_name']} (${area['area_name_en']})'
                                                      : area['area_name'],
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  // Show division in both languages if available
                                                  area['division_en'] != null
                                                      ? '${area['division']} (${area['division_en']})'
                                                      : area['division'],
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.6),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onTap: () => _selectArea(area),
                                              );
                                            },
                                          ),
                                        ),
                                      ),

                                    if (_showAreaDropdown && _filteredAreas.isEmpty && _areaSearchController.text.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E2A38),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'No areas found',
                                          style: TextStyle(color: Colors.white54),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // ADDED: Address Input Field
                                AnimatedInputField(
                                  labelText: 'Detailed Address',
                                  prefixIcon: Icons.home,
                                  maxLines: 2,  // Allow multiple lines for address
                                  validator: (value) =>
                                  value!.isEmpty ? 'Required' : null,
                                  onSaved: (value) => _address = value!,
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