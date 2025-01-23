import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class TwilioFunctionsService {
  TwilioFunctionsService._();
  static final instance = TwilioFunctionsService._();

  final http.Client client = http.Client();
  final accessTokenUrl = 'https://TwilioChatRoomAccessToken-2481.twil.io/accessToken';

  Future<Map<String, dynamic>> createToken({
    required String identity,
    required String roomName,
    required String maxDuration,
  }) async {
    try {
      Map<String, String> header = {
        'Content-Type': 'application/json',
      };
      var url = Uri.parse('$accessTokenUrl?identity=$identity&roomName=$roomName');
      final response = await client.get(url, headers: header);
      Map<String, dynamic> responseMap = jsonDecode(response.body);
      return responseMap;
    } catch (error) {
      print(error);
      throw 'An error occurred: $error';
    }
  }
}
