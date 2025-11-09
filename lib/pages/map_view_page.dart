import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../api_service.dart';
import 'comments_page.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  final MapController _mapController = MapController();
  
  LatLng _currentPosition = const LatLng(48.8566, 2.3522); // Paris par défaut
  bool _isLoadingLocation = true;
  List<Map<String, dynamic>> _publications = [];
  bool _isLoadingPublications = true;
  
  // Fournisseurs de tuiles
  String _currentTileProvider = 'osm';
  final Map<String, String> _tileProviders = {
    'osm': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'topo': 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    'carto': 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    'dark': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
    'satellite': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  };

  StreamSubscription<Position>? _positionStream;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadPublications();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadPublications();
    });
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await _getCurrentLocation();
      _startLocationTracking();
    } else {
      setState(() => _isLoadingLocation = false);
      _showMessage('Permission de localisation refusée');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      _mapController.move(_currentPosition, 13.0);
      debugPrint('📍 Position: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Erreur géolocalisation: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Mise à jour tous les 10 mètres
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
        debugPrint('🔄 Position mise à jour: ${position.latitude}, ${position.longitude}');
      }
    });
  }

  Future<void> _loadPublications() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final token = appProvider.accessToken;

    if (token == null) return;

    try {
      final result = await ApiService.getPublications(token);
      
      if (mounted) {
        setState(() {
          _publications = (result['publications'] as List).cast<Map<String, dynamic>>();
          _isLoadingPublications = false;
        });
      }

      debugPrint('✅ ${_publications.length} publications chargées');
    } catch (e) {
      debugPrint('❌ Erreur chargement publications: $e');
      if (mounted) {
        setState(() => _isLoadingPublications = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00D4FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openPublicationDetails(Map<String, dynamic> publication) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barre de drag
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Auteur
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF00D4FF),
                      backgroundImage: publication['author']?['profilePhoto'] != null
                          ? NetworkImage(publication['author']['profilePhoto'])
                          : null,
                      child: publication['author']?['profilePhoto'] == null
                          ? Text(
                              publication['author']?['name']?.substring(0, 1).toUpperCase() ?? '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            publication['author']?['name'] ?? 'Utilisateur',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _formatTimestamp(publication['createdAt']),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Contenu
                Text(
                  publication['content'] ?? '',
                  style: const TextStyle(fontSize: 15),
                ),

                const SizedBox(height: 12),

                // Localisation
                if (publication['latitude'] != null && publication['longitude'] != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${publication['latitude']?.toStringAsFixed(4)}, ${publication['longitude']?.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Bouton commentaires
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentsPage(
                          publicationId: publication['_id'],
                          publicationContent: publication['content'] ?? '',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.comment),
                  label: Text('Voir les commentaires (${publication['comments']?.length ?? 0})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      final date = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) return '${diff.inDays}j';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}min';
      return 'À l\'instant';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00D4FF),
        elevation: 0,
        title: const Text(
          'Carte des publications',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Bouton actualiser
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              _loadPublications();
              _getCurrentLocation();
            },
          ),
          // Menu fournisseurs de tuiles
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers, color: Colors.black),
            onSelected: (value) {
              setState(() {
                _currentTileProvider = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'osm', child: Text('🗺️ OpenStreetMap')),
              const PopupMenuItem(value: 'topo', child: Text('⛰️ Topographique')),
              const PopupMenuItem(value: 'carto', child: Text('🎨 Carto Voyager')),
              const PopupMenuItem(value: 'dark', child: Text('🌙 Mode Sombre')),
              const PopupMenuItem(value: 'satellite', child: Text('🛰️ Satellite')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Carte
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 13.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              // Couche de tuiles
              TileLayer(
                urlTemplate: _tileProviders[_currentTileProvider],
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.center',
              ),

              // Marqueurs
              MarkerLayer(
                markers: [
                  // Marqueur de position actuelle
                  if (!_isLoadingLocation)
                    Marker(
                      point: _currentPosition,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 3),
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                    ),

                  // Marqueurs de publications
                  ..._publications
                      .where((pub) => pub['latitude'] != null && pub['longitude'] != null)
                      .map((pub) => Marker(
                            point: LatLng(pub['latitude'], pub['longitude']),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => _openPublicationDetails(pub),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D4FF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          )),
                ],
              ),
            ],
          ),

          // Loading indicator
          if (_isLoadingLocation || _isLoadingPublications)
            const Positioned(
              top: 16,
              left: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00D4FF),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Chargement...'),
                    ],
                  ),
                ),
              ),
            ),

          // Compteur de publications
          Positioned(
            bottom: 16,
            right: 16,
            child: Card(
              color: const Color(0xFF00D4FF),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      '${_publications.where((p) => p['latitude'] != null).length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'map_location',
        backgroundColor: const Color(0xFF00D4FF),
        onPressed: () {
          _mapController.move(_currentPosition, 13.0);
        },
        child: const Icon(Icons.my_location, color: Colors.black),
      ),
    );
  }
}
