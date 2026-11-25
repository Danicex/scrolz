import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What every call returns. Screens never deal with exceptions.
class ApiResult<T> {
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResult.success(this.data, {this.statusCode}) : error = null;
  const ApiResult.failure(this.error, {this.statusCode}) : data = null;

  bool get isSuccess => error == null;
  bool get isFailure => !isSuccess;
}

class ApiHelper {
  ApiHelper._();

  // ---------------------------------------------------------------- config
  static const String baseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
  static String get mediaBaseUrl => Uri.parse(baseUrl).origin;
  
  static const _tokenKey = 'auth_token';
  static const _storage = FlutterSecureStorage();
  static String? _token; // in-memory cache so we don't hit storage on every request

  /// Called when the server returns 401 (token expired/invalid).
  /// Set this once in main(): navigate to login, clear app state, etc.
  static VoidCallback? onUnauthorized;

  static final Dio _dio = _buildDio();

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Pass `noAuth: true` for login/register endpoints.
          if (options.extra['noAuth'] != true) {
            final token = await getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401 && e.requestOptions.extra['noAuth'] != true) {
            await clearToken();
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );

    // Remove or guard with kDebugMode in production.
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    return dio;
  }

  // ----------------------------------------------------------------- token
  static Future<String?> getToken() async {
    _token ??= await _storage.read(key: _tokenKey);
    return _token;
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }
  /// Swap the Clerk session token for your own backend JWT and store it.
  static Future<ApiResult<String>> exchangeClerkToken(String clerkJwt) async {
    try {
      final res = await _dio.post(
        '/user/session',
        options: Options(
          headers: {'Authorization': 'Bearer $clerkJwt'},
          extra: {'noAuth': true}, // stops the interceptor swapping in the old token
        ),
      );
      final token = res.data['token'] as String;
      await saveToken(token);
      return ApiResult.success(token, statusCode: res.statusCode);
    } on DioException catch (e) {
      return ApiResult.failure(_mapDioError(e), statusCode: e.response?.statusCode);
    } catch (_) {
      return const ApiResult.failure('Could not start your session.');
    }
  }

  static Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  // ------------------------------------------------------------------ CRUD
  static Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    BuildContext? context,
    bool showLoader = false, // GETs usually render their own spinner
    bool showError = true,
    bool noAuth = false,
    T Function(dynamic json)? parser,
  }) =>
      _send<T>('GET', path,
          query: query,
          context: context,
          showLoader: showLoader,
          showError: showError,
          noAuth: noAuth,
          parser: parser);

  static Future<ApiResult<T>> post<T>(
    String path, {
    dynamic body,
    BuildContext? context,
    bool showLoader = true,
    bool showError = true,
    bool noAuth = false,
    String? successMessage,
    T Function(dynamic json)? parser,
  }) =>
      _send<T>('POST', path,
          body: body,
          context: context,
          showLoader: showLoader,
          showError: showError,
          noAuth: noAuth,
          successMessage: successMessage,
          parser: parser);

  static Future<ApiResult<T>> put<T>(
    String path, {
    dynamic body,
    BuildContext? context,
    bool showLoader = true,
    bool showError = true,
    String? successMessage,
    T Function(dynamic json)? parser,
  }) =>
      _send<T>('PUT', path,
          body: body,
          context: context,
          showLoader: showLoader,
          showError: showError,
          successMessage: successMessage,
          parser: parser);

  static Future<ApiResult<T>> patch<T>(
    String path, {
    dynamic body,
    BuildContext? context,
    bool showLoader = true,
    bool showError = true,
    String? successMessage,
    T Function(dynamic json)? parser,
  }) =>
      _send<T>('PATCH', path,
          body: body,
          context: context,
          showLoader: showLoader,
          showError: showError,
          successMessage: successMessage,
          parser: parser);

  static Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic body,
    BuildContext? context,
    bool showLoader = true,
    bool showError = true,
    String? successMessage,
    T Function(dynamic json)? parser,
  }) =>
      _send<T>('DELETE', path,
          body: body,
          context: context,
          showLoader: showLoader,
          showError: showError,
          successMessage: successMessage,
          parser: parser);

  /// Multipart upload (images, files). `fields` may contain MultipartFile values.
  static Future<ApiResult<T>> upload<T>(
    String path, {
    required Map<String, dynamic> fields,
    BuildContext? context,
    bool showLoader = true,
    bool showError = true,
    String? successMessage,
    T Function(dynamic json)? parser,
  }) =>
      _send<T>('POST', path,
          body: FormData.fromMap(fields),
          context: context,
          showLoader: showLoader,
          showError: showError,
          successMessage: successMessage,
          parser: parser);

  // ------------------------------------------------------------- core send
  static bool _loaderOpen = false;

  static Future<ApiResult<T>> _send<T>(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    BuildContext? context,
    bool showLoader = false,
    bool showError = true,
    bool noAuth = false,
    String? successMessage,
    T Function(dynamic json)? parser,
  }) async {
    final canShowUi = context != null;

    if (canShowUi && showLoader) _showLoader(context);

    ApiResult<T> result;
    try {
      final res = await _dio.request(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, extra: {'noAuth': noAuth}),
      );

      final T? parsed =
          parser != null ? parser(res.data) : res.data as T?;
      result = ApiResult<T>.success(parsed, statusCode: res.statusCode);
    } on DioException catch (e) {
      result = ApiResult<T>.failure(_mapDioError(e),
          statusCode: e.response?.statusCode);
    } catch (e) {
      // Parsing errors, casting errors, etc.
      result = const ApiResult.failure(
          'Something went wrong while processing the response.');
    }

    // The screen may have been popped while we were waiting.
    final stillMounted = canShowUi && context.mounted;

    if (stillMounted && showLoader) _hideLoader(context);

    if (stillMounted) {
      if (result.isFailure && showError && result.statusCode != 401) {
        await showMessageDialog(context,
            title: 'Error', message: result.error!, isError: true);
      } else if (result.isSuccess && successMessage != null) {
        await showMessageDialog(context,
            title: 'Success', message: successMessage);
      }
    }

    return result;
  }

  // ---------------------------------------------------------- error mapping
 static String _mapDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return 'The request timed out. Please try again.';
    case DioExceptionType.connectionError:
      return 'No internet connection. Check your network and try again.';
    case DioExceptionType.cancel:
      return 'Request was cancelled.';
    case DioExceptionType.badCertificate:
      return 'Secure connection failed.';
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);
    case DioExceptionType.unknown:
      if (e.error is SocketException) {
        return 'No internet connection. Check your network and try again.';
      }
      return 'Unexpected error. Please try again.';
  }
}

  static String _fromResponse(Response? res) {
    final code = res?.statusCode ?? 0;
    final data = res?.data;

    // Prefer the server's own message. Adjust keys to match your backend.
    if (data is Map) {
      final msg = data['message'] ?? data['error'] ?? data['detail'];
      if (msg is String && msg.isNotEmpty) return msg;

      // Validation errors: {"errors": {"email": ["is invalid"]}}
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
    } else if (data is String && data.isNotEmpty && data.length < 200) {
      return data;
    }

    switch (code) {
      case 400:
        return 'Invalid request.';
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return 'You don\'t have permission to do that.';
      case 404:
        return 'The requested item was not found.';
      case 409:
        return 'This conflicts with existing data.';
      case 422:
        return 'Some of the information provided is invalid.';
      case 429:
        return 'Too many requests. Please wait a moment.';
      default:
        if (code >= 500) return 'Server error. Please try again later.';
        return 'Request failed (code $code).';
    }
  }

  // ----------------------------------------------------------------- modals
  static void _showLoader(BuildContext context) {
    if (_loaderOpen) return;
    _loaderOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  static void _hideLoader(BuildContext context) {
    if (!_loaderOpen) return;
    _loaderOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Reusable message modal. Also callable from screens.
  static Future<void> showMessageDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool isError = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? Colors.red : Colors.green,
          size: 36,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Confirmation modal, e.g. before delete. Returns true if the user confirms.
  static Future<bool> confirm(
    BuildContext context, {
    String title = 'Are you sure?',
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'Cancel',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

// ======================================================================
// USAGE EXAMPLES
// ======================================================================
//
// main.dart (once):
//   final navKey = GlobalKey<NavigatorState>();
//   ApiHelper.onUnauthorized = () =>
//       navKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
//
// Login:
//   final res = await ApiHelper.post<Map<String, dynamic>>(
//     '/auth/login',
//     body: {'email': email, 'password': pass},
//     noAuth: true,
//     context: context,
//     parser: (j) => Map<String, dynamic>.from(j),
//   );
//   if (res.isSuccess) {
//     await ApiHelper.saveToken(res.data!['token']);
//     // navigate home
//   }
//
// READ (list):
//   final res = await ApiHelper.get<List<Todo>>(
//     '/todos',
//     query: {'page': 1},
//     parser: (j) => (j['data'] as List).map((e) => Todo.fromJson(e)).toList(),
//   );
//   setState(() {
//     _loading = false;
//     _error = res.error;
//     _todos = res.data ?? [];
//   });
//
// CREATE:
//   final res = await ApiHelper.post<Todo>(
//     '/todos',
//     body: {'title': title},
//     context: context,
//     successMessage: 'Todo created',
//     parser: (j) => Todo.fromJson(j['data']),
//   );
//   if (res.isSuccess) { /* add res.data to list */ }
//
// UPDATE:
//   await ApiHelper.put<Todo>('/todos/$id', body: {...}, context: context,
//       successMessage: 'Updated', parser: (j) => Todo.fromJson(j['data']));
//
// DELETE with confirmation:
//   if (await ApiHelper.confirm(context, message: 'Delete this todo?')) {
//     if (!context.mounted) return;
//     final res = await ApiHelper.delete<void>('/todos/$id', context: context);
//     if (res.isSuccess) { /* remove from list */ }
//   }
