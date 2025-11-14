import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'safe_spot_edit_form.dart';
import 'safe_spot_service.dart';

class SafeSpotDetails {
  static void showSafeSpotDetails({
    required BuildContext context,
    required Map<String, dynamic> safeSpot,
    required Map<String, dynamic>? userProfile,
    required bool isAdmin,
    required VoidCallback onUpdate,
    required Future<void> Function(LatLng destination) onGetSafeRoute,
  }) async {
    final lat = safeSpot['location']['coordinates'][1];
    final lng = safeSpot['location']['coordinates'][0];
    final coordinates =
        "(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";

    String address = "Loading address...";
    String fullLocation = coordinates;

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        address = data['display_name'] ?? "Unknown location";
        fullLocation = "$address\n$coordinates";
      }
    } catch (e) {
      address = "Could not load address";
      fullLocation = "$address\n$coordinates";
    }

    final DateTime createdTime = DateTime.parse(
      safeSpot['created_at'],
    ).toLocal();
    final formattedTime = DateFormat(
      'MMM dd, yyyy - hh:mm a',
    ).format(createdTime);
    final status = safeSpot['status'] ?? 'pending';
    final verified = safeSpot['verified'] ?? false;
    final verifiedByAdmin = safeSpot['verified_by_admin'] ?? false;
    const displayMinimum = 4;

    final isOwner =
        (userProfile?['id'] != null) &&
        (safeSpot['created_by'] == userProfile!['id']);
    final safeSpotType = safeSpot['safe_spot_types'];

    // Check if user has upvoted (if logged in)
    bool hasUpvoted = false;
    if (userProfile != null) {
      try {
        hasUpvoted = await SafeSpotService.hasUserUpvoted(
          safeSpotId: safeSpot['id'],
          userId: userProfile['id'],
        );
      } catch (e) {
        // Handle error silently
      }
    }

    // Inside SafeSpotDetails.showSafeSpotDetails
    final officerDetails = <String, String>{};
    try {
      final status = safeSpot['status'] ?? 'pending';
      final createdAt = DateTime.parse(safeSpot['created_at']);
      final updatedAt = safeSpot['updated_at'] != null
          ? DateTime.parse(safeSpot['updated_at'])
          : createdAt;
      final hasUpdateAfterApproval =
          status == 'approved' &&
          safeSpot['updated_profile'] != null &&
          updatedAt.isAfter(createdAt);

      // Populate officer details based on status
      if (status == 'approved' && safeSpot['approved_profile'] != null) {
        officerDetails['approved_by'] =
            '${safeSpot['approved_profile']['first_name'] ?? ''} ${safeSpot['approved_profile']['last_name'] ?? ''}'
                .trim();
      } else if (status == 'rejected' && safeSpot['rejected_profile'] != null) {
        officerDetails['rejected_by'] =
            '${safeSpot['rejected_profile']['first_name'] ?? ''} ${safeSpot['rejected_profile']['last_name'] ?? ''}'
                .trim();
      }

      // Show last_updated_by only if there’s an update profile after approval
      if (hasUpdateAfterApproval) {
        officerDetails['last_updated_by'] =
            '${safeSpot['updated_profile']['first_name'] ?? ''} ${safeSpot['updated_profile']['last_name'] ?? ''}'
                .trim();
      }
    } catch (e) {
      print('Error processing officer details: $e');
      officerDetails['approved_by'] = '';
      officerDetails['rejected_by'] = '';
      officerDetails['last_updated_by'] = '';
    }

    // Check if it's desktop/web
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SafeSpotDetailsContent(
              safeSpot: safeSpot,
              userProfile: userProfile,
              isAdmin: isAdmin,
              onUpdate: onUpdate,
              address: address,
              fullLocation: fullLocation,
              formattedTime: formattedTime,
              status: status,
              verified: verified,
              verifiedByAdmin: verifiedByAdmin,
              isOwner: isOwner,
              safeSpotType: safeSpotType,
              hasUpvoted: hasUpvoted,
              displayMinimum: displayMinimum,
              isDesktop: true,
              onGetSafeRoute: onGetSafeRoute,
              officerDetails: officerDetails,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: true,
        isDismissible: true,
        builder: (context) => SafeSpotDetailsContent(
          safeSpot: safeSpot,
          userProfile: userProfile,
          isAdmin: isAdmin,
          onUpdate: onUpdate,
          address: address,
          fullLocation: fullLocation,
          formattedTime: formattedTime,
          status: status,
          verified: verified,
          verifiedByAdmin: verifiedByAdmin,
          isOwner: isOwner,
          safeSpotType: safeSpotType,
          hasUpvoted: hasUpvoted,
          displayMinimum: displayMinimum,
          isDesktop: false,
          onGetSafeRoute: onGetSafeRoute,
          officerDetails: officerDetails,
        ),
      );
    }
  }

  // Show reject dialog
  static void _showRejectDialog(
    BuildContext context,
    String safeSpotId,
    VoidCallback onUpdate,
    String adminId,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Safe Spot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this safe spot:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SafeSpotService.updateSafeSpotStatus(
                  safeSpotId: safeSpotId,
                  status: 'rejected',
                  rejectionReason: reasonController.text.trim().isEmpty
                      ? null
                      : reasonController.text.trim(),
                  adminId: adminId,
                );
                onUpdate();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close details sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Safe spot rejected')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // Show delete confirmation dialog
  static void _showDeleteDialog(
    BuildContext context,
    String safeSpotId,
    VoidCallback onUpdate,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Safe Spot'),
        content: const Text(
          'Are you sure you want to delete this safe spot? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SafeSpotService.deleteSafeSpot(safeSpotId);
                onUpdate();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close details sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Safe spot deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Helper method to convert string to IconData
  static IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'local_police':
        return Icons.local_police;
      case 'account_balance':
        return Icons.account_balance;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'shopping_mall':
        return Icons.store;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'security':
        return Icons.security;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'church':
        return Icons.church;
      case 'community':
        return Icons.group;
      default:
        return Icons.place;
    }
  }
}

class SafeSpotDetailsContent extends StatefulWidget {
  final Map<String, dynamic> safeSpot;
  final Map<String, dynamic>? userProfile;
  final bool isAdmin;
  final VoidCallback onUpdate;
  final String address;
  final String fullLocation;
  final String formattedTime;
  final String status;
  final bool verified;
  final bool verifiedByAdmin;
  final bool isOwner;
  final Map<String, dynamic> safeSpotType;
  final bool hasUpvoted;
  final int displayMinimum;
  final bool isDesktop;
  final Function(LatLng) onGetSafeRoute;
  final Map<String, String> officerDetails;

  const SafeSpotDetailsContent({
    super.key,
    required this.safeSpot,
    required this.userProfile,
    required this.isAdmin,
    required this.onUpdate,
    required this.address,
    required this.fullLocation,
    required this.formattedTime,
    required this.status,
    required this.verified,
    required this.verifiedByAdmin,
    required this.isOwner,
    required this.safeSpotType,
    required this.hasUpvoted,
    required this.displayMinimum,
    required this.isDesktop,
    required this.onGetSafeRoute,
    required this.officerDetails,
  });

  @override
  State<SafeSpotDetailsContent> createState() => _SafeSpotDetailsContentState();
}

class _SafeSpotDetailsContentState extends State<SafeSpotDetailsContent> {
  late bool hasUpvoted;

  @override
  void initState() {
    super.initState();
    hasUpvoted = widget.hasUpvoted;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Prevents dismissal when tapping content
      child: Container(
        constraints: widget.isDesktop
            ? null
            : BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.95,
                minHeight: MediaQuery.of(context).size.height * 0.2,
              ),
        decoration: widget.isDesktop
            ? null
            : const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle at the top (only for mobile)
            if (!widget.isDesktop)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            // Content wrapper
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon and name
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            SafeSpotDetails._getIconFromString(
                              widget.safeSpotType['icon'],
                            ),
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.safeSpot['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    widget.safeSpotType['name'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildStatusWidget(
                                    widget.status,
                                    widget.verified,
                                    widget.verifiedByAdmin,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Description
                    if (widget.safeSpot['description'] != null &&
                        widget.safeSpot['description']
                            .toString()
                            .trim()
                            .isNotEmpty)
                      _buildInfoTile(
                        'Description',
                        widget.safeSpot['description'],
                        Icons.description,
                      ),

                    // Location
                    _buildInfoTile(
                      'Location',
                      widget.address,
                      Icons.location_on,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.fullLocation),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Location copied to clipboard'),
                            ),
                          );
                        },
                      ),
                      subtitle:
                          "(${widget.safeSpot['location']['coordinates'][1].toStringAsFixed(6)}, ${widget.safeSpot['location']['coordinates'][0].toStringAsFixed(6)})",
                    ),

                    // Get Safe Route button below lat/long
                    Padding(
                      padding: const EdgeInsets.only(left: 34, top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            print('Get Safe Route button clicked');
                            final coords =
                                widget.safeSpot['location']['coordinates'];
                            final safeSpotLocation = LatLng(
                              coords[1],
                              coords[0],
                            );
                            print('Safe spot location: $safeSpotLocation');

                            Navigator.pop(context);
                            print('Calling onGetSafeRoute callback');
                            widget.onGetSafeRoute(safeSpotLocation);
                          },
                          icon: const Icon(Icons.safety_check, size: 15),
                          label: const Text('Get Safe Route'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                    ),

                    // Created time
                    _buildInfoTile(
                      'Created',
                      widget.formattedTime,
                      Icons.access_time,
                    ),

                    // Officer details section (visible only to admins) - CLEANED
                    if (widget.isAdmin)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              (widget
                                      .officerDetails['approved_by']
                                      ?.isNotEmpty ??
                                  false)
                              ? Colors.green.shade50
                              : (widget
                                        .officerDetails['rejected_by']
                                        ?.isNotEmpty ??
                                    false)
                              ? Colors.red.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                (widget
                                        .officerDetails['approved_by']
                                        ?.isNotEmpty ??
                                    false)
                                ? Colors.green.shade200
                                : (widget
                                          .officerDetails['rejected_by']
                                          ?.isNotEmpty ??
                                      false)
                                ? Colors.red.shade200
                                : Colors.blue.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Review Status Header
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color:
                                      (widget
                                              .officerDetails['approved_by']
                                              ?.isNotEmpty ??
                                          false)
                                      ? Colors.green.shade600
                                      : (widget
                                                .officerDetails['rejected_by']
                                                ?.isNotEmpty ??
                                            false)
                                      ? Colors.red.shade600
                                      : Colors.blue.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Review Status',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Creator (just under Review Status)
                            Builder(
                              builder: (context) {
                                final creatorProfile = widget.safeSpot['users'];
                                if (creatorProfile != null) {
                                  final creatorName =
                                      '${creatorProfile['first_name'] ?? ''} ${creatorProfile['last_name'] ?? ''}'
                                          .trim();
                                  if (creatorName.isNotEmpty) {
                                    return Text(
                                      '📝 Created by: $creatorName',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    );
                                  }
                                }
                                return Text(
                                  'Creator information not available',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),

                            // Approved
                            if (widget
                                    .officerDetails['approved_by']
                                    ?.isNotEmpty ??
                                false) ...[
                              Text(
                                '✅ Approved by: ${widget.officerDetails['approved_by']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],

                            // Rejected
                            if (widget
                                    .officerDetails['rejected_by']
                                    ?.isNotEmpty ??
                                false) ...[
                              Text(
                                '❌ Rejected by: ${widget.officerDetails['rejected_by']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],

                            // Last updated (only if unique)
                            Builder(
                              builder: (context) {
                                final lastUpdatedBy =
                                    widget.officerDetails['last_updated_by'];
                                final approvedBy =
                                    widget.officerDetails['approved_by'];
                                final rejectedBy =
                                    widget.officerDetails['rejected_by'];

                                final creatorProfile = widget.safeSpot['users'];
                                final creatorName = creatorProfile != null
                                    ? '${creatorProfile['first_name'] ?? ''} ${creatorProfile['last_name'] ?? ''}'
                                          .trim()
                                    : '';

                                if (lastUpdatedBy?.isNotEmpty ?? false) {
                                  if (lastUpdatedBy != approvedBy &&
                                      lastUpdatedBy != rejectedBy &&
                                      lastUpdatedBy != creatorName) {
                                    return Column(
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          '🔄 Last updated by: $lastUpdatedBy',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),

                    // Upvote section
                    if (widget.status == 'pending') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Community Votes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${widget.safeSpot['upvote_count'] ?? 0} of ${widget.displayMinimum} needed',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),

                                // Voting button
                                if (widget.userProfile != null &&
                                    !widget.isOwner)
                                  ElevatedButton.icon(
                                    // In safe_spot_details.dart, replace the upvote button onPressed with this:
                                    onPressed: () async {
                                      try {
                                        final bool newUpvoteState = !hasUpvoted;

                                        // Optimistically update UI
                                        setState(() {
                                          hasUpvoted = newUpvoteState;
                                        });

                                        if (newUpvoteState) {
                                          await SafeSpotService.upvoteSafeSpot(
                                            safeSpotId: widget.safeSpot['id'],
                                            userId: widget.userProfile!['id'],
                                          );
                                        } else {
                                          await SafeSpotService.removeUpvote(
                                            safeSpotId: widget.safeSpot['id'],
                                            userId: widget.userProfile!['id'],
                                          );
                                        }

                                        // Refresh the actual data from database (don't manipulate counts locally)
                                        final actualUpvoteCount =
                                            await SafeSpotService.getSafeSpotUpvoteCount(
                                              widget.safeSpot['id'],
                                            );
                                        final actualHasUpvoted =
                                            await SafeSpotService.hasUserUpvoted(
                                              safeSpotId: widget.safeSpot['id'],
                                              userId: widget.userProfile!['id'],
                                            );

                                        // Update UI with actual database values
                                        setState(() {
                                          hasUpvoted = actualHasUpvoted;
                                          widget.safeSpot['upvote_count'] =
                                              actualUpvoteCount;
                                        });

                                        widget
                                            .onUpdate(); // Refresh parent view
                                      } catch (e) {
                                        // Revert optimistic update on error
                                        setState(() {
                                          hasUpvoted = !hasUpvoted;
                                        });

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Voting failed: ${e.toString()}',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      hasUpvoted
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_outlined,
                                      size: 14,
                                    ),
                                    label: Text(
                                      hasUpvoted ? 'Voted' : 'Vote',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: hasUpvoted
                                          ? Colors.green
                                          : Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value:
                                  ((widget.safeSpot['upvote_count'] ?? 0) /
                                          widget.displayMinimum)
                                      .clamp(0.0, 1.0),
                              backgroundColor: Colors.blue.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Show rejection reason for rejected spots
                    if (widget.status == 'rejected' &&
                        widget.safeSpot['rejection_reason'] != null)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.cancel,
                                  color: Colors.red.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Rejection Reason:',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.safeSpot['rejection_reason']
                                      .toString()
                                      .trim()
                                      .isEmpty
                                  ? 'No reason provided'
                                  : widget.safeSpot['rejection_reason'],
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Show approval note for approved spots
                    if (widget.status == 'approved' &&
                        !widget.isAdmin &&
                        widget.isOwner)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.verified
                                    ? widget.verifiedByAdmin
                                          ? 'Your safe spot has been approved and verified by an admin!'
                                          : 'Your safe spot has been approved and verified by the community!'
                                    : 'Your safe spot has been approved by the community.',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Edit button for admin on pending spots
                    if (widget.isAdmin && widget.status == 'pending')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              SafeSpotEditForm.showEditForm(
                                context: context,
                                safeSpot: widget.safeSpot,
                                userProfile: widget.userProfile,
                                onUpdate: widget.onUpdate,
                              );
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text(
                              'Edit Safe Spot',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Admin actions for pending spots
                    if (widget.isAdmin && widget.status == 'pending')
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  await SafeSpotService.updateSafeSpotStatus(
                                    safeSpotId: widget.safeSpot['id'],
                                    status: 'approved',
                                    adminId: widget.userProfile!['id'],
                                  );
                                  widget.onUpdate();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Safe spot approved'),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  SafeSpotDetails._showRejectDialog(
                                    context,
                                    widget.safeSpot['id'],
                                    widget.onUpdate,
                                    widget.userProfile!['id'],
                                  ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  SafeSpotDetails._showDeleteDialog(
                                    context,
                                    widget.safeSpot['id'],
                                    widget.onUpdate,
                                  ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),

                    // Owner actions for pending spots
                    if (!widget.isAdmin &&
                        widget.status == 'pending' &&
                        widget.isOwner)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                SafeSpotEditForm.showEditForm(
                                  context: context,
                                  safeSpot: widget.safeSpot,
                                  userProfile: widget.userProfile,
                                  onUpdate: widget.onUpdate,
                                );
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  SafeSpotDetails._showDeleteDialog(
                                    context,
                                    widget.safeSpot['id'],
                                    widget.onUpdate,
                                  ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),

                    // Actions for rejected spots
                    if (widget.status == 'rejected')
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  SafeSpotDetails._showDeleteDialog(
                                    context,
                                    widget.safeSpot['id'],
                                    widget.onUpdate,
                                  ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),

                    // Admin actions for approved spots
                    if (widget.isAdmin && widget.status == 'approved')
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                SafeSpotEditForm.showEditForm(
                                  context: context,
                                  safeSpot: widget.safeSpot,
                                  userProfile: widget.userProfile,
                                  onUpdate: widget.onUpdate,
                                );
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  SafeSpotDetails._showDeleteDialog(
                                    context,
                                    widget.safeSpot['id'],
                                    widget.onUpdate,
                                  ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
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

  // Helper method to build info tiles
  Widget _buildInfoTile(
    String title,
    String content,
    IconData icon, {
    Widget? trailing,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // Helper method to build status widget
  Widget _buildStatusWidget(
    String status,
    bool verified,
    bool verifiedByAdmin,
  ) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      case 'approved':
        if (verified) {
          color = Colors.green;
          text = verifiedByAdmin ? 'Admin Verified' : 'Community Verified';
          icon = Icons.verified;
        } else {
          color = Colors.blue;
          text = 'Approved';
          icon = Icons.check;
        }
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Rejected';
        icon = Icons.close;
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
