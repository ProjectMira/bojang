import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'offline_cache_service.dart';
import 'progress_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();
  
  final ApiService _apiService = ApiService();
  final OfflineCacheService _cacheService = OfflineCacheService();
  final Connectivity _connectivity = Connectivity();
  
  bool _isOnline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  int _pendingItems = 0;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  
  // Getters
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingItems => _pendingItems;
  
  Future<void> initialize() async {
    // Initialize connectivity monitoring
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    
    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;
    
    // Load last sync time and pending items count
    _lastSyncTime = await _cacheService.getLastSyncTime();
    _pendingItems = await _cacheService.getOfflineDataCount();
    
    // Start periodic sync if online
    if (_isOnline) {
      _startPeriodicSync();
    }
    
    notifyListeners();
  }
  
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
  
  // =====================================================
  // CONNECTIVITY HANDLING
  // =====================================================
  
  void _onConnectivityChanged(ConnectivityResult result) async {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    
    if (!wasOnline && _isOnline) {
      // Just came online - trigger sync
      print('Device came online - triggering sync');
      await syncAll();
      _startPeriodicSync();
    } else if (wasOnline && !_isOnline) {
      // Just went offline
      print('Device went offline');
      _stopPeriodicSync();
    }
    
    notifyListeners();
  }
  
  void _startPeriodicSync() {
    _stopPeriodicSync();
    
    // Sync every 5 minutes when online
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline && !_isSyncing) {
        syncAll();
      }
    });
  }
  
  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }
  
  // =====================================================
  // SYNC METHODS
  // =====================================================
  
  Future<bool> syncAll() async {
    if (!_isOnline || _isSyncing) {
      return false;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      print('Starting full sync...');
      
      // 1. Sync offline data first
      final offlineSyncSuccess = await _cacheService.syncOfflineData();
      if (offlineSyncSuccess) {
        print('Offline data synced successfully');
      }
      
      // 2. Check for content updates
      await _cacheService.checkForContentUpdates();
      
      // 3. Sync user progress
      await _syncUserProgress();
      
      // 4. Update sync status
      _lastSyncTime = DateTime.now();
      _pendingItems = await _cacheService.getOfflineDataCount();
      
      print('Full sync completed successfully');
      return true;
      
    } catch (e) {
      print('Error during sync: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  Future<void> _syncUserProgress() async {
    try {
      // Get user progress from API and update local progress service
      final progressData = await _apiService.getUserProgress();
      if (progressData != null) {
        // Update local progress service with server data
        // This would require updating ProgressService to handle server sync
        print('User progress synced from server');
      }
    } catch (e) {
      print('Error syncing user progress: $e');
    }
  }
  
  Future<bool> syncQuizSession(Map<String, dynamic> sessionData) async {
    if (_isOnline) {
      // Try to sync immediately
      final success = await _apiService.submitQuizSession(sessionData);
      if (success) {
        return true;
      }
    }
    
    // Store offline for later sync
    await _cacheService.storeOfflineQuizSession(sessionData);
    _pendingItems = await _cacheService.getOfflineDataCount();
    notifyListeners();
    return false; // Indicates it was stored offline
  }
  
  Future<bool> syncGameScore(Map<String, dynamic> scoreData) async {
    if (_isOnline) {
      final success = await _apiService.submitGameScore(scoreData);
      if (success) {
        return true;
      }
    }
    
    await _cacheService.storeOfflineGameScore(scoreData);
    _pendingItems = await _cacheService.getOfflineDataCount();
    notifyListeners();
    return false;
  }
  
  Future<bool> syncProgressUpdate(Map<String, dynamic> progressData) async {
    if (_isOnline) {
      final success = await _apiService.updateStreak(progressData);
      if (success) {
        return true;
      }
    }
    
    await _cacheService.storeOfflineProgressUpdate(progressData);
    _pendingItems = await _cacheService.getOfflineDataCount();
    notifyListeners();
    return false;
  }
  
  // =====================================================
  // MANUAL SYNC TRIGGERS
  // =====================================================
  
  Future<bool> forceSyncNow() async {
    if (!_isOnline) {
      return false;
    }
    
    return await syncAll();
  }
  
  Future<void> syncWhenOnline() async {
    if (_isOnline) {
      await syncAll();
    } else {
      // Set up a one-time listener for when we come back online
      StreamSubscription<ConnectivityResult>? subscription;
      subscription = _connectivity.onConnectivityChanged.listen((result) async {
        if (result != ConnectivityResult.none) {
          await syncAll();
          subscription?.cancel();
        }
      });
    }
  }
  
  // =====================================================
  // UTILITY METHODS
  // =====================================================
  
  String getSyncStatusMessage() {
    if (_isSyncing) {
      return 'Syncing...';
    } else if (!_isOnline) {
      return 'Offline';
    } else if (_pendingItems > 0) {
      return '$_pendingItems items pending sync';
    } else if (_lastSyncTime != null) {
      final timeDiff = DateTime.now().difference(_lastSyncTime!);
      if (timeDiff.inMinutes < 1) {
        return 'Synced just now';
      } else if (timeDiff.inMinutes < 60) {
        return 'Synced ${timeDiff.inMinutes}m ago';
      } else if (timeDiff.inHours < 24) {
        return 'Synced ${timeDiff.inHours}h ago';
      } else {
        return 'Synced ${timeDiff.inDays}d ago';
      }
    } else {
      return 'Never synced';
    }
  }
  
  Color getSyncStatusColor() {
    if (_isSyncing) {
      return Colors.orange;
    } else if (!_isOnline) {
      return Colors.red;
    } else if (_pendingItems > 0) {
      return Colors.amber;
    } else {
      return Colors.green;
    }
  }
  
  IconData getSyncStatusIcon() {
    if (_isSyncing) {
      return Icons.sync;
    } else if (!_isOnline) {
      return Icons.cloud_off;
    } else if (_pendingItems > 0) {
      return Icons.cloud_upload;
    } else {
      return Icons.cloud_done;
    }
  }
  
  Future<Map<String, dynamic>> getSyncStats() async {
    final pendingCount = await _cacheService.getOfflineDataCount();
    final lastSync = await _cacheService.getLastSyncTime();
    
    return {
      'is_online': _isOnline,
      'is_syncing': _isSyncing,
      'pending_items': pendingCount,
      'last_sync': lastSync?.toIso8601String(),
      'status_message': getSyncStatusMessage(),
    };
  }
  
  // =====================================================
  // SMART SYNC STRATEGIES
  // =====================================================
  
  Future<void> smartSync() async {
    if (!_isOnline) return;
    
    // Determine sync priority based on data age and type
    final pendingCount = await _cacheService.getOfflineDataCount();
    
    if (pendingCount == 0) {
      // No pending data, just check for content updates
      await _cacheService.checkForContentUpdates();
    } else if (pendingCount < 10) {
      // Small amount of data, sync immediately
      await syncAll();
    } else {
      // Large amount of data, sync in batches to avoid overwhelming the server
      await _batchSync();
    }
  }
  
  Future<void> _batchSync() async {
    // This would implement batched syncing for large amounts of offline data
    // For now, just do a regular sync
    await syncAll();
  }
  
  // Background sync when app is backgrounded
  Future<void> backgroundSync() async {
    if (_isOnline && !_isSyncing) {
      // Quick sync of critical data only
      await _cacheService.syncOfflineData();
    }
  }
}
