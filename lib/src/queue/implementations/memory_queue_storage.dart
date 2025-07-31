import '../request_queue.dart';

class MemoryQueueStorage implements RequestQueueStorage {
  final List<QueuedRequest> _storage = [];

  @override
  Future<void> save(List<QueuedRequest> requests) async {
    _storage.clear();
    _storage.addAll(requests);
  }

  @override
  Future<List<QueuedRequest>> load() async {
    return List.from(_storage);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  int get length => _storage.length;
  
  bool get isEmpty => _storage.isEmpty;
  
  bool get isNotEmpty => _storage.isNotEmpty;
}