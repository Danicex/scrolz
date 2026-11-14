import 'dart:io';
import '../networking/api_endpoints.dart';
import '../networking/dio_client.dart';


class ProjectRepository {
  final DioClient _client;

  ProjectRepository(this._client);

  // 1. Health Check: GET /
  Future<Map<String, dynamic>> checkRoot() async {
    final response = await _client.get(ApiEndpoints.root);
    return response.data as Map<String, dynamic>;
  }

  // 2. Create User: POST /user/
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String username,
  }) async {
    final response = await _client.post(
      ApiEndpoints.createUser,
      data: {
        'email': email,
        'username': username,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // 3. Upload PDF: POST /project/upload_pdf
  Future<Map<String, dynamic>> uploadPdf({
    required File pdfFile,
    void Function(int sent, int total)? onProgress,
  }) async {
    final response = await _client.uploadFile(
      ApiEndpoints.uploadPdf,
      file: pdfFile,
      fileFieldName: 'file', // Matches FastAPI UploadFile parameter name
      onSendProgress: onProgress,
    );
    // Returns e.g. {"task_id": "abc-123", "status": "processing"}
    return response.data as Map<String, dynamic>;
  }

  // 4. Check Celery Task Status: GET /project/task/{task_id}
  Future<Map<String, dynamic>> getTaskStatus(String taskId) async {
    final response = await _client.get(ApiEndpoints.taskStatus(taskId));
    return response.data as Map<String, dynamic>;
  }

  // 5. List Projects (READ ALL): GET /project/
  Future<List<dynamic>> listProjects() async {
    final response = await _client.get(ApiEndpoints.projects);
    return response.data as List<dynamic>;
  }

  // 6. Get Single Project (READ ONE): GET /project/{project_id}
  Future<Map<String, dynamic>> getProject(String projectId) async {
    final response = await _client.get(ApiEndpoints.projectById(projectId));
    return response.data as Map<String, dynamic>;
  }

  // 7. Update Project (UPDATE): PATCH /project/{project_id}
  Future<Map<String, dynamic>> updateProject(
    String projectId, {
    String? title,
    String? status,
  }) async {
    final response = await _client.patch(
      ApiEndpoints.projectById(projectId),
      data: {
        if (title != null) 'title': title,
        if (status != null) 'status': status,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // 8. Delete Project (DELETE): DELETE /project/{project_id}
  Future<void> deleteProject(String projectId) async {
    await _client.delete(ApiEndpoints.projectById(projectId));
  }
}
