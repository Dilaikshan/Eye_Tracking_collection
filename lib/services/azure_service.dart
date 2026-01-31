import 'dart:convert';

import 'package:http/http.dart' as http;

class AzureService {
  AzureService({required this.endpoint, required this.apiKey});

  final String endpoint; // e.g. https://<function>.azurewebsites.net/api/process
  final String apiKey; // function key or bearer; user will supply securely

  Future<AzureResponse> sendSamples({required Map<String, dynamic> payload}) async {
    final uri = Uri.parse(endpoint);
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-functions-key': apiKey,
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body.isEmpty ? '{}' : response.body);
      return AzureResponse(success: true, statusCode: response.statusCode, data: data);
    }

    return AzureResponse(
      success: false,
      statusCode: response.statusCode,
      errorMessage: response.body,
    );
  }
}

class AzureResponse {
  AzureResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.errorMessage,
  });

  final bool success;
  final int statusCode;
  final dynamic data;
  final String? errorMessage;
}
