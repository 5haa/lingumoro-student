import 'package:flutter/material.dart';
import 'package:flag/flag.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../config/app_colors.dart';
import '../../services/language_service.dart';
import '../../services/carousel_service.dart';
import '../teachers/teachers_list_screen.dart';
import '../students/students_list_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _languageService = LanguageService();
  final _carouselService = CarouselService();
  
  int _currentCarouselPage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.85);
  Timer? _timer;
  
  List<Map<String, dynamic>> _languages = [];
  List<Map<String, dynamic>> _carouselSlides = [];
  int _selectedLanguageIndex = 0;
  bool _isLoadingLanguages = true;
  bool _isLoadingCarousel = true;
  
  // Map language names to flag codes
  final Map<String, FlagsCode> _languageFlagMap = {
    'English': FlagsCode.GB,
    'Arabic': FlagsCode.SA,
    'Spanish': FlagsCode.ES,
    'French': FlagsCode.FR,
    'German': FlagsCode.DE,
    'Italian': FlagsCode.IT,
    'Turkish': FlagsCode.TR,
    'Kurdish': FlagsCode.IQ, // Using Iraq flag as approximation
  };
  
  @override
  void initState() {
    super.initState();
    _loadLanguages();
    _loadCarousel();
    _startCarouselTimer();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
  
  void _startCarouselTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_pageController.hasClients && _carouselSlides.isNotEmpty) {
        int nextPage = _currentCarouselPage + 1;
        if (nextPage >= _carouselSlides.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
  }
  
  Future<void> _loadLanguages() async {
    try {
      final languages = await _languageService.getActiveLanguages();
      if (mounted) {
        setState(() {
          _languages = languages;
          _isLoadingLanguages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLanguages = false);
      }
    }
  }
  
  Future<void> _loadCarousel() async {
    try {
      final slides = await _carouselService.getActiveSlides();
      if (mounted) {
        setState(() {
          _carouselSlides = slides;
          _isLoadingCarousel = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCarousel = false);
      }
    }
  }
  
  void _navigateToTeachers() {
    if (_languages.isEmpty || _selectedLanguageIndex >= _languages.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a language first'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    
    final selectedLanguage = _languages[_selectedLanguageIndex];
    Navigator.pushNamed(
      context,
      '/teachers',
      arguments: {
        'languageId': selectedLanguage['id'],
        'languageName': selectedLanguage['name'],
      },
    );
  }
  
  void _navigateToStudents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StudentsListScreen(),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),
            
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 15),
                    
                    // Carousel
                    _buildCarousel(),
                    
                    const SizedBox(height: 20),
                    
                    // Choose Your Class Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHOOSE YOUR CLASS',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 15),
                          
                          // Language Cards
                          _isLoadingLanguages
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  ),
                                )
                              : _languages.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(32.0),
                                        child: Text(
                                          'No languages available',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Row(
                                      children: _languages.asMap().entries.take(3).map((entry) {
                                        int index = entry.key;
                                        Map<String, dynamic> lang = entry.value;
                                        return Expanded(
                                          child: _buildLanguageCard(
                                            lang['name'] ?? '',
                                            lang['flag_url'],
                                            _selectedLanguageIndex == index,
                                            index,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                          
                          const SizedBox(height: 20),
                          
                          // Student and Teacher Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  'Students',
                                  Colors.red.shade400,
                                  'assets/images/student.jpg',
                                  imageOnRight: false,
                                  onTap: _navigateToStudents,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildRoleCard(
                                  'Teachers',
                                  Colors.blue.shade400,
                                  'assets/images/teacher.jpg',
                                  imageOnRight: true,
                                  onTap: _navigateToTeachers,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Menu Icon
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const FaIcon(
                FontAwesomeIcons.bars,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          
          const Expanded(
            child: Center(
              child: Text(
                'LINGUMORO',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          
          // Notification Icon
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const FaIcon(FontAwesomeIcons.bell, size: 20),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCarousel() {
    if (_isLoadingCarousel) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }
    
    if (_carouselSlides.isEmpty) {
      // Fallback carousel with default content
      return SizedBox(
        height: 180,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (int page) {
            setState(() {
              _currentCarouselPage = page;
            });
          },
          itemBuilder: (context, index) {
            final actualIndex = index % 3;
            final defaultTexts = [
              'Web Designing\nONLINE COURSE',
              'Instagram Banner\nWeb course online',
              'Mobile Development\nONLINE COURSE',
            ];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A5568), Color(0xFF6B46C1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 20,
                    child: Text(
                      defaultTexts[actualIndex],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'JOIN NOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    
    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
            _currentCarouselPage = page;
          });
        },
        itemBuilder: (context, index) {
          final actualIndex = index % _carouselSlides.length;
          final slide = _carouselSlides[actualIndex];
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A5568), Color(0xFF6B46C1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background image if available
                if (slide['image_url'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: slide['image_url'],
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const SizedBox(),
                    ),
                  ),
                Positioned(
                  left: 20,
                  top: 20,
                  child: Text(
                    slide['title'] ?? 'ONLINE COURSE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'JOIN NOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildLanguageCard(String name, String? flagUrl, bool isSelected, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLanguageIndex = index;
        });
      },
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double flagSize = (constraints.maxWidth * 0.5).clamp(45.0, 60.0);
              final double fontSize = (constraints.maxWidth * 0.16).clamp(12.0, 15.0);
              final double spacing = (constraints.maxWidth * 0.08).clamp(8.0, 12.0);
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flag
                  ClipOval(
                    child: flagUrl != null
                        ? CachedNetworkImage(
                            imageUrl: flagUrl,
                            width: flagSize,
                            height: flagSize,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: flagSize,
                              height: flagSize,
                              color: AppColors.lightGrey,
                              child: Icon(
                                Icons.language,
                                size: flagSize * 0.5,
                                color: AppColors.grey,
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              // Try to use flag code if available
                              final flagCode = _languageFlagMap[name];
                              if (flagCode != null) {
                                return Flag.fromCode(
                                  flagCode,
                                  height: flagSize,
                                  width: flagSize,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                width: flagSize,
                                height: flagSize,
                                color: AppColors.lightGrey,
                                child: Icon(
                                  Icons.language,
                                  size: flagSize * 0.5,
                                  color: AppColors.grey,
                                ),
                              );
                            },
                          )
                        : _languageFlagMap.containsKey(name)
                            ? Flag.fromCode(
                                _languageFlagMap[name]!,
                                height: flagSize,
                                width: flagSize,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: flagSize,
                                height: flagSize,
                                decoration: BoxDecoration(
                                  color: AppColors.lightGrey,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.language,
                                  size: flagSize * 0.5,
                                  color: AppColors.grey,
                                ),
                              ),
                  ),
                  SizedBox(height: spacing),
                  // Language Name
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildRoleCard(
    String title,
    Color color,
    String imagePath,
    {required bool imageOnRight, required VoidCallback onTap}
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double imageSize = (constraints.maxWidth * 0.55).clamp(80.0, 120.0);
              final double iconSize = (constraints.maxWidth * 0.25).clamp(30.0, 45.0);
              final double fontSize = (constraints.maxWidth * 0.12).clamp(14.0, 16.0);
              final double padding = (constraints.maxWidth * 0.1).clamp(10.0, 15.0);
              
              return Stack(
                children: [
                  if (!imageOnRight) ...[
                    // Students: Text on top right, Image on bottom left
                    Positioned(
                      top: padding,
                      right: padding,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(15),
                        ),
                        child: Image.asset(
                          imagePath,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: imageSize,
                              height: imageSize,
                              color: color.withOpacity(0.2),
                              child: FaIcon(
                                FontAwesomeIcons.graduationCap,
                                color: color,
                                size: iconSize,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ] else ...[
                    // Teachers: Text on top left, Image on bottom right
                    Positioned(
                      top: padding,
                      left: padding,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(15),
                        ),
                        child: Image.asset(
                          imagePath,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: imageSize,
                              height: imageSize,
                              color: color.withOpacity(0.2),
                              child: FaIcon(
                                FontAwesomeIcons.chalkboardUser,
                                color: color,
                                size: iconSize,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
