import 'package:flutter/material.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/widgets/custom_button.dart';
import 'package:student/widgets/custom_text_field.dart';
import 'package:student/l10n/app_localizations.dart';
import 'otp_verification_screen.dart';

class SignUpContent extends StatefulWidget {
  const SignUpContent({super.key});

  @override
  State<SignUpContent> createState() => _SignUpContentState();
}

class _SignUpContentState extends State<SignUpContent> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  
  String? _selectedProvinceId;
  String? _selectedProvinceName;
  bool _isLoading = false;
  
  // Hardcoded list of all Iraqi provinces
  static const List<Map<String, String>> _provinces = [
    {'id': 'baghdad', 'name': 'Baghdad', 'nameAr': 'بغداد'},
    {'id': 'basra', 'name': 'Basra', 'nameAr': 'البصرة'},
    {'id': 'nineveh', 'name': 'Nineveh', 'nameAr': 'نينوى'},
    {'id': 'erbil', 'name': 'Erbil', 'nameAr': 'أربيل'},
    {'id': 'sulaymaniyah', 'name': 'Sulaymaniyah', 'nameAr': 'السليمانية'},
    {'id': 'diyala', 'name': 'Diyala', 'nameAr': 'ديالى'},
    {'id': 'anbar', 'name': 'Anbar', 'nameAr': 'الأنبار'},
    {'id': 'kirkuk', 'name': 'Kirkuk', 'nameAr': 'كركوك'},
    {'id': 'najaf', 'name': 'Najaf', 'nameAr': 'النجف'},
    {'id': 'karbala', 'name': 'Karbala', 'nameAr': 'كربلاء'},
    {'id': 'babil', 'name': 'Babil', 'nameAr': 'بابل'},
    {'id': 'dhi_qar', 'name': 'Dhi Qar', 'nameAr': 'ذي قار'},
    {'id': 'maysan', 'name': 'Maysan', 'nameAr': 'ميسان'},
    {'id': 'wasit', 'name': 'Wasit', 'nameAr': 'واسط'},
    {'id': 'saladin', 'name': 'Saladin', 'nameAr': 'صلاح الدين'},
    {'id': 'muthanna', 'name': 'Muthanna', 'nameAr': 'المثنى'},
    {'id': 'qadisiyyah', 'name': 'Qadisiyyah', 'nameAr': 'القادسية'},
    {'id': 'dohuk', 'name': 'Dohuk', 'nameAr': 'دهوك'},
    {'id': 'halabja', 'name': 'Halabja', 'nameAr': 'حلبجة'},
  ];
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  void _showProvinceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ProvinceBottomSheet(
        provinces: _provinces,
        selectedProvinceId: _selectedProvinceId,
        onProvinceSelected: (provinceId, provinceName) {
          setState(() {
            _selectedProvinceId = provinceId;
            _selectedProvinceName = provinceName;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
  
  Future<void> _handleSignUp() async {
    final l10n = AppLocalizations.of(context);
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.fillAllFields),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.passwordMismatch),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    
    if (_selectedProvinceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseSelectProvince),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        phone: null,
        provinceId: _selectedProvinceId,
      );
      
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OTPVerificationScreen(
              email: _emailController.text.trim(),
              fullName: _nameController.text.trim(),
              phone: null,
              provinceId: _selectedProvinceId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).signupFailed}: ${e.toString()}'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Full Name field
        CustomTextField(
          controller: _nameController,
          hintText: l10n.fullName,
          keyboardType: TextInputType.name,
        ),
        
        const SizedBox(height: 20),
        
        // Email field
        CustomTextField(
          controller: _emailController,
          hintText: l10n.email,
          keyboardType: TextInputType.emailAddress,
        ),
        
        const SizedBox(height: 20),
        
        // Province selection field
        GestureDetector(
          onTap: _showProvinceBottomSheet,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: _selectedProvinceId != null 
                      ? AppColors.primary 
                      : AppColors.textHint,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedProvinceName ?? l10n.chooseCity,
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedProvinceId != null 
                          ? AppColors.textPrimary 
                          : AppColors.textHint,
                      fontWeight: _selectedProvinceId != null 
                          ? FontWeight.w500 
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Password field
        CustomTextField(
          controller: _passwordController,
          hintText: l10n.password,
          obscureText: true,
        ),
        
        const SizedBox(height: 20),
        
        // Confirm Password field
        CustomTextField(
          controller: _confirmPasswordController,
          hintText: l10n.confirmPassword,
          obscureText: true,
        ),
        
        const SizedBox(height: 30),
        
        // Confirm Account button
        CustomButton(
          text: l10n.confirmAccount,
          onPressed: _handleSignUp,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}

class _ProvinceBottomSheet extends StatefulWidget {
  final List<Map<String, String>> provinces;
  final String? selectedProvinceId;
  final Function(String provinceId, String provinceName) onProvinceSelected;

  const _ProvinceBottomSheet({
    required this.provinces,
    required this.selectedProvinceId,
    required this.onProvinceSelected,
  });

  @override
  State<_ProvinceBottomSheet> createState() => _ProvinceBottomSheetState();
}

class _ProvinceBottomSheetState extends State<_ProvinceBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filteredProvinces = [];

  @override
  void initState() {
    super.initState();
    _filteredProvinces = widget.provinces;
    _searchController.addListener(_filterProvinces);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProvinces);
    _searchController.dispose();
    super.dispose();
  }

  void _filterProvinces() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProvinces = widget.provinces;
      } else {
        _filteredProvinces = widget.provinces.where((province) {
          return province['name']!.toLowerCase().contains(query) ||
                 province['nameAr']!.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.redGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).selectProvince,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchProvince,
                  hintStyle: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 16,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.grey,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Provinces list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: _filteredProvinces.length,
              itemBuilder: (context, index) {
                final province = _filteredProvinces[index];
                final isSelected = widget.selectedProvinceId == province['id'];
                
                return InkWell(
                  onTap: () {
                    widget.onProvinceSelected(
                      province['id']!,
                      '${province['name']} (${province['nameAr']})',
                    );
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary 
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                province['name']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected 
                                      ? AppColors.primary 
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                province['nameAr']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected 
                                      ? AppColors.primary.withOpacity(0.8)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: AppColors.redGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppColors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
