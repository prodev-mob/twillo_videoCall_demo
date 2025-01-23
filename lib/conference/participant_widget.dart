import 'package:flutter/material.dart';

class ParticipantInfo {
  final Widget remoteVideoTrack;
  final String? id;

  const ParticipantInfo({
    required this.remoteVideoTrack,
    required this.id,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ParticipantInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
