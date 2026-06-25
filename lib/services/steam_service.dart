import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SteamService {
  final api_key = dotenv.env['STEAM_API_KEY'];
  final dio = Dio();
}