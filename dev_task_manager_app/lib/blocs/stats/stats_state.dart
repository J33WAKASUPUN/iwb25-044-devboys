import 'package:equatable/equatable.dart';
import '../../services/stats_service.dart';

abstract class StatsState extends Equatable {
  const StatsState();

  @override
  List<Object?> get props => [];
}

class StatsInitial extends StatsState {}

class StatsLoading extends StatsState {}

class StatsLoaded extends StatsState {
  final TaskStatistics statistics;

  const StatsLoaded({required this.statistics});

  @override
  List<Object> get props => [statistics];
}

class StatsError extends StatsState {
  final String message;

  const StatsError({required this.message});

  @override
  List<Object> get props => [message];
}
