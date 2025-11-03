import 'package:flutter/material.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/language_service.dart';
import 'package:student/widgets/carousel_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _languageService = LanguageService();
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _languages = [];
  String? _selectedLanguageId;
  String? _selectedLanguageName;
  bool _isLoading = true;
  bool _isLoadingLanguages = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getStudentProfile();
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
      // Load languages
      _loadLanguages();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLanguages() async {
    setState(() => _isLoadingLanguages = true);
    try {
      final languages = await _languageService.getActiveLanguages();
      setState(() {
        _languages = languages;
        _isLoadingLanguages = false;
      });
    } catch (e) {
      setState(() => _isLoadingLanguages = false);
    }
  }

  void _navigateToTeachers() {
    if (_selectedLanguageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a language first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Navigate to teachers list for selected language
    Navigator.pushNamed(
      context,
      '/teachers',
      arguments: {
        'languageId': _selectedLanguageId,
        'languageName': _selectedLanguageName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lingumoro Student'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Welcome banner
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.deepPurple.shade400,
                            Colors.deepPurple.shade800,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profile?['full_name'] ?? 'Student',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Continue your learning journey',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Carousel
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CarouselWidget(),
                    ),

                    // Choose Your Course Section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHOOSE YOUR COURSE',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Language Buttons Grid
                          _isLoadingLanguages
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.0,
                                  ),
                                  itemCount: _languages.length,
                                  itemBuilder: (context, index) {
                                    final language = _languages[index];
                                    final isSelected = _selectedLanguageId == language['id'];
                                    
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedLanguageId = language['id'];
                                          _selectedLanguageName = language['name'];
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.deepPurple
                                                : Colors.grey.shade300,
                                            width: isSelected ? 3 : 2,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.deepPurple.withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            // Flag
                                            if (language['flag_url'] != null)
                                              Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.1),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl: language['flag_url'],
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) => Container(
                                                      color: Colors.grey[200],
                                                      child: const Icon(
                                                        Icons.language,
                                                        size: 30,
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) =>
                                                        Container(
                                                      color: Colors.grey[200],
                                                      child: const Icon(
                                                        Icons.language,
                                                        size: 30,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            else
                                              Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.grey[200],
                                                ),
                                                child: const Icon(
                                                  Icons.language,
                                                  size: 30,
                                                ),
                                              ),
                                            const SizedBox(height: 12),
                                            // Language Name
                                            Text(
                                              language['name'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.deepPurple
                                                    : Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          
                          const SizedBox(height: 32),
                          
                          // Teachers and Students Buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionCard(
                                  'Teachers',
                                  Icons.person_outline,
                                  'Find your perfect instructor',
                                  Colors.deepPurple,
                                  _navigateToTeachers,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionCard(
                                  'Students',
                                  Icons.school_outlined,
                                  'Connect with learners',
                                  Colors.teal,
                                  () {
                                    // TODO: Navigate to students (coming soon)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Coming soon...'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Dashboard cards
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Quick stats
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            children: [
                              _buildStatCard(
                                'My Courses',
                                '0',
                                Icons.book,
                                Colors.blue,
                              ),
                              _buildStatCard(
                                'Completed',
                                '0',
                                Icons.check_circle,
                                Colors.green,
                              ),
                              _buildStatCard(
                                'In Progress',
                                '0',
                                Icons.hourglass_empty,
                                Colors.orange,
                              ),
                              _buildStatCard(
                                'Certificates',
                                '0',
                                Icons.workspace_premium,
                                Colors.purple,
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Quick actions
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildActionButton(
                            'Browse Courses',
                            Icons.search,
                            () {},
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            'My Schedule',
                            Icons.calendar_today,
                            () {},
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            'Assignments',
                            Icons.assignment,
                            () {},
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            'Messages',
                            Icons.message,
                            () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.7),
              color,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

