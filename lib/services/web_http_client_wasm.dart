import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> webGet(String url,
    {Map<String, String>? headers}) async {
  final response = await http.get(Uri.parse(url), headers: headers);
  return {
    'statusCode': response.statusCode,
    'body': response.body,
  };
}

Future<Map<String, dynamic>> webPost(String url,
    {Map<String, String>? headers, String? body}) async {
  final response =
      await http.post(Uri.parse(url), headers: headers, body: body);
  return {
    'statusCode': response.statusCode,
    'body': response.body,
  };
}
