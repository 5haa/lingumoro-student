import 'package:flutter/material.dart';
import 'package:student/services/package_service.dart';
import 'dart:convert';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final _packageService = PackageService();
  List<Map<String, dynamic>> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);
    try {
      final packages = await _packageService.getActivePackages();
      setState(() {
        _packages = packages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Packages'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _packages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        size: 80,
                        color: Colors.deepPurple.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Packages Available',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check back later for subscription options',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPackages,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _packages.length,
                    itemBuilder: (context, index) {
                      final package = _packages[index];
                      final isFeatured = package['is_featured'] ?? false;
                      
                      return _buildPackageCard(package, isFeatured);
                    },
                  ),
                ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package, bool isFeatured) {
    final features = package['features'] != null
        ? (package['features'] is List
            ? List<String>.from(package['features'])
            : List<String>.from(json.decode(package['features'])))
        : <String>[];

    return Card(
      elevation: isFeatured ? 8 : 3,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isFeatured
            ? const BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isFeatured
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.shade50,
                    Colors.orange.shade50,
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      package['name'] ?? 'Package',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isFeatured ? Colors.orange.shade900 : Colors.black87,
                      ),
                    ),
                  ),
                  if (isFeatured)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'POPULAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Description
              if (package['description'] != null)
                Text(
                  package['description'],
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Package Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.access_time,
                      'Session Duration',
                      '${package['duration_minutes']} minutes',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Sessions per Week',
                      '${package['sessions_per_week']} sessions',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.date_range,
                      'Total Duration',
                      '${package['total_weeks']} weeks',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Price
              if (package['price_monthly'] != null || package['price_total'] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.deepPurple.shade600,
                        Colors.deepPurple.shade800,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (package['price_monthly'] != null) ...[
                        const Text(
                          'Starting from',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${package['price_monthly'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'per month',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                      if (package['price_total'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Total: \$${package['price_total'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              
              // Features
              if (features.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'What\'s Included:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              
              const SizedBox(height: 24),
              
              // Subscribe Button (disabled for now)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: null, // Disabled for now
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text(
                    'Subscription Coming Soon',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

