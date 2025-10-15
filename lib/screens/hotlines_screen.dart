import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HotlinesScreen extends StatelessWidget {
  const HotlinesScreen({super.key});

  final List<Map<String, dynamic>> hotlines = const [
    {
      'category': 'CDRRMO',
      'numbers': [
        {'name': 'CDRRMO', 'number': '0917-711-3536'},
        {'name': 'CDRRMO', 'number': '0918-933-7858'},
        {'name': 'CDRRMO', 'number': '926-9274'},
      ]
    },
    {
      'category': 'ZCDRRMO',
      'numbers': [
        {'name': 'ZCDRRMO', 'number': '986-1171'},
        {'name': 'ZCDRRMO', 'number': '826-1848'},
        {'name': 'ZCDRRMO', 'number': '955-9801'},
        {'name': 'ZCDRRMO', 'number': '955-3850'},
        {'name': 'ZCDRRMO', 'number': '956-1871'},
        {'name': 'Emergency Operations Center', 'number': '0966-731-6242'},
        {'name': 'Emergency Operations Center', 'number': '0955-604-3882'},
        {'name': 'Emergency Operations Center', 'number': '0925-502-3829'},
        {'name': 'Technical Rescue/Fire Auxiliary', 'number': '0926-091-2492'},
        {'name': 'Services/Emergency Medical', 'number': '926-1848'},
      ]
    },
    {
      'category': 'Emergency Ciudad Medical (EMS)',
      'numbers': [
        {'name': 'EMS', 'number': '926-1849'},
      ]
    },
    {
      'category': 'Join Task Force Zamboanga (JTFZ)',
      'numbers': [
        {'name': 'JTFZ', 'number': '0917-710-2326'},
        {'name': 'JTFZ', 'number': '0916-535-8106'},
        {'name': 'JTFZ', 'number': '0928-396-9926'},
      ]
    },
    {
      'category': 'Zamboanga City Police Office (ZCPO)',
      'numbers': [
        {'name': 'ZCPO', 'number': '0977-855-8138'},
      ]
    },
    {
      'category': 'Police Stations',
      'stations': [
        {
          'name': 'PS1-Vitali',
          'numbers': [
            '0935-604-9139',
            '0988-967-3923',
          ]
        },
        {
          'name': 'PS2-Curuan',
          'numbers': [
            '0935-457-3483',
            '0918-230-7135',
          ]
        },
        {
          'name': 'PS3-Sangali',
          'numbers': [
            '0917-146-2400',
            '939-930-7144',
            '955-0156',
          ]
        },
        {
          'name': 'PS4-Culianan',
          'numbers': [
            '0975-333-9826',
            '0935-562-7161',
            '955-0255',
          ]
        },
        {
          'name': 'PS5-Divisoria',
          'numbers': [
            '0917-837-8907',
            '0998-967-3927',
            '955-6887',
          ]
        },
        {
          'name': 'PS6-Tetuan',
          'numbers': [
            '0997-746-6666',
            '0926-174-0151',
            '901-0678',
          ]
        },
        {
          'name': 'PS7-Sta. Maria',
          'numbers': [
            '0917-397-8098',
            '0998-967-3929',
            '985-9001',
          ]
        },
        {
          'name': 'PS8-Sininuc',
          'numbers': [
            '0906-853-9806',
            '0988-967-3930',
            '985-9001',
          ]
        },
        {
          'name': 'PS9-Ayala',
          'numbers': [
            '0998-967-3931',
            '0917-864-8553',
            '983-0001',
          ]
        },
        {
          'name': 'PS10-Labuan',
          'numbers': [
            '0917-309-3887',
            '0935-993-8033',
          ]
        },
        {
          'name': 'PS11-Central',
          'numbers': [
            '0917-701-4340',
            '0998-967-3934',
            '310-2030',
          ]
        },
      ]
    },
    {
      'category': 'Zamboanga City Mobile Force Company',
      'numbers': [
        {'name': '1ST ZCMFC', 'number': '0995-279-1449'},
        {'name': '2ND ZCMFC', 'number': '0905-886-0405'},
      ]
    },
    {
      'category': 'Fire Department',
      'numbers': [
        {'name': 'Zamboanga City Fire District', 'number': '991-3255'},
        {'name': 'Zamboanga City Fire District', 'number': '0955-781-6063'},
      ],
      'stations': [
        {
          'name': 'Putik Fire Sub-Station',
          'numbers': [
            '310-9797',
          ]
        },
        {
          'name': 'Lunzuran Fire Sub-Station',
          'numbers': [
            '310-7212',
            '0935-454-5366',
          ]
        },
        {
          'name': 'Guiwan Fire Sub-Station',
          'numbers': [
            '957-4372',
            '0916-135-2436',
          ]
        },
        {
          'name': 'Tumaga Fire Sub-Station',
          'numbers': [
            '991-5809',
          ]
        },
        {
          'name': 'Sta. Maria Fire Sub-Station',
          'numbers': [
            '985-0520',
          ]
        },
        {
          'name': 'Tetuan Fire Sub-Station',
          'numbers': [
            '992-0620',
            '0906-441-1416',
          ]
        },
        {
          'name': 'Sta Catalina Fire Sub-Station',
          'numbers': [
            '957-3160',
            '0995-071-7746',
          ]
        },
        {
          'name': 'Mahaman Fire Sub-Station',
          'numbers': [
            '0975-074-1376',
          ]
        },
        {
          'name': 'Boalan Fire Sub-Station',
          'numbers': [
            '957-6217',
            '0997-703-1365',
          ]
        },
        {
          'name': 'Manicahan Fire Sub-Station',
          'numbers': [
            '0975-031-1372',
          ]
        },
        {
          'name': 'Quiniput Fire Sub-Station',
          'numbers': [
            '0975-197-3009',
          ]
        },
        {
          'name': 'Culianan Fire Sub-Station',
          'numbers': [
            '310-0313',
            '0975-255-3899',
          ]
        },
        {
          'name': 'Vitalli Fire Sub-Station',
          'numbers': [
            '0965-185-7746',
            '0999-518-4848',
          ]
        },
        {
          'name': 'San Jose Guling Fire Sub-Station',
          'numbers': [
            '0914-701-0209',
          ]
        },
        {
          'name': 'Calarian Fire Sub-Station',
          'numbers': [
            '0917-106-2785',
            '957-4440',
          ]
        },
        {
          'name': 'Recodo Fire Sub-Station',
          'numbers': [
            '957-3729',
            '0936-256-7071',
          ]
        },
        {
          'name': 'Talisayan Fire Sub-Station',
          'numbers': [
            '0936-462-2070',
          ]
        },
        {
          'name': 'Ayala Fire Sub-Station',
          'numbers': [
            '957-6209',
            '0953-149-9756',
          ]
        },
        {
          'name': 'Labuan Fire Sub-Station',
          'numbers': [
            '0927-493-5473',
          ]
        },
      ]
    },
  ];

@override
Widget build(BuildContext context) {
  return Scaffold(
    // Set a background color that matches your design to prevent black flash
    backgroundColor: const Color(0xFFF8FAFC),
    
    body: Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/LIGHT.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        // Colored overlay
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC).withOpacity(0.2),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                pinned: false,
                floating: false,
                expandedHeight: 0,
                flexibleSpace: Container(), // Add empty container to ensure proper rendering
                
                title: const Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.8,
                    color: Color(0xFF1A1D29),
                  ),
                ),
                foregroundColor: const Color(0xFF1A1D29),
                centerTitle: false,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Color(0xFF6B7280),
                      size: 18,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ];
          },
          body: CustomScrollView(
            slivers: [
              // Updated Header Section
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    children: [
                      // Main header card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 92, 118, 165), // Indigo
                              Color.fromARGB(255, 61, 91, 131), // Purple
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Contact icon instead of logo
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                               Icons.phone_in_talk,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Tap to call or send SMS instantly',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Hotline Services',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Stats row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '24/7 Available',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 911 Emergency button (enhanced)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade200.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _makePhoneCall('911'),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.call_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '911',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        Text(
                                          'Emergency Hotline',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Enhanced Hotlines List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = hotlines[index];
                    return Container(
                      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          childrenPadding: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          iconColor: Colors.grey[400],
                          collapsedIconColor: Colors.grey[400],
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getCategoryColor(category['category']).withOpacity(0.1),
                                      _getCategoryColor(category['category']).withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _getCategoryColor(category['category']).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  _getCategoryIcon(category['category']),
                                  color: _getCategoryColor(category['category']),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category['category'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getCategoryDescription(category['category']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          children: _buildCategoryContent(category),
                        ),
                      ),
                    );
                  },
                  childCount: hotlines.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    ),
  );
}

// Helper method to get category descriptions
String _getCategoryDescription(String category) {
  switch (category.toLowerCase()) {
    case 'general emergency':
      return 'All-purpose emergency line';
    case 'cdrrmo':
    case 'zcdrrmo':
      return 'Disaster risk management';
    case 'emergency ciudad medical (ems)':
      return 'Medical emergencies';
    case 'join task force zamboanga (jtfz)':
      return 'Joint security operations';
    case 'zamboanga city police office (zcpo)':
      return 'Police headquarters';
    case 'police stations':
      return 'Local police stations';
    case 'fire department':
      return 'Fire and rescue services';
    case 'zamboanga city mobile force company':
      return 'Mobile security units';
    default:
      return 'Emergency services';
  }
}

  List<Widget> _buildCategoryContent(Map<String, dynamic> category) {
    List<Widget> children = [];
    
    // Add regular numbers if they exist
    if (category.containsKey('numbers')) {
      children.addAll(
        (category['numbers'] as List<Map<String, String>>).map(
          (hotline) => _buildHotlineItem(
            hotline['name']!,
            hotline['number']!,
          ),
        ),
      );
    }
    
    // Add stations if they exist (for Police Stations and Fire Department)
    if (category.containsKey('stations')) {
      children.addAll(_buildStations(category['stations']));
    }
    
    return children;
  }

  List<Widget> _buildStations(List<Map<String, dynamic>> stations) {
    return stations.map((station) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              station['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
          ),
          ...station['numbers'].map<Widget>(
            (number) => _buildHotlineItem(station['name'], number),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildHotlineItem(String name, String number) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  number,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.call_rounded,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  onPressed: () => _makePhoneCall(number),
                  tooltip: 'Call',
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.message_rounded,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  onPressed: () => _sendSMS(number),
                  tooltip: 'SMS',
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cdrrmo':
      case 'zcdrrmo':
        return Icons.warning_rounded;
      case 'emergency ciudad medical (ems)':
        return Icons.local_hospital_rounded;
      case 'join task force zamboanga (jtfz)':
        return Icons.security_rounded;
      case 'zamboanga city police office (zcpo)':
      case 'police stations':
        return Icons.local_police_rounded;
      case 'fire department':
        return Icons.local_fire_department_rounded;
      case 'zamboanga city mobile force company':
        return Icons.shield_rounded;
      default:
        return Icons.contact_phone_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'cdrrmo':
      case 'zcdrrmo':
        return Colors.orange.shade600;
      case 'emergency ciudad medical (ems)':
        return Colors.pink.shade600;
      case 'join task force zamboanga (jtfz)':
        return Colors.indigo.shade600;
      case 'zamboanga city police office (zcpo)':
      case 'police stations':
        return Colors.blue.shade600;
      case 'fire department':
        return Colors.deepOrange.shade600;
      case 'zamboanga city mobile force company':
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }
}