class ApiResponse<T> {
  final String status;
  final T data;
  final String message;

  ApiResponse({
    required this.status,
    required this.data,
    this.message = '',
  });
}
