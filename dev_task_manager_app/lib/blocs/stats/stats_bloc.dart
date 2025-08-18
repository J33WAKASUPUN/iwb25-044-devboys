import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;
import '../../services/stats_service.dart';
import 'stats_event.dart';
import 'stats_state.dart';

class StatsBloc extends Bloc<StatsEvent, StatsState> {
  final StatsService _statsService = StatsService();

  StatsBloc() : super(StatsInitial()) {
    on<LoadStats>(_onLoadStats);
    on<RefreshStats>(_onRefreshStats);

    developer.log('📊 StatsBloc initialized');
  }

  Future<void> _onLoadStats(LoadStats event, Emitter<StatsState> emit) async {
    developer.log('📊 StatsBloc.LoadStats event received');
    emit(StatsLoading());

    try {
      developer.log('📡 Calling StatsService.getTaskStatistics()');
      final statistics = await _statsService.getTaskStatistics();

      developer.log('✅ Received statistics: Total: ${statistics.total}');
      emit(StatsLoaded(statistics: statistics));

      developer.log('✅ StatsLoaded state emitted');
    } catch (e) {
      developer.log('💥 Error loading statistics: $e');
      emit(StatsError(message: 'Failed to load statistics: $e'));
    }
  }

  Future<void> _onRefreshStats(
      RefreshStats event, Emitter<StatsState> emit) async {
    developer.log('🔄 StatsBloc.RefreshStats event received');
    // Don't emit loading for refresh to avoid UI flicker

    try {
      final statistics = await _statsService.getTaskStatistics();
      emit(StatsLoaded(statistics: statistics));
      developer.log('✅ Stats refreshed successfully');
    } catch (e) {
      developer.log('💥 Error refreshing statistics: $e');
      emit(StatsError(message: 'Failed to refresh statistics: $e'));
    }
  }
}
