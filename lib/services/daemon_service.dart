import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

/// Gerencia um processo Python persistente (daemon) que responde a comandos
/// JSON via stdin/stdout, eliminando o cold start do PyInstaller.
///
/// Protocolo:
///   → stdin:  {"cmd": "get-all", "input": "/path/file.xlsx"}\n
///   ← stdout: <json da resposta>\n
class BRServiceDaemon {
  static final BRServiceDaemon instance = BRServiceDaemon._();
  BRServiceDaemon._();

  static final _log = Logger('BRServiceDaemon');

  Process? _process;
  bool _alive = false;
  bool _starting = false;
  String? _executablePath;

  /// Caminho do executável que o daemon está usando atualmente.
  String? get executablePath => _alive ? _executablePath : null;

  final _responseQueue = Queue<Completer<String>>();
  Future<void> _writeChain = Future.value();
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;

  // -------------------------------------------------------------------------
  // API pública
  // -------------------------------------------------------------------------

  /// Inicia o daemon com antecedência. Chamar no main() após resolver o exe.
  Future<void> warmUp(String executablePath) async {
    _executablePath = executablePath;
    await _ensureRunning();
  }

  /// Envia um comando ao daemon e retorna o JSON de resposta.
  Future<Map<String, dynamic>> send(
    String cmd,
    String inputPath, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (_executablePath == null) {
      throw StateError('BRServiceDaemon não foi inicializado. Chame warmUp() primeiro.');
    }
    await _ensureRunning();

    final completer = Completer<String>();
    _responseQueue.add(completer);

    final payload = jsonEncode({'cmd': cmd, 'input': inputPath});
    _log.fine('→ daemon: $payload');
    // Serializa writes: encadeia no _writeChain para evitar writes concorrentes no stdin
    _writeChain = _writeChain.then((_) async {
      _process!.stdin.add(utf8.encode('$payload\n'));
      await _process!.stdin.flush();
    });
    await _writeChain;

    try {
      final line = await completer.future.timeout(timeout);
      _log.fine('← daemon: ${line.length > 200 ? "${line.substring(0, 200)}…" : line}');
      return jsonDecode(line) as Map<String, dynamic>;
    } on TimeoutException {
      _responseQueue.remove(completer);
      _log.severe('Timeout aguardando resposta do daemon (cmd=$cmd)');
      await _cleanup();
      rethrow;
    }
  }

  Future<void> dispose() => _cleanup();

  // -------------------------------------------------------------------------
  // Ciclo de vida interno
  // -------------------------------------------------------------------------

  Future<void> _ensureRunning() async {
    if (_alive) return;

    // Espera se outro await já está iniciando
    if (_starting) {
      while (_starting) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      return;
    }

    _starting = true;
    try {
      await _start();
    } finally {
      _starting = false;
    }
  }

  Future<void> _start() async {
    _log.info('Iniciando daemon CLI...');
    final exe = _executablePath!;

    _process = await Process.start(
      exe,
      ['--daemon'],
      runInShell: false,
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );

    _process!.exitCode.then((_) {
      _alive = false;
      _onProcessDone();
    });

    // Aguarda sinal DAEMON_READY via stderr
    final readyCompleter = Completer<void>();
    _stderrSub = _process!.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      _log.fine('[daemon] $line');
      if (!readyCompleter.isCompleted && line.contains('DAEMON_READY')) {
        readyCompleter.complete();
      }
    });

    _stdoutSub = _process!.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          _onLine,
          onError: (e) => _log.severe('Daemon stdout error: $e'),
        );

    await readyCompleter.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        _alive = false;
        throw Exception('Daemon não emitiu DAEMON_READY em 45s');
      },
    );

    _alive = true;
    _log.info('Daemon CLI pronto (pid=${_process!.pid})');
  }

  void _onLine(String line) {
    if (line.isEmpty) return;
    if (_responseQueue.isNotEmpty) {
      _responseQueue.removeFirst().complete(line);
    } else {
      _log.warning('Resposta inesperada do daemon ignorada: $line');
    }
  }

  void _onProcessDone() {
    _log.warning('Daemon encerrou inesperadamente.');
    for (final c in _responseQueue) {
      if (!c.isCompleted) {
        c.completeError(Exception('Daemon encerrou durante a operação'));
      }
    }
    _responseQueue.clear();
  }

  Future<void> _cleanup() async {
    _alive = false;
    _writeChain = Future.value();
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _process?.kill();
    _process = null;
  }
}
