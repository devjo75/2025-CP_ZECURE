import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:zecure/services/gemini_service.dart';

class SafetyChatbotDropdown extends StatefulWidget {
  final LatLng? currentPosition;
  final List<Map<String, dynamic>> hotspots;
  final List<Map<String, dynamic>> safeSpots;

  const SafetyChatbotDropdown({
    super.key,
    this.currentPosition,
    required this.hotspots,
    required this.safeSpots,
  });

  @override
  State<SafetyChatbotDropdown> createState() => _SafetyChatbotDropdownState();
}

class _SafetyChatbotDropdownState extends State<SafetyChatbotDropdown> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final GeminiService _geminiService = GeminiService();
  late AnimationController _typingAnimationController;

  // Quick questions - compact version for dropdown
  final List<QuickQuestion> _quickQuestions = [
    QuickQuestion(icon: Icons.warning_amber_rounded, text: 'Recent crimes?', color: Colors.orange),
    QuickQuestion(icon: Icons.shield_outlined, text: 'Safe spots?', color: Colors.blue),
    QuickQuestion(icon: Icons.tips_and_updates_outlined, text: 'Safety tips', color: Colors.green),
    QuickQuestion(icon: Icons.phone_in_talk_rounded, text: 'Emergency', color: Colors.red),
  ];

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
      if (criticalCrimes > 0) safetyLevel = 'CAUTION';
      if (nearbyHotspots.length > 10) safetyLevel = 'HIGH ALERT';
      
      String welcomeMessage = '👋 **Hello! I\'m your Safety Assistant**\n\n';
      
      if (widget.currentPosition != null) {
        welcomeMessage += '📊 **Status: $safetyLevel**\n';
        welcomeMessage += '🔴 ${nearbyHotspots.length} incidents nearby\n';
        if (criticalCrimes > 0) {
          welcomeMessage += '⚠️ $criticalCrimes critical\n';
        }
        welcomeMessage += '🛡️ ${nearbySafeSpots.length} safe spots\n\n';
      }
      
      welcomeMessage += 'Ask me anything about safety in your area! 💬';
      
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
          text: '⚠️ Connection issue. Please check your internet and try again.',
          isUser: false,
          timestamp: DateTime.now(),
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
          text: '❌ Error: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
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
          '🚨 **911** - Police\n'
          '🚒 **117** - Fire\n'
          '🚑 **161** - Medical\n\n'
          '_Call immediately in emergencies!_';
    }
    
    if (lowerMessage.contains('report')) {
      return '🚨 **Report Incidents**\n\n'
          '1. Tap **"+" button** on map\n'
          '2. Select **"Report Crime"**\n'
          '3. Add details & submit\n\n'
          '📞 Or call **911** for emergencies';
    }
    
    if (lowerMessage.contains('safe at night')) {
      return '🌙 **Night Safety**\n\n'
          '✅ Stay in lit areas\n'
          '✅ Walk with others\n'
          '✅ Keep phone ready\n'
          '✅ Stay alert\n\n'
          '_Trust your instincts!_';
    }
    
    return '✅ **All Clear!**\n\n'
        'No incidents nearby. Stay safe! 🛡️';
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
  return Container(
    width: 450,
    height: 800, // Changed from maxHeight constraint to fixed height
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade700],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'AI-Powered',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                  onPressed: _showInfoDialog,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Quick Questions (only show when messages <= 2)
          if (_messages.length <= 2) _buildQuickQuestions(),

          const Divider(height: 1),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Input field
          const Divider(height: 1),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildQuickQuestions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _quickQuestions.map((q) => InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _sendMessage(q.text),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: q.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: q.color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(q.icon, size: 12, color: q.color),
                const SizedBox(width: 4),
                Text(
                  q.text,
                  style: TextStyle(
                    color: q.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: message.isUser ? Colors.blue.shade600 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildFormattedText(message.text, message.isUser),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 14, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isUser) {
    final textStyle = TextStyle(
      color: isUser ? Colors.white : Colors.black87,
      fontSize: 12,
      height: 1.4,
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

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
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
                      width: 6,
                      height: 6,
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask about safety...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) => _sendMessage(value),
              enabled: !_isLoading,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade700],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
              onPressed: _isLoading ? null : () => _sendMessage(_messageController.text),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Safety Assistant', style: TextStyle(fontSize: 16)),
        content: const Text(
          'AI-powered safety insights based on verified crime data.\n\n'
          '• Crime statistics\n'
          '• Safe locations\n'
          '• Emergency help',
          style: TextStyle(fontSize: 13),
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