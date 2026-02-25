import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Callback para atualizações de progresso do download
typedef ProgressCallback = void Function(double progress, String status);

/// Serviço para verificar e gerenciar atualizações do GitHub
class UpdateService {
  static const String _owner = 'rikelmyso7'; // Substitua pelo seu usuário GitHub
  static const String _repo = 'br_service'; // Substitua pelo nome do repositório
  static String? _cachedVersion;
  
  /// Obtém a versão atual do app do pubspec.yaml
  static Future<String> _getCurrentVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _cachedVersion = packageInfo.version;
      return _cachedVersion!;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter versão do app: $e');
      }
      // Fallback para versão padrão se houver erro
      _cachedVersion = '1.0.0';
      return _cachedVersion!;
    }
  }
  
  /// Verifica se há uma nova versão disponível no GitHub
  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      final currentVersion = await _getCurrentVersion();
      final url = Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest');
      
      if (kDebugMode) {
        print('Verificando updates em: $url');
        print('Versão atual: $currentVersion');
      }
      
      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'br_service_app',
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] as String;
        final downloadUrl = _getWindowsDownloadUrl(data['assets']);
        
        if (kDebugMode) {
          print('Versão mais recente: $latestVersion');
        }
        
        if (downloadUrl != null && _isNewerVersion(latestVersion, currentVersion)) {
          return UpdateInfo(
            version: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: data['body'] ?? '',
            releaseDate: DateTime.parse(data['published_at']),
          );
        }
      } else {
        if (kDebugMode) {
          print('Erro ao verificar updates: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao verificar updates: $e');
      }
    }
    
    return null;
  }
  
  /// Encontra a URL de download para Windows nos assets da release
  static String? _getWindowsDownloadUrl(List<dynamic> assets) {
    for (final asset in assets) {
      final name = asset['name'] as String;
      if (name.contains('windows') || name.endsWith('.exe') || name.endsWith('.zip')) {
        return asset['browser_download_url'] as String;
      }
    }
    return null;
  }
  
  /// Compara duas versões no formato semver (x.y.z)
  static bool _isNewerVersion(String latestVersion, String currentVersion) {
    // Remove o 'v' do início se existir
    final latest = latestVersion.replaceFirst('v', '').split('.');
    final current = currentVersion.replaceFirst('v', '').split('.');
    
    for (int i = 0; i < 3; i++) {
      final latestPart = int.tryParse(latest.length > i ? latest[i] : '0') ?? 0;
      final currentPart = int.tryParse(current.length > i ? current[i] : '0') ?? 0;
      
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    
    return false;
  }
  
  /// Baixa e instala a atualização automaticamente com callback de progresso
  static Future<bool> downloadAndInstallUpdate(
    UpdateInfo updateInfo, {
    ProgressCallback? onProgress,
  }) async {
    try {
      onProgress?.call(0.0, 'Iniciando download...');
      
      if (kDebugMode) {
        print('Iniciando download da atualização: ${updateInfo.version}');
      }
      
      // Faz requisição para obter o tamanho do arquivo
      final headResponse = await http.head(Uri.parse(updateInfo.downloadUrl));
      final contentLength = int.tryParse(headResponse.headers['content-length'] ?? '0') ?? 0;
      
      onProgress?.call(0.1, 'Conectando...');
      
      // Stream para download com progresso
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = updateInfo.downloadUrl.split('/').last;
        final filePath = '${tempDir.path}/$fileName';
        
        onProgress?.call(0.2, 'Baixando arquivo...');
        
        // Baixa o arquivo com progresso
        final file = File(filePath);
        final sink = file.openWrite();
        
        int downloaded = 0;
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          
          if (contentLength > 0) {
            final progress = 0.2 + (downloaded / contentLength) * 0.6; // 20% a 80%
            final mbDownloaded = (downloaded / 1024 / 1024).toStringAsFixed(1);
            final mbTotal = (contentLength / 1024 / 1024).toStringAsFixed(1);
            onProgress?.call(progress, 'Baixando... $mbDownloaded/$mbTotal MB');
          } else {
            final mbDownloaded = (downloaded / 1024 / 1024).toStringAsFixed(1);
            onProgress?.call(0.5, 'Baixando... $mbDownloaded MB');
          }
        }
        
        await sink.close();
        onProgress?.call(0.8, 'Download concluído. Preparando instalação...');
        
        if (kDebugMode) {
          print('Arquivo baixado: $filePath');
        }
        
        // Se for um arquivo .exe, executa diretamente
        if (fileName.endsWith('.exe')) {
          onProgress?.call(0.9, 'Instalando...');
          return await _installExecutable(filePath, onProgress);
        }
        
        // Se for um .zip, extrai e executa
        if (fileName.endsWith('.zip')) {
          onProgress?.call(0.85, 'Extraindo arquivo...');
          return await _installFromZip(filePath, onProgress);
        }
        
        // Se não conseguir identificar o tipo, abre o local do arquivo
        onProgress?.call(1.0, 'Abrindo local do arquivo...');
        await _openFileLocation(tempDir.path);
        return true;
      } else {
        onProgress?.call(0.0, 'Erro: Falha no download (${streamedResponse.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro durante download/instalação: $e');
      }
      onProgress?.call(0.0, 'Erro: $e');
    }
    
    return false;
  }
  
  /// Instala um executável (.exe)
  static Future<bool> _installExecutable(String filePath, [ProgressCallback? onProgress]) async {
    try {
      if (Platform.isWindows) {
        onProgress?.call(0.95, 'Executando instalador...');
        
        // No Windows, executa o instalador
        await Process.start(filePath, [], mode: ProcessStartMode.detached);
        
        onProgress?.call(1.0, 'Instalação iniciada! Reiniciando...');
        
        // Fecha o app atual após um delay para permitir a instalação
        Future.delayed(const Duration(seconds: 2), () {
          exit(0);
        });
        
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao executar instalador: $e');
      }
      onProgress?.call(0.0, 'Erro ao executar instalador: $e');
    }
    
    return false;
  }
  
  /// Instala a partir de um arquivo .zip
  static Future<bool> _installFromZip(String zipPath, [ProgressCallback? onProgress]) async {
    try {
      onProgress?.call(0.85, 'Preparando extração...');
      
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory('${tempDir.path}/br_service_update');
      
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create();
      
      onProgress?.call(0.9, 'Extraindo arquivo...');
      
      // Extrai o arquivo
      await extractFileToDisk(zipPath, extractDir.path);
      
      onProgress?.call(0.95, 'Procurando executável...');
      
      // Procura por um executável na pasta extraída
      final files = await extractDir.list(recursive: true).toList();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.exe')) {
          return await _installExecutable(file.path, onProgress);
        }
      }
      
      // Se não encontrar executável, abre a pasta
      onProgress?.call(1.0, 'Abrindo pasta extraída...');
      await _openFileLocation(extractDir.path);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao extrair e instalar: $e');
      }
      onProgress?.call(0.0, 'Erro ao extrair: $e');
    }
    
    return false;
  }
  
  /// Abre o local do arquivo no explorador
  static Future<void> _openFileLocation(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao abrir local do arquivo: $e');
      }
    }
  }
  
  /// Abre a página de releases no navegador
  static Future<void> openReleasePage() async {
    final url = Uri.parse('https://github.com/$_owner/$_repo/releases');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
  
  /// Retorna a versão atual do app
  static Future<String> get currentVersion => _getCurrentVersion();
}

/// Informações sobre uma atualização disponível
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime releaseDate;
  
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseDate,
  });
  
  @override
  String toString() {
    return 'UpdateInfo{version: $version, downloadUrl: $downloadUrl}';
  }
}

/// Notificação de atualização para a UI
class UpdateNotification {
  final UpdateInfo updateInfo;
  final VoidCallback onUpdate;
  final VoidCallback onSkip;
  final VoidCallback onViewDetails;
  
  const UpdateNotification({
    required this.updateInfo,
    required this.onUpdate,
    required this.onSkip,
    required this.onViewDetails,
  });
}