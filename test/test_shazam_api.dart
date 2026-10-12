import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

void main() async {
  final uuid1 = const Uuid().v4().toUpperCase();
  final uuid2 = const Uuid().v4().toLowerCase();
  final url = Uri.parse(
    'https://amp.shazam.com/discovery/v5/en/US/android/-/tag/$uuid1/$uuid2'
    '?sync=true&webv3=true&sampling=true&connected=&shazamapiversion=v3&sharehub=true&video=v3',
  );

  final payload = {
    'geolocation': {'altitude': 300, 'latitude': 45.0, 'longitude': 2.0},
    'signature': {
      'samplems': 4000,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'uri': 'data:audio/vnd.shazam.sig;base64,',
    },
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'timezone': 'America/Sao_Paulo',
  };

  try {
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
      body: jsonEncode(payload),
    );
    print('Status: ${res.statusCode}');
    print('Body: ${res.body.substring(0, res.body.length > 300 ? 300 : res.body.length)}');
  } catch (e) {
    print('Error: $e');
  }
}
