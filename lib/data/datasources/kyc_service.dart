import 'dart:math';

/// A Mock KYC Service to simulate the Aadhaar Verification Flow.
class KycService {
  /// Simulates requesting an OTP for the given Aadhaar number.
  /// In a real scenario, this would call Digilocker / Razorpay KYC / Setu API.
  Future<String> requestAadhaarOtp(String aadhaarNumber) async {
    if (aadhaarNumber.length != 12) {
      throw Exception('Invalid Aadhaar Number. Must be 12 digits.');
    }
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Return a mock reference ID for the OTP session
    return 'req_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Simulates verifying the given OTP.
  /// Returns a map of the verified demographic data.
  Future<Map<String, dynamic>> verifyAadhaarOtp({
    required String referenceId,
    required String otp,
    required String aadhaarNumber,
  }) async {
    if (otp.length != 6) {
      throw Exception('Invalid OTP. Must be 6 digits.');
    }
    // Simulate network delay processing the OTP
    await Future.delayed(const Duration(seconds: 2));

    if (otp != '123456') {
      // For demo, we accept '123456' as the correct OTP always.
      throw Exception('Incorrect OTP. Please try again.');
    }

    // Generate some random demographic data based on the Aadhaar Number to simulate auto-fetch.
    final rand = Random(aadhaarNumber.hashCode);
    final isMale = rand.nextBool();
    final year = 1980 + rand.nextInt(20);
    final month = 1 + rand.nextInt(11);
    final day = 1 + rand.nextInt(27);

    return {
      'is_verified': true,
      'gender': isMale ? 'Male' : 'Female',
      'dob': DateTime(year, month, day).toIso8601String(),
      'name': isMale ? 'Ramesh Kumar' : 'Priya Sharma',
      'last_four': aadhaarNumber.substring(8),
      'phone': '+91 9${rand.nextInt(999999999).toString().padLeft(9, '0')}', // Generate realistic mock phone
    };
  }
}
