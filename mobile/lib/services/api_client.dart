import 'package:dio/dio.dart';
import '../core/config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      },
    ));
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get(path);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(path, data: body);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const ApiException('Request timed out. Please try again.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return const ApiException('No internet connection.');
    }
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final detail = data is Map<String, dynamic> ? data['detail'] as String? : null;
    if (status == 502) {
      return ApiException(detail ?? 'Payment initiation failed. Please try again.', statusCode: status);
    }
    if (status == 404) {
      return ApiException('Transaction not found.', statusCode: status);
    }
    return ApiException(detail ?? 'Something went wrong. Please try again.', statusCode: status);
  }
}
