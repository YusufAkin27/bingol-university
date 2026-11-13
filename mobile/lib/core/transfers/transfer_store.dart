import 'dart:convert';
import 'dart:io';

import 'transfer_job.dart';

/// İş kayıtlarının kalıcı deposu. Bozuk kayıt atlanır; yazma atomiktir (tmp + yeniden adlandırma).
abstract class TransferStore {
  Future<List<TransferJob>> load();
  Future<void> save(List<TransferJob> jobs);

  /// İşin yerel kopyalarının yaşadığı dizin (kuyruk buraya kopyalar ve siler).
  Future<Directory> filesDir();
}

class MemoryTransferStore implements TransferStore {
  MemoryTransferStore({Directory? dir}) : _dir = dir;

  String? _raw;
  Directory? _dir;

  @override
  Future<List<TransferJob>> load() async {
    final raw = _raw;
    if (raw == null) return [];
    return _decode(raw);
  }

  @override
  Future<void> save(List<TransferJob> jobs) async => _raw = jsonEncode(jobs.map((j) => j.toJson()).toList());

  @override
  Future<Directory> filesDir() async => _dir ??= await Directory.systemTemp.createTemp('bu_transfers_');
}

List<TransferJob> _decode(String raw) {
  try {
    final list = jsonDecode(raw);
    if (list is! List) return [];
    return list.map(TransferJob.fromJson).whereType<TransferJob>().toList();
  } catch (_) {
    return [];
  }
}

/// `<uygulama dizini>/transfers/jobs.json`; dosyalar `<uygulama dizini>/transfers/files/<jobId>/`.
class FileTransferStore implements TransferStore {
  FileTransferStore(this.root);

  final Directory root;

  File get _file => File('${root.path}${Platform.pathSeparator}jobs.json');

  @override
  Future<List<TransferJob>> load() async {
    try {
      if (!await _file.exists()) return [];
      return _decode(await _file.readAsString());
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<TransferJob> jobs) async {
    await root.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(jobs.map((j) => j.toJson()).toList()), flush: true);
    await tmp.rename(_file.path);
  }

  @override
  Future<Directory> filesDir() async {
    final d = Directory('${root.path}${Platform.pathSeparator}files');
    await d.create(recursive: true);
    return d;
  }
}
