// Location fakes for the end-to-end suite: the learner is "in Kathmandu".
//
// geocoding_darwin talks to CoreLocation through a Pigeon proxy API that a
// method-channel mock cannot answer, so both plugins are replaced at their
// platform interfaces instead.

// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/widgets.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart'
    as pi;
import 'package:geolocator/geolocator.dart';

/// Calls the app made to the fakes, for assertions.
final List<String> locationCalls = [];

class FakeGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;

  @override
  Future<LocationPermission> checkPermission() async {
    locationCalls.add('checkPermission');
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    locationCalls.add('requestPermission');
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  Position get _kathmandu => Position(
    latitude: 27.7172,
    longitude: 85.3240,
    timestamp: DateTime.now(),
    accuracy: 1000,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    isMocked: true,
  );

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => _kathmandu;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    locationCalls.add('getCurrentPosition');
    return _kathmandu;
  }
}

class _FakeGeocoding extends pi.Geocoding {
  _FakeGeocoding(super.params) : super.implementation();

  @override
  Future<List<pi.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    Locale? locale,
  }) async {
    locationCalls.add('placemarkFromCoordinates');
    return const [
      pi.Placemark(
        locality: 'Kathmandu',
        country: 'Nepal',
        isoCountryCode: 'NP',
        administrativeArea: 'Bagmati',
      ),
    ];
  }
}

class _FakeGeocodingFactory extends pi.GeocodingPlatformFactory {
  @override
  pi.Geocoding createGeocoding(pi.GeocodingCreationParams params) =>
      _FakeGeocoding(params);
}

/// Replaces geolocator and geocoding with the Kathmandu fakes.
void installFakeLocation() {
  GeolocatorPlatform.instance = FakeGeolocator();
  pi.GeocodingPlatformFactory.instance = _FakeGeocodingFactory();
}
