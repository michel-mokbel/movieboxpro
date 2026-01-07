import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static const String _countryKey = 'user_country';
  
  static Future<String?> initializeLocation() async {
    try {
      // Check if we have a cached country
      final prefs = await SharedPreferences.getInstance();
      final cachedCountry = prefs.getString(_countryKey);
      if (cachedCountry != null) {
        return cachedCountry;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low
      );

      // Get country from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && placemarks.first.isoCountryCode != null) {
        final country = placemarks.first.isoCountryCode!;
        // Cache the country code
        await prefs.setString(_countryKey, country);
        print('Country cached from location: $country');
        return country;
      }

      return null; // Return null if no country could be determined
    } catch (e) {
      print('Error getting country: $e');
      return null; // Return null in case of any errors
    }
  }

  static Future<String?> getCountry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_countryKey);
    } catch (e) {
      print('Error getting cached country: $e');
      return null; // Return null in case of any errors
    }
  }
} 