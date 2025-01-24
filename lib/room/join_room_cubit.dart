import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_twilio/shared/twilio_service.dart';

abstract class RoomState extends Equatable {
  const RoomState();
  @override
  List<Object> get props => [];
}

class RoomInitial extends RoomState {}

class RoomError extends RoomState {
  final String error;
  const RoomError({required this.error});
  @override
  List<Object> get props => [error];
}

class RoomLoaded extends RoomState {
  final String roomName;
  final String token;
  final String identity;

  const RoomLoaded({required this.roomName, required this.token, required this.identity});
  @override
  List<Object> get props => [];
}

class RoomLoading extends RoomState {}

class RoomCubit extends Cubit<RoomState> {
  final TwilioFunctionsService backendService;

  RoomCubit({required this.backendService}) : super(RoomInitial());

  submit({
    required String identity,
    required String roomName,
  }) async {
    emit(RoomLoading());
    try {
      final twilioRoomTokenResponse = await backendService.createToken(
        identity: identity,
        roomName: roomName,
      );
      final token = twilioRoomTokenResponse['accessToken'];

      if (token != null) {
        emit(RoomLoaded(roomName: roomName, token: token, identity: identity));
      } else {
        emit(RoomError(error: 'Something went wrong'));
      }
    } catch (e) {
      emit(RoomError(error: e.toString()));
    } finally {}
  }
}
