import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_twilio/conference/conference_cubit.dart';
import 'package:flutter_twilio/conference/conference_page.dart';
import 'package:flutter_twilio/room/join_room_cubit.dart';
import 'package:flutter_twilio/shared/twilio_service.dart';
import 'package:uuid/uuid.dart';

class JoinRoomPage extends StatefulWidget {
  const JoinRoomPage({super.key});

  @override
  State<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends State<JoinRoomPage> {
  late TextEditingController _roomNameController;
  late TextEditingController _identityController;
  int selectedNumber = 10;

  @override
  void initState() {
    super.initState();
    _roomNameController = TextEditingController(text: "test-room");
    _identityController = TextEditingController(text: Uuid().v4());
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _identityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: BlocProvider(
            create: (context) => RoomCubit(backendService: TwilioFunctionsService.instance),
            child: BlocConsumer<RoomCubit, RoomState>(
              listener: (context, state) async {
                if (state is RoomLoaded) {
                  await Navigator.of(context).push(
                    MaterialPageRoute<ConferencePage>(
                      fullscreenDialog: true,
                      builder: (BuildContext context) {
                        return BlocProvider(
                          create: (BuildContext context) {
                            return ConferenceCubit(
                              identity: state.identity,
                              token: state.token,
                              roomName: state.roomName,
                            );
                          },
                          child: ConferencePage(),
                        );
                      },
                    ),
                  );
                }
              },
              builder: (context, state) {
                var isLoading = false;
                RoomCubit bloc = context.read<RoomCubit>();
                if (state is RoomLoading) {
                  isLoading = true;
                }
                return Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: Key('enter-room-name'),
                        decoration: InputDecoration(
                          labelText: 'Enter your room name',
                          enabled: !isLoading,
                        ),
                        controller: _roomNameController,
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      TextField(
                        key: Key('enter-identity'),
                        decoration: InputDecoration(
                          labelText: 'Enter your identity',
                          enabled: !isLoading,
                        ),
                        controller: _identityController,
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      DropdownButtonFormField<int>(
                        value: selectedNumber,
                        hint: Text('Select a number'),
                        icon: Row(
                          children: [
                            Text("In Second"),
                            Icon(Icons.arrow_drop_down_outlined),
                          ],
                        ),
                        items: [10, 20, 30, 40, 50, 60].map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value'),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          if (newValue == null) return;
                          setState(() {
                            selectedNumber = newValue;
                          });
                        },
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      if (isLoading == true)
                        LinearProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: () async {
                            await bloc.submit(
                              identity: _identityController.text.trim(),
                              roomName: _roomNameController.text.trim(),
                              maxDuration: selectedNumber.toString(),
                            );
                          },
                          child: Text('Enter the room'),
                        ),
                      const SizedBox(
                        height: 10,
                      ),
                      if (state is RoomError)
                        Text(
                          state.error,
                          style: TextStyle(color: Colors.red),
                        )
                      else
                        Container(),
                      const SizedBox(
                        height: 16,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
