import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:zecure/services/gemini_service.dart';

class SafetyChatbotScreen extends StatefulWidget {
  final LatLng? currentPosition;
  final List<Map<String, dynamic>> hotspots;
  final List<Map<String, dynamic>> safeSpots;

  const SafetyChatbotScreen({
    super.key,
    this.currentPosition,
    required this.hotspots,
    required this.safeSpots,
  });

  @override
  State<SafetyChatbotScreen> createState() => _SafetyChatbotScreenState();
}

class _SafetyChatbotScreenState extends State<SafetyChatbotScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final GeminiService _geminiService = GeminiService();
  late AnimationController _typingAnimationController;

  // Enhanced quick questions with categories
  final Map<String, List<QuickQuestion>> _categorizedQuestions = {
    'Crime Info': [
      QuickQuestion(
        icon: Icons.warning_amber_rounded,
        text: 'What crimes happened recently?',
        color: Colors.orange,
      ),
      QuickQuestion(
        icon: Icons.analytics_outlined,
        text: 'Crime statistics in my area',
        color: Colors.red,
      ),
    ],
    'Safety': [
      QuickQuestion(
        icon: Icons.dark_mode_outlined,
        text: 'Is it safe to walk at night?',
        color: Colors.indigo,
      ),
      QuickQuestion(
        icon: Icons.tips_and_updates_outlined,
        text: 'Give me safety tips',
        color: Colors.green,
      ),
    ],
    'Locations': [
      QuickQuestion(
        icon: Icons.shield_outlined,
        text: 'Where are safe spots?',
        color: Colors.blue,
      ),
      QuickQuestion(
        icon: Icons.location_on_outlined,
        text: 'Show me police stations',
        color: Colors.cyan,
      ),
    ],
    'Help': [
      QuickQuestion(
        icon: Icons.report_outlined,
        text: 'How do I report a crime?',
        color: Colors.purple,
      ),
      QuickQuestion(
        icon: Icons.phone_in_talk_rounded,
        text: 'Emergency contacts',
        color: Colors.red,
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _initializeChatbot();
  }

  @override
  void dispose() {
    _typingAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChatbot() async {
    try {
      await _geminiService.initialize();
      
      final nearbyHotspots = _getNearbyHotspots();
      final nearbySafeSpots = _getNearbySafeSpots();
      
      final criticalCrimes = nearbyHotspots.where((h) => 
        h['crime_type']?['level'] == 'critical'
      ).length;
      
      String safetyLevel = 'GOOD';
      
      if (criticalCrimes > 0) {
        safetyLevel = 'CAUTION';
      }
      if (nearbyHotspots.length > 10) {
        safetyLevel = 'HIGH ALERT';
      }
      
      String welcomeMessage = '👋 Hello! I\'m your **Community Safety Assistant**.\n\n';
      
      if (widget.currentPosition != null) {
        welcomeMessage += '📊 **Your Area Status: $safetyLevel**\n\n';
        welcomeMessage += '**Recent Activity (5km radius):**\n';
        welcomeMessage += '🔴 ${nearbyHotspots.length} crime incidents\n';
        if (criticalCrimes > 0) {
          welcomeMessage += '⚠️ $criticalCrimes critical incidents\n';
        }
        welcomeMessage += '🛡️ ${nearbySafeSpots.length} safe spots nearby\n\n';
      } else {
        welcomeMessage += '⚠️ **Location not available**\n';
        welcomeMessage += 'Enable location for personalized safety insights.\n\n';
      }
      
      welcomeMessage += '**I can help you with:**\n';
      welcomeMessage += '• 🔍 Crime analysis & trends\n';
      welcomeMessage += '• 🛡️ Safety recommendations\n';
      welcomeMessage += '• 📍 Nearby safe locations\n';
      welcomeMessage += '• 📞 Emergency procedures\n';
      welcomeMessage += '• 🚨 How to report incidents\n\n';
      welcomeMessage += 'Try the quick questions below or ask me anything! 💬';
      
      setState(() {
        _messages.add(ChatMessage(
          text: welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
          hasMarkdown: true,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: '⚠️ **Connection Issue**\n\n'
                'I\'m having trouble starting up. Please check:\n\n'
                '1. Your internet connection\n'
                '2. Try restarting the app\n\n'
                'If the problem persists, contact support.\n\n'
                '_Error: ${e.toString()}_',
          isUser: false,
          timestamp: DateTime.now(),
          hasMarkdown: true,
        ));
      });
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final nearbyHotspots = _getNearbyHotspots();
      final nearbySafeSpots = _getNearbySafeSpots();

      String locationStr = 'Location not available';
      if (widget.currentPosition != null) {
        locationStr = 'Lat: ${widget.currentPosition!.latitude.toStringAsFixed(4)}, '
            'Lng: ${widget.currentPosition!.longitude.toStringAsFixed(4)}';
      }

      final isGeneralQuestion = _isGeneralSafetyQuestion(message);
      
      String response;
      if (nearbyHotspots.isEmpty && nearbySafeSpots.isEmpty && !isGeneralQuestion) {
        response = _getGeneralSafetyResponse(message);
      } else {
        response = await _geminiService.generateSafetyResponse(
          userMessage: message,
          nearbyHotspots: nearbyHotspots,
          nearbySafeSpots: nearbySafeSpots,
          userLocation: locationStr,
        );
      }

      response = _enhanceResponseFormatting(response);

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
          hasMarkdown: true,
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: '❌ **Error**\n\nI apologize, but I encountered an error. Please try again.\n\n_${e.toString()}_',
          isUser: false,
          timestamp: DateTime.now(),
          hasMarkdown: true,
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  String _enhanceResponseFormatting(String response) {
    final keywords = ['IMPORTANT', 'WARNING', 'CAUTION', 'SAFE', 'DANGER', 'URGENT'];
    for (final keyword in keywords) {
      response = response.replaceAll(keyword, '**$keyword**');
    }
    return response;
  }

  bool _isGeneralSafetyQuestion(String message) {
    final generalKeywords = [
      'how to report', 'report suspicious', 'safety tips', 
      'what to do', 'emergency', 'contact', 'police',
      'safe at night', 'stay safe', 'protect myself',
      'emergency contact', 'hotline', 'phone number'
    ];
    
    final lowerMessage = message.toLowerCase();
    return generalKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  String _getGeneralSafetyResponse(String message) {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('emergency') || lowerMessage.contains('hotline') || lowerMessage.contains('contact')) {
      return '📞 **Emergency Contacts**\n\n'
          '**In Case of Emergency:**\n'
          '🚨 **911** - Police Emergency\n'
          '🚒 **117** - Fire Department\n'
          '🚑 **161** - Medical Emergency\n\n'
          '**Quick Access:**\n'
          'Tap the phone icon 📞 in the search bar to view all emergency hotlines!\n\n'
          '**When to Call:**\n'
          '• Crime in progress\n'
          '• Immediate danger\n'
          '• Medical emergency\n'
          '• Fire or disaster\n\n'
          '_Stay safe! Always call immediately in emergencies._';
    }
    
    if (lowerMessage.contains('report') || lowerMessage.contains('suspicious')) {
      return '🚨 **How to Report Incidents**\n\n'
          '**Using This App:**\n'
          '1. Tap the **"+" button** on the map\n'
          '2. Select **"Report Crime"**\n'
          '3. Choose incident type & add details\n'
          '4. Submit for review\n\n'
          '**Other Methods:**\n'
          '📞 Call **911** for emergencies\n'
          '🏛️ Visit nearest police station\n'
          '💻 Anonymous tips hotline\n\n'
          '**What to Include:**\n'
          '• Time and location\n'
          '• What you witnessed\n'
          '• Description of people/vehicles\n'
          '• Photos if safe to take\n\n'
          '_Currently: No recent reports in your area 🎉_';
    }
    
    if (lowerMessage.contains('safe at night') || lowerMessage.contains('walk')) {
      return '🌙 **Night Safety Tips**\n\n'
          '**Before You Go:**\n'
          '✅ Tell someone your route\n'
          '✅ Charge your phone fully\n'
          '✅ Check the safe route in app\n\n'
          '**While Walking:**\n'
          '🔦 Stay in well-lit areas\n'
          '👥 Walk with others if possible\n'
          '📱 Keep phone accessible\n'
          '👂 Avoid headphones\n'
          '👀 Stay alert & aware\n\n'
          '**Trust Your Instincts:**\n'
          'If something feels wrong, it probably is. Take action immediately!\n\n'
          '_Good news: No crime hotspots detected nearby! 🎊_';
    }
    
    if (lowerMessage.contains('safe spot') || lowerMessage.contains('where')) {
      return '🛡️ **Finding Safe Locations**\n\n'
          '**Recommended Safe Spots:**\n'
          '🏛️ Police stations (24/7)\n'
          '🏥 Hospitals & clinics\n'
          '🏫 Schools (during hours)\n'
          '🏪 Shopping malls & stores\n'
          '⛪ Churches & community centers\n'
          '💡 Well-lit public areas\n\n'
          '**Using the App:**\n'
          '1. Look for 🛡️ blue shield icons\n'
          '2. Tap for details & directions\n'
          '3. Use "Safe Route" feature\n\n'
          '**Add Safe Spots:**\n'
          'Found a safe place? Help the community by adding it to the map!\n\n'
          '_Check the map for verified safe locations near you._';
    }
    
    return '✅ **Safety Status: All Clear**\n\n'
        'No recent crime incidents reported in your immediate area.\n\n'
        '**General Safety Tips:**\n'
        '• Stay aware of surroundings\n'
        '• Keep emergency contacts handy\n'
        '• Report suspicious activity\n'
        '• Use well-lit routes at night\n'
        '• Travel in groups when possible\n\n'
        '**Need Help?**\n'
        'Try asking about:\n'
        '• "How do I report a crime?"\n'
        '• "Emergency contact numbers"\n'
        '• "Safety tips for walking at night"\n'
        '• "Where are safe spots nearby?"\n\n'
        '_The absence of reports is good news! Stay vigilant. 🛡️_';
  }

  List<Map<String, dynamic>> _getNearbyHotspots() {
    if (widget.currentPosition == null) return [];

    const Distance distance = Distance();
    return widget.hotspots.where((hotspot) {
      if (hotspot['status'] != 'approved' || hotspot['active_status'] != 'active') {
        return false;
      }

      try {
        final coords = _parseLocation(hotspot['location']);
        if (coords == null) return false;

        final dist = distance.as(LengthUnit.Kilometer, widget.currentPosition!, coords);
        return dist <= 5.0;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  List<Map<String, dynamic>> _getNearbySafeSpots() {
    if (widget.currentPosition == null) return [];

    const Distance distance = Distance();
    return widget.safeSpots.where((spot) {
      if (spot['status'] != 'approved') return false;

      try {
        final coords = _parseLocation(spot['location']);
        if (coords == null) return false;

        final dist = distance.as(LengthUnit.Kilometer, widget.currentPosition!, coords);
        return dist <= 5.0;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  LatLng? _parseLocation(dynamic location) {
    if (location == null) return null;
    
    try {
      final regex = RegExp(r'POINT\(([0-9.-]+) ([0-9.-]+)\)');
      final match = regex.firstMatch(location.toString());
      
      if (match != null) {
        final lng = double.parse(match.group(1)!);
        final lat = double.parse(match.group(2)!);
        return LatLng(lat, lng);
      }
    } catch (e) {
      print('Error parsing location: $e');
    }
    
    return null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // FIXED: Wrap in Expanded and use ListView for proper scrolling
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0) + (_messages.length <= 2 ? 1 : 0),
              itemBuilder: (context, index) {
                // Quick questions at the top (only shown when messages <= 2)
                if (index == 0 && _messages.length <= 2) {
                  return _buildQuickQuestionsGrid();
                }
                
                // Adjust index if quick questions are shown
                final adjustedIndex = _messages.length <= 2 ? index - 1 : index;
                
                // Typing indicator
                if (adjustedIndex == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                
                // Messages
                if (adjustedIndex >= 0 && adjustedIndex < _messages.length) {
                  return _buildMessageBubble(_messages[adjustedIndex]);
                }
                
                return const SizedBox.shrink();
              },
            ),
          ),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: message.isUser ? Colors.blue.shade600 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildFormattedText(message.text, message.isUser),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 20, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.blue.shade600,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Assistant',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Powered by Gemini AI',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: () => _showInfoDialog(),
        ),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Safety Assistant'),
        content: const Text(
          'I analyze real police data to provide safety insights for your area.\n\n'
          '• Crime statistics & trends\n'
          '• Safe location recommendations\n'
          '• Emergency procedures\n\n'
          'All responses are based on verified data.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

// ---------------------------------------------------------------
//  QUICK QUESTIONS – horizontal, scrollable, compact
// ---------------------------------------------------------------
Widget _buildQuickQuestionsGrid() {
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Quick Questions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Horizontal scrollable chips
        SizedBox(
          height: 44, // fixed height → no overflow
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: _categorizedQuestions.entries
                .expand((entry) => entry.value) // flatten all questions
                .map(_buildQuickQuestionChip)
                .toList(),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------
//  SINGLE QUICK-QUESTION CHIP (compact)
// ---------------------------------------------------------------
Widget _buildQuickQuestionChip(QuickQuestion question) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _sendMessage(question.text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: question.color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: question.color.withOpacity(0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(question.icon, size: 15, color: question.color),
            const SizedBox(width: 5),
            Text(
              question.text,
              style: TextStyle(
                color: question.color,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFormattedText(String text, bool isUser) {
    final textStyle = TextStyle(
      color: isUser ? Colors.white : Colors.black87,
      fontSize: 14,
      height: 1.5,
    );

    final spans = <TextSpan>[];
    final parts = text.split('**');
    
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        spans.add(TextSpan(text: parts[i], style: textStyle));
      } else {
        spans.add(TextSpan(
          text: parts[i],
          style: textStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _typingAnimationController,
                  builder: (context, child) {
                    final progress = (_typingAnimationController.value + (index * 0.3)) % 1.0;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600.withOpacity(0.3 + (progress * 0.7)),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Ask about safety in your area...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) => _sendMessage(value),
                enabled: !_isLoading,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade700],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _isLoading ? null : () => _sendMessage(_messageController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool hasMarkdown;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.hasMarkdown = false,
  });
}

class QuickQuestion {
  final IconData icon;
  final String text;
  final Color color;

  QuickQuestion({
    required this.icon,
    required this.text,
    required this.color,
  });
}