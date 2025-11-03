import 'package:flutter/material.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/language_service.dart';
import 'package:student/widgets/carousel_widget.dart';
import 'package:student/widgets/language_slider_widget.dart';
import 'package:student/widgets/teacher_card_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _languageService = LanguageService();
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _teachers = [];
  String? _selectedLanguageId;
  String? _selectedLanguageName;
  bool _isLoading = true;
  bool _isLoadingTeachers = false;

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
      // Load all teachers with languages initially
      _loadAllTeachers();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllTeachers() async {
    setState(() => _isLoadingTeachers = true);
    try {
      final teachers = await _languageService.getAllTeachersWithLanguages();
      setState(() {
        _teachers = teachers;
        _isLoadingTeachers = false;
      });
    } catch (e) {
      setState(() => _isLoadingTeachers = false);
    }
  }

  Future<void> _loadTeachersForLanguage(String languageId, String languageName) async {
    setState(() {
      _selectedLanguageId = languageId;
      _selectedLanguageName = languageName;
      _isLoadingTeachers = true;
    });
    
    try {
      final teacherLanguages = await _languageService.getTeachersForLanguage(languageId);
      setState(() {
        _teachers = teacherLanguages;
        _isLoadingTeachers = false;
      });
    } catch (e) {
      setState(() => _isLoadingTeachers = false);
    }
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

                    // Language Slider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: LanguageSliderWidget(
                        onLanguageSelected: _loadTeachersForLanguage,
                      ),
                    ),

                    // Teachers and Students Cards
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLanguageName != null
                                ? 'Teachers for $_selectedLanguageName'
                                : 'Available Teachers',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Teachers Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        color: Colors.deepPurple.shade700,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Teachers',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _isLoadingTeachers
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      : _teachers.isEmpty
                                          ? Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Center(
                                                child: Text(
                                                  _selectedLanguageName != null
                                                      ? 'No teachers available for $_selectedLanguageName'
                                                      : 'No teachers available',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : ListView.separated(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: _teachers.length,
                                              separatorBuilder: (context, index) =>
                                                  const SizedBox(height: 12),
                                              itemBuilder: (context, index) {
                                                return TeacherCardWidget(
                                                  teacher: _teachers[index],
                                                  onTap: () {
                                                    // TODO: Navigate to teacher details
                                                  },
                                                );
                                              },
                                            ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Students Card (placeholder)
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.school_outlined,
                                        color: Colors.deepPurple.shade700,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Students',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'Coming soon...',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
}

