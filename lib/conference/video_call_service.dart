import 'dart:async';

import 'package:flutter_twilio/conference/participant_widget.dart';
import 'package:twilio_programmable_video/twilio_programmable_video.dart';
import 'package:uuid/uuid.dart';

class TwilioVideoService {
  static final TwilioVideoService _instance = TwilioVideoService._internal();

  factory TwilioVideoService() => _instance;

  TwilioVideoService._internal();

  late String _roomName;
  late String _token;
  late String _identity;

  late String _trackId;
  late Room _room;
  late VideoCapturer _cameraCapture;
  final Set<ParticipantInfo> _participants = {};

  late LocalAudioTrack _localAudioTrack;
  late LocalVideoTrack _localVideoTrack;
  late LocalDataTrack _localDataTrack;

  final StreamController<List<ParticipantInfo>> _participantsController = StreamController.broadcast();

  Stream<List<ParticipantInfo>> get participantsStream => _participantsController.stream;

  void initialize({
    required String roomName,
    required String token,
    required String identity,
  }) {
    _roomName = roomName;
    _token = token;
    _identity = identity;
    _trackId = Uuid().v4();
  }

  Future<void> connect() async {
    try {
      print('[APPDEBUG] VideoCallService.connect()');
      await TwilioProgrammableVideo.setAudioSettings(speakerphoneEnabled: true, bluetoothPreferred: true);

      final sources = await CameraSource.getSources();
      _cameraCapture = CameraCapturer(
        sources.firstWhere((source) => source.isFrontFacing),
      );

      _localAudioTrack = LocalAudioTrack(false, 'audio_track-$_trackId');
      _localVideoTrack = LocalVideoTrack(true, _cameraCapture);
      _localDataTrack = LocalDataTrack(DataTrackOptions(name: 'data_track-$_trackId'));

      var connectOptions = ConnectOptions(
        _token,
        roomName: _roomName,
        preferredAudioCodecs: [OpusCodec()],
        audioTracks: [_localAudioTrack],
        videoTracks: [_localVideoTrack],
        dataTracks: [_localDataTrack],
        enableNetworkQuality: true,
        enableDominantSpeaker: true,
      );

      _room = await TwilioProgrammableVideo.connect(connectOptions);
      _room.onConnected.listen(_onConnected);
      _room.onDisconnected.listen(_onDisconnected);
      _room.onReconnecting.listen(_onReconnecting);
      _room.onConnectFailure.listen(_onConnectFailure);
    } catch (err) {
      print('[APPDEBUG] $err');
      rethrow;
    }
  }

  Future<void> flipCamera() async {
    if (_cameraCapture is CameraCapturer) {
      final cameraCapturer = _cameraCapture as CameraCapturer;
      final sources = await CameraSource.getSources();

      final newSource = cameraCapturer.source?.isFrontFacing == true
          ? sources.firstWhere((source) {
              return source.isBackFacing;
            })
          : sources.firstWhere((source) {
              return source.isFrontFacing;
            });

      await cameraCapturer.switchCamera(newSource);
    }
  }

  bool isAudioTrackEnabled() => _localAudioTrack.isEnabled;

  void toggleAudioTrack(bool value) => _localAudioTrack.enable(value);

  Future<void> disconnect() async {
    await _room.disconnect();
  }

  void _onConnected(Room room) {
    print('[APPDEBUG] VideoCallService._onConnected => state: ${room.state}');

    _room.onParticipantConnected.listen(_onParticipantConnected);
    _room.onParticipantDisconnected.listen(_onParticipantDisconnected);

    final localParticipant = room.localParticipant;
    if (localParticipant != null) {
      _participants.add(
        ParticipantInfo(
          id: _identity,
          remoteVideoTrack: localParticipant.localVideoTracks[0].localVideoTrack.widget(),
        ),
      );
      _notifyParticipantsUpdated();
    }

    for (final remoteParticipant in room.remoteParticipants) {
      _addRemoteParticipantListeners(remoteParticipant);
    }
  }

  void _onDisconnected(RoomDisconnectedEvent event) {
    print('[APPDEBUG] VideoCallService._onDisconnected');
    _participants.clear();
    _notifyParticipantsUpdated();
  }

  void _onReconnecting(RoomReconnectingEvent room) {
    print('[APPDEBUG] VideoCallService._onReconnecting');
  }

  void _onConnectFailure(RoomConnectFailureEvent event) {
    print('[APPDEBUG] VideoCallService._onConnectFailure: ${event.exception}');
  }

  void _onParticipantConnected(RoomParticipantConnectedEvent event) {
    print('[APPDEBUG] VideoCallService._onParticipantConnected, ${event.remoteParticipant.sid}');
    _addRemoteParticipantListeners(event.remoteParticipant);
  }

  void _onParticipantDisconnected(RoomParticipantDisconnectedEvent event) {
    print('[APPDEBUG] VideoCallService._onParticipantDisconnected: ${event.remoteParticipant.sid}');
    _participants.removeWhere((p) => p.id == event.remoteParticipant.sid);
    _notifyParticipantsUpdated();
  }

  void _addRemoteParticipantListeners(RemoteParticipant remoteParticipant) {
    remoteParticipant.onVideoTrackSubscribed.listen((event) {
      _participants.add(
        ParticipantInfo(
          id: remoteParticipant.sid,
          remoteVideoTrack: event.remoteVideoTrack.widget(),
        ),
      );
      _notifyParticipantsUpdated();
    });
    remoteParticipant.onAudioTrackSubscribed.listen((event) {
      print('[APPDEBUG] Audio track subscribed for ${remoteParticipant.sid}');
    });
  }

  void _notifyParticipantsUpdated() {
    _participantsController.add(List.unmodifiable(_participants));
  }

  void dispose() {
    _participantsController.close();
  }
}
