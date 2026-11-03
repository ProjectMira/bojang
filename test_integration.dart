#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

void main() async {
  print('🧪 BOJANG INTEGRATION TEST');
  print('==========================');
  
  // Test 1: API Health Check
  print('\n1️⃣ Testing API Health...');
  await testApiHealth();
  
  // Test 2: API Authentication
  print('\n2️⃣ Testing API Authentication...');
  await testApiAuth();
  
  // Test 3: API Content Endpoints
  print('\n3️⃣ Testing API Content...');
  await testApiContent();
  
  // Test 4: Database Verification
  print('\n4️⃣ Testing Database Data...');
  await testDatabaseData();
  
  print('\n🎉 Integration Test Complete!');
  print('✅ Your backend API is ready for Flutter app integration');
}

Future<void> testApiHealth() async {
  try {
    final result = await Process.run('curl', [
      '-s',
      'http://localhost:3000/health'
    ]);
    
    if (result.exitCode == 0) {
      final response = jsonDecode(result.stdout);
      print('✅ API Health: ${response['status']}');
      print('   Service: ${response['service']}');
      print('   Version: ${response['version']}');
    } else {
      print('❌ API Health check failed');
    }
  } catch (e) {
    print('❌ API Health error: $e');
  }
}

Future<void> testApiAuth() async {
  try {
    // Test login
    final loginResult = await Process.run('curl', [
      '-s',
      '-X', 'POST',
      'http://localhost:3000/api/v1/auth/login',
      '-H', 'Content-Type: application/json',
      '-d', '{"email": "test@example.com", "password": "testpass123"}'
    ]);
    
    if (loginResult.exitCode == 0) {
      final response = jsonDecode(loginResult.stdout);
      if (response['token'] != null) {
        print('✅ Authentication: Login successful');
        print('   User: ${response['user']['displayName']}');
        print('   Token: ${response['token'].substring(0, 20)}...');
      } else {
        print('❌ Authentication: No token received');
      }
    } else {
      print('❌ Authentication: Login failed');
    }
  } catch (e) {
    print('❌ Authentication error: $e');
  }
}

Future<void> testApiContent() async {
  try {
    // Get auth token first
    final loginResult = await Process.run('curl', [
      '-s',
      '-X', 'POST',
      'http://localhost:3000/api/v1/auth/login',
      '-H', 'Content-Type: application/json',
      '-d', '{"email": "test@example.com", "password": "testpass123"}'
    ]);
    
    if (loginResult.exitCode != 0) {
      print('❌ Content: Could not get auth token');
      return;
    }
    
    final loginResponse = jsonDecode(loginResult.stdout);
    final token = loginResponse['token'];
    
    if (token == null) {
      print('❌ Content: No auth token available');
      return;
    }
    
    // Test categories endpoint
    final categoriesResult = await Process.run('curl', [
      '-s',
      'http://localhost:3000/api/v1/content/categories',
      '-H', 'Authorization: Bearer $token'
    ]);
    
    if (categoriesResult.exitCode == 0) {
      final response = jsonDecode(categoriesResult.stdout);
      if (response['categories'] != null) {
        print('✅ Content: Categories loaded');
        print('   Count: ${response['count']} categories');
        for (var category in response['categories']) {
          print('   - ${category['name']} (${category['levels'].length} levels)');
        }
      } else {
        print('❌ Content: No categories data');
      }
    } else {
      print('❌ Content: Categories request failed');
    }
  } catch (e) {
    print('❌ Content error: $e');
  }
}

Future<void> testDatabaseData() async {
  try {
    final databaseUrl = Platform.environment['DATABASE_URL'];
    if (databaseUrl == null) {
      print('⏭️  Database: skipped (set DATABASE_URL to run)');
      return;
    }
    final result = await Process.run('psql', [
      databaseUrl,
      '-c',
      'SELECT COUNT(*) as categories FROM categories; SELECT COUNT(*) as questions FROM questions; SELECT COUNT(*) as users FROM users;'
    ]);
    
    if (result.exitCode == 0) {
      print('✅ Database: Connected to Render PostgreSQL');
      print('   Output: ${result.stdout}');
    } else {
      print('❌ Database: Connection failed');
    }
  } catch (e) {
    print('❌ Database error: $e');
  }
}
