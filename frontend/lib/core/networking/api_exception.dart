import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timed out. Please check your internet and try again.',
        );

      case DioExceptionType.connectionError:
        return ApiException(
          message: 'No internet connection or server is unreachable.',
        );

      case DioExceptionType.cancel:
        return ApiException(message: 'Request was cancelled.');

      case DioExceptionType.badResponse:
        return _handleStatusCode(error.response);

      default:
        return ApiException(message: 'An unexpected error occurred.');
    }
  }

  static ApiException _handleStatusCode(Response? response) {
    final statusCode = response?.statusCode;
    final data = response?.data;

    // FastAPI typically returns errors under the "detail" key
    String serverMessage = 'Something went wrong.';
    if (data is Map<String, dynamic> && data.containsKey('detail')) {
      final detail = data['detail'];
      if (detail is String) {
        serverMessage = detail;
      } else if (detail is List && detail.isNotEmpty) {
        // FastAPI 422 Pydantic validation errors return a list of objects
        serverMessage = detail.first['msg'] ?? 'Validation error.';
      }
    }

    switch (statusCode) {
      case 400:
        return ApiException(message: serverMessage, statusCode: 400);
      case 401:
        return ApiException(message: 'Session expired. Please log in again.', statusCode: 401);
      case 403:
        return ApiException(message: 'You do not have permission to perform this action.', statusCode: 403);
      case 404:
        return ApiException(message: 'Requested resource was not found.', statusCode: 404);
      case 422:
        return ApiException(message: 'Invalid input: $serverMessage', statusCode: 422);
      case 500:
      case 502:
      case 503:
        return ApiException(message: 'Server error. Please try again later.', statusCode: statusCode);
      default:
        return ApiException(message: serverMessage, statusCode: statusCode);
    }
  }

  @override
  String toString() => message;
}
