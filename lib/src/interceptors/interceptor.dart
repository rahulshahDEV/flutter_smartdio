import '../core/smart_dio_request.dart';
import '../core/smart_dio_response.dart';

abstract class SmartDioInterceptor {
  Future<SmartDioRequest> onRequest(SmartDioRequest request) async => request;
  
  Future<SmartDioResponse<T>> onResponse<T>(SmartDioResponse<T> response) async => response;
  
  Future<SmartDioResponse<T>> onError<T>(SmartDioError<T> error) async => error;
}

class InterceptorChain {
  final List<SmartDioInterceptor> _interceptors = [];

  void add(SmartDioInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  void addAll(List<SmartDioInterceptor> interceptors) {
    _interceptors.addAll(interceptors);
  }

  void remove(SmartDioInterceptor interceptor) {
    _interceptors.remove(interceptor);
  }

  void clear() {
    _interceptors.clear();
  }

  List<SmartDioInterceptor> get interceptors => List.unmodifiable(_interceptors);

  Future<SmartDioRequest> processRequest(SmartDioRequest request) async {
    var currentRequest = request;
    
    for (final interceptor in _interceptors) {
      currentRequest = await interceptor.onRequest(currentRequest);
    }
    
    return currentRequest;
  }

  Future<SmartDioResponse<T>> processResponse<T>(SmartDioResponse<T> response) async {
    var currentResponse = response;
    
    for (final interceptor in _interceptors.reversed) {
      currentResponse = await interceptor.onResponse(currentResponse);
    }
    
    return currentResponse;
  }

  Future<SmartDioResponse<T>> processError<T>(SmartDioError<T> error) async {
    var currentError = error;
    
    for (final interceptor in _interceptors.reversed) {
      final result = await interceptor.onError(currentError);
      if (result is SmartDioSuccess<T>) {
        return result;
      }
      currentError = result as SmartDioError<T>;
    }
    
    return currentError;
  }
}