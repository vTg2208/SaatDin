import '../models/user_model.dart';
import '../models/claim_model.dart';
import '../models/plan_model.dart';
import '../models/platform_model.dart';

/// Placeholder API service for future FastAPI backend integration.
///
/// All methods currently return mock data. When the backend is ready,
/// replace the mock returns with HTTP calls to the FastAPI endpoints.
///
/// Base URL pattern: `https://api.saatdin.com/v1/`
class ApiService {
  static const String baseUrl = 'http://localhost:8000/api/v1';

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── Auth ──────────────────────────────────────────

  /// POST /auth/send-otp
  Future<bool> sendOtp(String phoneNumber) async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  /// POST /auth/verify-otp
  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  // ── Registration ──────────────────────────────────

  /// POST /register
  Future<User> registerUser({
    required String phone,
    required String platformName,
    required String zone,
    required String planName,
  }) async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 800));
    return User.getMockUser();
  }

  // ── Platforms ─────────────────────────────────────

  /// GET /platforms
  Future<List<DeliveryPlatform>> getPlatforms() async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 300));
    return DeliveryPlatform.getPlatforms();
  }

  // ── Plans ─────────────────────────────────────────

  /// GET /plans?zone={zone}&platform={platform}
  Future<List<InsurancePlan>> getPlans({
    required String zone,
    required String platform,
  }) async {
    // TODO: Connect to FastAPI — ZAPE calculates premiums based on zone + platform
    await Future.delayed(const Duration(milliseconds: 300));
    return InsurancePlan.getPlans();
  }

  // ── Policy ────────────────────────────────────────

  /// GET /policy/{userId}
  Future<Map<String, dynamic>> getPolicy(String userId) async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'status': 'active',
      'plan': 'Standard',
      'zone': 'Bellandur',
      'weeklyPremium': 69,
      'earningsProtected': 1240.50,
      'parametricCoverageOn': true,
    };
  }

  // ── Claims ────────────────────────────────────────

  /// GET /claims/{userId}
  Future<List<Claim>> getClaims(String userId) async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 300));
    return Claim.getMockClaims();
  }

  /// POST /claims/submit
  Future<Claim> submitClaim({
    required String userId,
    required ClaimType type,
    required String description,
  }) async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 800));
    return Claim(
      id: '#17215',
      type: type,
      status: ClaimStatus.pending,
      amount: 400,
      date: DateTime.now(),
      description: description,
    );
  }

  // ── Profile ───────────────────────────────────────

  /// GET /profile/{userId}
  Future<User> getProfile(String userId) async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 300));
    return User.getMockUser();
  }

  /// PUT /profile/{userId}
  Future<User> updateProfile(String userId, Map<String, dynamic> data) async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 500));
    return User.getMockUser();
  }

  // ── Triggers / Risk ───────────────────────────────

  /// GET /triggers/active?zone={zone}
  Future<Map<String, dynamic>> getActiveTriggers(String zone) async {
    // TODO: Connect to FastAPI
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'hasActiveAlert': true,
      'alertType': 'rain',
      'alertTitle': 'Heavy Rain Detected',
      'alertDescription':
          'Automatic compensation accumulating based on rainfall intensity.',
      'confidence': 0.94,
    };
  }
}
