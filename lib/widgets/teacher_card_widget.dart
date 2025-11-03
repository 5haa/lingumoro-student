import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TeacherCardWidget extends StatelessWidget {
  final Map<String, dynamic> teacher;
  final VoidCallback? onTap;

  const TeacherCardWidget({
    super.key,
    required this.teacher,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final teacherData = teacher['teachers'] ?? teacher;
    final languages = teacher['teacher_languages'] as List?;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurple.shade100,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: teacherData['avatar_url'] != null
                      ? CachedNetworkImage(
                          imageUrl: teacherData['avatar_url'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.deepPurple.shade100,
                            child: const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.deepPurple,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.deepPurple.shade100,
                            child: const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.deepPurple,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.deepPurple.shade700,
                        ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Teacher Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacherData['full_name'] ?? 'Teacher',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (teacherData['specialization'] != null)
                      Text(
                        teacherData['specialization'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    if (languages != null && languages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: languages.take(3).map((langData) {
                          final lang = langData['language_courses'];
                          if (lang == null) return const SizedBox.shrink();
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.deepPurple.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (lang['flag_url'] != null)
                                  Image.network(
                                    lang['flag_url'],
                                    width: 16,
                                    height: 12,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(
                                      Icons.language,
                                      size: 12,
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  lang['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepPurple.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


