import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_twilio/conference/participant_widget.dart';
import 'package:twilio_programmable_video/twilio_programmable_video.dart';
import 'package:uuid/uuid.dart';

abstract class ConferenceState extends Equatable {
  const ConferenceState();

  @override
  List<Object> get props => [];
}

class ConferenceInitial extends ConferenceState {}

class ConferenceLoaded extends ConferenceState {}

class ConferenceCubit extends Cubit<ConferenceState> {
  final String roomName;
  final String token;
  final String identity;

  late String trackId;
  late Room _room;
  late VideoCapturer _cameraCapture;
  final List<ParticipantInfo> _participants = [];

  late LocalAudioTrack _localAudioTrack;
  late LocalVideoTrack _localVideoTrack;
  late LocalDataTrack _localDataTracks;

  ConferenceCubit({
    required this.roomName,
    required this.token,
    required this.identity,
  }) : super(ConferenceInitial()) {
    connect();
  }

  List<ParticipantInfo> get participants {
    return [..._participants];
  }

  connect() async {
    print('[ APPDEBUG ] ConferenceRoom.connect()');

    try {
      await TwilioProgrammableVideo.setAudioSettings(speakerphoneEnabled: true, bluetoothPreferred: true);

      final sources = await CameraSource.getSources();
      _cameraCapture = CameraCapturer(
        sources.firstWhere((source) => source.isFrontFacing),
      );

      trackId = Uuid().v4();

      _localAudioTrack = LocalAudioTrack(false, 'audio_track-$trackId');
      _localVideoTrack = LocalVideoTrack(true, _cameraCapture);
      _localDataTracks = LocalDataTrack(DataTrackOptions(name: 'data_track-$trackId'));

      var connectOptions = ConnectOptions(
        token,
        roomName: roomName,
        preferredAudioCodecs: [OpusCodec()],
        audioTracks: [_localAudioTrack],
        videoTracks: [_localVideoTrack],
        dataTracks: [_localDataTracks],
        enableNetworkQuality: true,
        enableDominantSpeaker: true,
      );

      _room = await TwilioProgrammableVideo.connect(connectOptions);
      _room.onConnected.listen(_onConnected);
      _room.onDisconnected.listen(_onDisconnected);
      _room.onReconnecting.listen(_onReconnecting);
      _room.onConnectFailure.listen(_onConnectFailure);
    } catch (err) {
      print('[ APPDEBUG ] $err');
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

  bool isAudioTrackEnabled() {
    return _localAudioTrack.isEnabled;
  }

  void toggleAudioTrack(bool value) {
    _localAudioTrack.enable(value);
  }

  Future<void> disconnect() async {
    if (_room.state == RoomState.CONNECTED || _room.state == RoomState.CONNECTING) {
      print('[ APPDEBUG ] ConferenceRoom.disconnect()');
      await _room.disconnect();
    }
  }

  void _onDisconnected(RoomDisconnectedEvent event) {
    print('[ APPDEBUG ] ConferenceRoom._onDisconnected');
  }

  void _onReconnecting(RoomReconnectingEvent room) {
    print('[ APPDEBUG ] ConferenceRoom._onReconnecting');
  }

  void _onConnected(Room room) {
    print('[ APPDEBUG ] ConferenceRoom._onConnected => state: ${room.state}');

    // When connected for the first time, add remote participant listeners
    _room.onParticipantConnected.listen(_onParticipantConnected);
    _room.onParticipantDisconnected.listen(_onParticipantDisconnected);
    final localParticipant = room.localParticipant;
    if (localParticipant == null) {
      print('[ APPDEBUG ] ConferenceRoom._onConnected => localParticipant is null');
      return;
    }

    // Only add ourselves when connected for the first time too.
    _participants.add(
      ParticipantInfo(
        remoteVideoTrack: localParticipant.localVideoTracks[0].localVideoTrack.widget(),
        id: identity,
      ),
    );

    for (final remoteParticipant in room.remoteParticipants) {
      _addRemoteParticipantListeners(remoteParticipant);
    }
    reload();
  }

  void _onConnectFailure(RoomConnectFailureEvent event) {
    print('[ APPDEBUG ] ConferenceRoom._onConnectFailure: ${event.exception}');
  }

  void _onParticipantConnected(RoomParticipantConnectedEvent event) {
    print('[ APPDEBUG ] ConferenceRoom._onParticipantConnected, ${event.remoteParticipant.sid}');
    _addRemoteParticipantListeners(event.remoteParticipant);
    reload();
  }

  void _onParticipantDisconnected(RoomParticipantDisconnectedEvent event) {
    print('[ APPDEBUG ] ConferenceRoom._onParticipantDisconnected: ${event.remoteParticipant.sid}');
    _participants.removeWhere((ParticipantInfo p) => p.id == event.remoteParticipant.sid);
    reload();
  }

  void _addRemoteParticipantListeners(RemoteParticipant remoteParticipant) {
    remoteParticipant.onVideoTrackSubscribed.listen(_addOrUpdateParticipant);
    remoteParticipant.onAudioTrackSubscribed.listen((event) {
      print('[APPDEBUG] Audio track subscribed for ${remoteParticipant.sid}');
    });
  }

  void _addOrUpdateParticipant(RemoteParticipantEvent event) {
    print('[ APPDEBUG ] ConferenceRoom._addOrUpdateParticipant(), ${event.remoteParticipant.sid}');
    final participant = _participants.firstWhere(
      (ParticipantInfo participant) => participant.id == event.remoteParticipant.sid,
      orElse: () => ParticipantInfo(
        id: null,
        remoteVideoTrack: SizedBox.shrink(),
      ),
    );
    if (participant.id == null) {
      if (event is RemoteVideoTrackSubscriptionEvent) {
        print('[ APPDEBUG ] New participant, adding: ${event.remoteParticipant.sid}');
        _participants.insert(
          0,
          ParticipantInfo(
            remoteVideoTrack: event.remoteVideoTrack.widget(),
            id: event.remoteParticipant.sid,
          ),
        );
        reload();
      }
    } else {
      print('[ APPDEBUG ] Participant found: ${participant.id}, updating A/V enabled values');
    }
  }

  reload() {
    emit(ConferenceInitial());
    emit(ConferenceLoaded());
  }
}
