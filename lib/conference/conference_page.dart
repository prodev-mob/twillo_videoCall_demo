import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_twilio/conference/conference_cubit.dart';

class ConferencePage extends StatefulWidget {
  const ConferencePage({
    super.key,
  });

  @override
  State<ConferencePage> createState() => _ConferencePageState();
}

class _ConferencePageState extends State<ConferencePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<ConferenceCubit, ConferenceState>(
        listener: (context, state) {},
        builder: (context, state) {
          if (state is ConferenceInitial) {
            return showProgress();
          }
          if (state is ConferenceLoaded) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                _buildParticipants(context),
                _buildControls(context),
              ],
            );
          }
          return Container();
        },
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final conferenceCubit = context.read<ConferenceCubit>();
    final isAudioEnabled = conferenceCubit.isAudioTrackEnabled();
    return Positioned(
      bottom: 50,
      right: 0,
      left: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey,
            child: IconButton(
              icon: Icon(
                isAudioEnabled ? Icons.mic : Icons.mic_off,
                color: Colors.white,
              ),
              onPressed: () {
                conferenceCubit.toggleAudioTrack(!isAudioEnabled);
                setState(() {});
              },
            ),
          ),
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.red,
            child: FittedBox(
              child: IconButton(
                icon: Icon(
                  Icons.call_end_sharp,
                  color: Colors.white,
                ),
                onPressed: () async {
                  context.read<ConferenceCubit>().disconnect();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey,
            child: IconButton(
              icon: const Icon(
                Icons.cameraswitch,
                color: Colors.white,
              ),
              onPressed: () async {
                await conferenceCubit.flipCamera();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget showProgress() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Center(child: CircularProgressIndicator()),
        SizedBox(
          height: 10,
        ),
        Text(
          'Connecting to the room...',
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildParticipants(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final children = <Widget>[];
    _buildOverlayLayout(context, size, children);
    return Stack(children: children);
  }

  void _buildOverlayLayout(BuildContext context, Size size, List<Widget> children) {
    final conferenceRoom = context.read<ConferenceCubit>();
    final participants = conferenceRoom.participants;
    children.add(
      GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1),
        itemCount: participants.length,
        itemBuilder: (BuildContext context, int index) {
          return Card(
            child: participants[index].remoteVideoTrack,
          );
        },
      ),
    );
  }
}
