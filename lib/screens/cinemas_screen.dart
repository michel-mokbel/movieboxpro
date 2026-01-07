import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import '../services/ads_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CinemasScreen extends StatefulWidget {
  const CinemasScreen({super.key});

  @override
  State<CinemasScreen> createState() => _CinemasScreenState();
}

class _CinemasScreenState extends State<CinemasScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyCinemas = [];
  bool _isLoading = true;
  String? _error;
  Set<Marker> _markers = {};
  final String _apiKey = 'AIzaSyCsiw4EUdPsStONc7B3rLOh9gwxdP6IE7U';
  bool _mapInitialized = false;
  final AdsService _adsService = AdsService();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    if (_mapController != null) {
      _mapController!.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _error = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _error = 'Location permissions are denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _error = 'Location permissions are permanently denied.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _error = null;
        });
        await _searchNearbyCinemas();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error getting location: $e';
        });
      }
    }
  }

  Future<void> _searchNearbyCinemas() async {
    if (_currentPosition == null) return;

    try {
      final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
          'location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&radius=10000'
          '&type=cinema'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data['status'] == 'OK') {
        if (mounted) {
          setState(() {
            _nearbyCinemas = List<Map<String, dynamic>>.from(data['results']);
            _markers = _nearbyCinemas.map((cinema) {
              final location = cinema['geometry']['location'];
              return Marker(
                markerId: MarkerId(cinema['place_id']),
                position: LatLng(location['lat'], location['lng']),
                infoWindow: InfoWindow(
                  title: cinema['name'],
                  snippet: cinema['vicinity'],
                ),
              );
            }).toSet();
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        throw Exception(data['error_message'] ?? 'Failed to fetch nearby cinemas');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error fetching nearby cinemas: $e';
        });
      }
    }
  }

  Future<void> _launchMaps(double lat, double lng, String placeId) async {
    HapticFeedback.selectionClick();
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$placeId';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Error opening maps: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        );
      }
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    try {
      _mapController = controller;
      await controller.setMapStyle('''
        [
          {
            "elementType": "geometry",
            "stylers": [
              {
                "color": "#212121"
              }
            ]
          },
          {
            "elementType": "labels.text.fill",
            "stylers": [
              {
                "color": "#757575"
              }
            ]
          },
          {
            "elementType": "labels.text.stroke",
            "stylers": [
              {
                "color": "#212121"
              }
            ]
          },
          {
            "featureType": "water",
            "elementType": "geometry",
            "stylers": [
              {
                "color": "#000000"
              }
            ]
          }
        ]
      ''');
      setState(() {
        _mapInitialized = true;
      });
    } catch (e) {
      print('Error initializing map: $e');
      setState(() {
        _error = 'Error initializing map: $e';
      });
    }
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String name) async {
    HapticFeedback.selectionClick();
    await _adsService.showInterstitialAd();
    
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=${Uri.encodeComponent(name)}',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<bool> _shouldShowBanner() async {
    final prefs = await SharedPreferences.getInstance();
    int bannerCounter = prefs.getInt('cinemas_banner_counter') ?? 0;
    bannerCounter++;
    await prefs.setInt('cinemas_banner_counter', bannerCounter);
    return bannerCounter % 2 == 0;
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 24),
            onPressed: onPressed,
            ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full Screen Map
          if (_currentPosition != null)
            GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          zoom: 13,
        ),
        markers: _markers,
        onMapCreated: _onMapCreated,
        myLocationEnabled: _mapInitialized,
              myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
              padding: const EdgeInsets.only(bottom: 300),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: _isLoading
                    ? const CupertinoActivityIndicator(color: Colors.white, radius: 15)
                    : Text(_error ?? 'Location unavailable', style: IOSTheme.body),
              ),
            ),

          // Top Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Floating Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: _buildGlassButton(
              icon: CupertinoIcons.location_fill,
              onPressed: () async {
                HapticFeedback.mediumImpact();
                if (_mapController != null && _currentPosition != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
      ),
    );
  }
              },
            ),
          ),

          // Bottom Sheet List
          if (!_isLoading && _error == null)
            DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.2,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Column(
                        children: [
                          // Handle
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 20),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
        ),
                            ),
                          ),
                          
                          // Title
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                            child: Row(
        children: [
                                Text('Nearby Cinemas', style: IOSTheme.title2),
                                const Spacer(),
          Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: IOSTheme.systemBlue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: IOSTheme.systemBlue.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    '${_nearbyCinemas.length} found',
                                    style: IOSTheme.caption1.copyWith(color: IOSTheme.systemBlue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),

                          // List
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _nearbyCinemas.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Container(
            height: 60,
                                    margin: const EdgeInsets.only(bottom: 20),
            child: FutureBuilder<bool>(
              future: _shouldShowBanner(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == true) {
                  return _adsService.showBannerAd();
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  );
                                }
                                
                                final cinema = _nearbyCinemas[index - 1];
                                          final location = cinema['geometry']['location'];
                                          
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                            ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        final lat = location['lat'];
                                        final lng = location['lng'];
                                        await _openInGoogleMaps(lat, lng, cinema['name']);
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: cinema['photos'] != null && cinema['photos'].isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: 'https://maps.googleapis.com/maps/api/place/photo'
                                                          '?maxwidth=100'
                                                          '&photo_reference=${cinema['photos'][0]['photo_reference']}'
                                                          '&key=$_apiKey',
                                                      height: 60,
                                                      width: 60,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Container(
                                                        color: Colors.white.withOpacity(0.1),
                                                      ),
                                                      errorWidget: (context, url, error) => Container(
                                                        color: Colors.white.withOpacity(0.1),
                                                        child: const Icon(CupertinoIcons.film, color: Colors.white),
                                                      ),
                                                    )
                                                  : Container(
                                                      height: 60,
                                                      width: 60,
                                                      color: Colors.white.withOpacity(0.1),
                                                      child: const Icon(CupertinoIcons.film, color: Colors.white),
                                                    ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    cinema['name'],
                                                    style: IOSTheme.headline,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    cinema['vicinity'] ?? 'Unknown location',
                                                    style: IOSTheme.caption1.copyWith(color: Colors.white.withOpacity(0.6)),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      if (cinema['rating'] != null) ...[
                                                        const Icon(CupertinoIcons.star_fill, size: 14, color: Colors.amber),
                                                        const SizedBox(width: 4),
                                                        Text(cinema['rating'].toString(), style: IOSTheme.caption1.copyWith(fontWeight: FontWeight.bold)),
                                                        const SizedBox(width: 12),
                                                      ],
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: (cinema['opening_hours'] != null && cinema['opening_hours']['open_now']) 
                                                              ? Colors.green.withOpacity(0.2) 
                                                              : const Color(0xFF0A84FF).withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(4),
                                                      ),
                                                        child: Text(
                                                          (cinema['opening_hours'] != null && cinema['opening_hours']['open_now']) ? 'OPEN' : 'CLOSED',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: (cinema['opening_hours'] != null && cinema['opening_hours']['open_now']) 
                                                                ? Colors.green 
                                                                : const Color(0xFF0A84FF),
                                                          ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: IOSTheme.systemBlue.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                icon: const Icon(CupertinoIcons.paperplane_fill, color: IOSTheme.systemBlue, size: 20),
                                                onPressed: () => _launchMaps(
                                                  location['lat'],
                                                  location['lng'],
                                                  cinema['place_id'],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                    ),
                  ),
                );
              },
          ),
        ],
      ),
    );
  }
}
