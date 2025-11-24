import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Caso de uso base para todos los use cases
/// [Type] es el tipo de retorno
/// [Params] son los parámetros de entrada
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Clase para casos de uso que no requieren parámetros
class NoParams {
  const NoParams();
}

/// Caso de uso base para operaciones síncronas
abstract class SyncUseCase<Type, Params> {
  Either<Failure, Type> call(Params params);
}

/// Caso de uso base para streams
abstract class StreamUseCase<Type, Params> {
  Stream<Either<Failure, Type>> call(Params params);
}
