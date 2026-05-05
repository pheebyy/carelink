import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BidExpirationHelper {
  /// Calculate time remaining until bid expires
  static Duration? calculateTimeRemaining(Timestamp? expiresAt) {
    if (expiresAt == null) return null;

    final now = DateTime.now();
    final expirationDate = expiresAt.toDate();

    if (expirationDate.isBefore(now)) {
      return null; // Already expired
    }

    return expirationDate.difference(now);
  }

  /// Get remaining days
  static int getDaysRemaining(Timestamp? expiresAt) {
    final duration = calculateTimeRemaining(expiresAt);
    return duration?.inDays ?? 0;
  }

  /// Get remaining hours
  static int getHoursRemaining(Timestamp? expiresAt) {
    final duration = calculateTimeRemaining(expiresAt);
    return (duration?.inHours ?? 0) % 24;
  }

  /// Get remaining minutes
  static int getMinutesRemaining(Timestamp? expiresAt) {
    final duration = calculateTimeRemaining(expiresAt);
    return (duration?.inMinutes ?? 0) % 60;
  }

  /// Check if bid is expired
  static bool isExpired(Timestamp? expiresAt) {
    if (expiresAt == null) return false;
    return expiresAt.toDate().isBefore(DateTime.now());
  }

  /// Check if bid expires within 24 hours
  static bool isExpiringSoon(Timestamp? expiresAt) {
    final daysRemaining = getDaysRemaining(expiresAt);
    return daysRemaining == 0 && !isExpired(expiresAt);
  }

  /// Get expiration status
  static String getExpirationStatus(Timestamp? expiresAt) {
    if (isExpired(expiresAt)) return 'expired';
    if (isExpiringSoon(expiresAt)) return 'expiring_soon';
    return 'active';
  }

  /// Format time remaining for display
  static String formatTimeRemaining(Timestamp? expiresAt) {
    if (expiresAt == null) return 'No expiration set';

    if (isExpired(expiresAt)) {
      return '❌ Expired';
    }

    final days = getDaysRemaining(expiresAt);
    final hours = getHoursRemaining(expiresAt);
    final minutes = getMinutesRemaining(expiresAt);

    if (days > 0) {
      return '⏰ Expires in $days day${days > 1 ? 's' : ''}, $hours hour${hours != 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '⏱️ Expires in $hours hour${hours != 1 ? 's' : ''}, $minutes min${minutes != 1 ? 's' : ''}';
    } else {
      return '🚨 Expires in $minutes minute${minutes != 1 ? 's' : ''}';
    }
  }

  /// Get expiration color for UI
  static Color getExpirationColor(Timestamp? expiresAt) {
    if (isExpired(expiresAt)) return Colors.grey;
    if (isExpiringSoon(expiresAt)) return Colors.red;
    if (getDaysRemaining(expiresAt) <= 2) return Colors.orange;
    return Colors.green;
  }

  /// Get expiration icon
  static IconData getExpirationIcon(Timestamp? expiresAt) {
    if (isExpired(expiresAt)) return Icons.cancel;
    if (isExpiringSoon(expiresAt)) return Icons.warning;
    return Icons.schedule;
  }
}
