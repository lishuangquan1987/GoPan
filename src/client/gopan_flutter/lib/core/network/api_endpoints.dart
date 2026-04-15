class ApiEndpoints {
  static const auth = '/api/auth';
  static const register = '$auth/register';
  static const login = '$auth/login';
  static const logout = '$auth/logout';
  static const me = '$auth/me';

  static const files = '/api/files';
  static const upload = '$files/upload';
  static const uploadStatus = '$files/upload/status';
  static const uploadChunk = '$files/upload/chunk';
  static const uploadCancel = '$files/upload/cancel';
  static const quickUpload = '$files/quick-upload';
  static const folder = '$files/folder';
  static const tree = '$files/tree';
  static const search = '$files/search';
  static const trash = '$files/trash';
  static const restore = '$files/restore';
  static String fileById(String id) => '$files/$id';
  static String download(String id) => '$files/$id/download';
  static String proxy(String id) => '$files/$id/proxy';
  static String trashById(String id) => '$files/trash/$id';
  static String moveFiles() => '$files/move';
  static String copyFiles() => '$files/copy';

  static const shares = '/api/shares';
  static String shareById(String id) => '$shares/$id';
  static String shareByCode(String code) => '$shares/$code';
  static String shareDownload(String code) => '$shares/$code/download';
  static String shareFolder(String code, String id) => '$shares/$code/folder/$id';
  static String shareSave(String code) => '$shares/$code/save';
  static String sharePreview(String code, String id) => '$shares/$code/preview/$id';

  static const capacity = '/api/user/capacity';
  static String preview(String id) => '/api/preview/$id';
}
