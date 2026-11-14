class ApiEndpoints {
  ApiEndpoints._();

  // Base URL (Use 10.0.2.2 for Android Emulator, localhost for iOS Simulator, or your LAN/Prod IP)
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Root
  static const String root = '/';

  // User
  static const String createUser = '/user/';

  // Projects (CRUD)
  static const String projects = '/project/';
  static String projectById(String projectId) => '/project/$projectId';

  // PDF Upload & Celery Task Polling
  static const String uploadPdf = '/project/upload_pdf';
  static String taskStatus(String taskId) => '/project/task/$taskId';
}
