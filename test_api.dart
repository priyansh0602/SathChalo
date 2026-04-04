import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=poornima%20university%20jaipur'
      '&key=AIzaSyAQkXgEClg3yF-f2rraXFBKG0LWf28JMp4'
      '&components=country:in'
      '&language=en';
      
  final res = await http.get(Uri.parse(url));
  print(res.statusCode);
  print(res.body);
}
