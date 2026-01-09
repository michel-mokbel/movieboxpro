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
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
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
          {"elementType":"geometry","stylers":[{"color":"#1B1F2B"}]},
          {"elementType":"labels.text.fill","stylers":[{"color":"#9AA4B2"}]},
          {"elementType":"labels.text.stroke","stylers":[{"color":"#1B1F2B"}]},
          {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0B0F17"}]}
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: Stack(
        children: [
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
              padding: const EdgeInsets.only(bottom: 320),
            )
          else
            Container(
              color: BentoTheme.background,
              child: Center(
                child: _isLoading
                    ? const CupertinoActivityIndicator(color: Colors.white, radius: 15)
                    : Text(_error ?? 'Location unavailable', style: BentoTheme.body),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    BentoTheme.background.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: BentoCard(
              padding: const EdgeInsets.all(8),
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context),
              child: const Icon(CupertinoIcons.arrow_left, color: Colors.white, size: 18),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: BentoCard(
              padding: const EdgeInsets.all(8),
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
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
              child: const Icon(CupertinoIcons.location_fill, color: Colors.white, size: 18),
            ),
          ),
          if (!_isLoading && _error == null)
            DraggableScrollableSheet(
              initialChildSize: 0.42,
              minChildSize: 0.2,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: BentoTheme.background.withOpacity(0.92),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(top: BorderSide(color: BentoTheme.outline)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: BentoTheme.textMuted,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Text('Nearby Cinemas', style: BentoTheme.title.copyWith(color: Colors.white)),
                                const Spacer(),
                                BentoCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  borderRadius: BorderRadius.circular(20),
                                  color: BentoTheme.accent.withOpacity(0.15),
                                  border: Border.all(color: BentoTheme.accent.withOpacity(0.4)),
                                  child: Text(
                                    '${_nearbyCinemas.length} found',
                                    style: BentoTheme.caption.copyWith(color: BentoTheme.accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
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

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: BentoCard(
                                    padding: const EdgeInsets.all(14),
                                    borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
                                    onTap: () async {
                                      final lat = location['lat'];
                                      final lng = location['lng'];
                                      await _openInGoogleMaps(lat, lng, cinema['name']);
                                    },
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
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
                                                    color: BentoTheme.surfaceAlt,
                                                  ),
                                                  errorWidget: (context, url, error) => Container(
                                                    color: BentoTheme.surfaceAlt,
                                                    child: const Icon(CupertinoIcons.film, color: Colors.white),
                                                  ),
                                                )
                                              : Container(
                                                  height: 60,
                                                  width: 60,
                                                  color: BentoTheme.surfaceAlt,
                                                  child: const Icon(CupertinoIcons.film, color: Colors.white),
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cinema['name'],
                                                style: BentoTheme.title.copyWith(color: Colors.white),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                cinema['vicinity'] ?? 'Unknown location',
                                                style: BentoTheme.caption.copyWith(color: BentoTheme.textSecondary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  if (cinema['rating'] != null) ...[
                                                    const Icon(CupertinoIcons.star_fill, size: 14, color: BentoTheme.highlight),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      cinema['rating'].toString(),
                                                      style: BentoTheme.caption.copyWith(color: Colors.white),
                                                    ),
                                                    const SizedBox(width: 12),
                                                  ],
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: (cinema['opening_hours'] != null && cinema['opening_hours']['open_now'])
                                                          ? Colors.green.withOpacity(0.2)
                                                          : BentoTheme.accent.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: BentoTheme.outline),
                                                    ),
                                                    child: Text(
                                                      (cinema['opening_hours'] != null && cinema['opening_hours']['open_now'])
                                                          ? 'OPEN'
                                                          : 'CLOSED',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: (cinema['opening_hours'] != null && cinema['opening_hours']['open_now'])
                                                            ? Colors.green
                                                            : BentoTheme.accent,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        BentoCard(
                                          padding: const EdgeInsets.all(8),
                                          borderRadius: BorderRadius.circular(14),
                                          color: BentoTheme.accent.withOpacity(0.15),
                                          border: Border.all(color: BentoTheme.accent.withOpacity(0.4)),
                                          onTap: () => _launchMaps(
                                            location['lat'],
                                            location['lng'],
                                            cinema['place_id'],
                                          ),
                                          child: const Icon(CupertinoIcons.paperplane_fill, color: BentoTheme.accent, size: 18),
                                        ),
                                      ],
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
