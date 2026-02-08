class DatabaseConfig {
  // MySQL Server Configuration
  static const String host = '10.0.5.60';
  static const int port = 3306;
  static const String user = 'gecko';
  static const String password = 'tuko9';
  static const String database = 'punchgo';
  
  // Connection settings
  static const int timeout = 30;
  static const int maxRetries = 3;
}

class ServerConfig {
  // Server Configuration for File Uploads
  static const String host = '10.0.5.60';
  static const String protocol = 'http'; // Change to 'https' for production
  static const int port = 3000; // Your Node.js server port
  
  // Upload endpoint
  static const String uploadEndpoint = '/api/punchgo/upload';
  
  // Full upload URL
  static String get uploadUrl => '$protocol://$host:$port$uploadEndpoint';
  
  // Base URL for accessing uploaded files
  static String get baseUrl => '$protocol://$host:$port';
  
  // Upload folder path on server
  static const String uploadFolder = 'uploads';
}
