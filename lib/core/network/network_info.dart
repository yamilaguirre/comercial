import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

/// Información sobre el estado de la conexión de red
abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get connectionStream;
}

/// Implementación concreta de NetworkInfo
@LazySingleton(as: NetworkInfo)
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  const NetworkInfoImpl(this.connectivity);

  @override
  Future<bool> get isConnected async {
    final result = await connectivity.checkConnectivity();
    return _isConnectedResult(result);
  }

  @override
  Stream<bool> get connectionStream {
    return connectivity.onConnectivityChanged.map(
      (result) => _isConnectedResult(result),
    );
  }

  bool _isConnectedResult(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }
}
