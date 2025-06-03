import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart'; // Add google_fonts for better fonts

const String openRouteApiKey = '5b3ce3597851110001cf62480f90ebec2d7846a6ab421cefec6bbb6d';

class RouteMapScreen extends StatefulWidget {
  final double shipperLat, shipperLng, destLat, destLng;
  const RouteMapScreen({
    required this.shipperLat,
    required this.shipperLng,
    required this.destLat,
    required this.destLng,
    super.key,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen>
    with SingleTickerProviderStateMixin {
  List<LatLng> routePoints = [];
  List<String> instructions = [];
  int currentStep = 0;
  bool firstPersonMode = true;
  final FlutterTts flutterTts = FlutterTts();
  final MapController _mapController = MapController();
  double zoom = 17;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    fetchRoute();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    flutterTts.stop();
    _animController.dispose();
    super.dispose();
  }
  

  String translateInstruction(String instruction) {
    instruction = instruction.trim();
    final lower = instruction.toLowerCase();
 if (lower.contains('arrive at')) {
  final atMatch = RegExp(r'arrive at (.*?)(?:,\s*(on the left|on the right))?$', caseSensitive: false).firstMatch(instruction);
  if (atMatch != null) {
    final location = atMatch.group(1)?.trim() ?? 'điểm đến';
    final side = atMatch.group(2)?.toLowerCase();
    String sideVi = '';
    if (side == 'on the left') sideVi = ', ở bên trái';
    else if (side == 'on the right') sideVi = ', ở bên phải';
    return 'Đã đến ${capitalizeEachWord(location)}$sideVi';
  }
  return 'Bạn đã đến nơi';
}
    final regex = RegExp(r'Head (\w+)', caseSensitive: false);
    final match = regex.firstMatch(instruction);


    if (match != null) {
      String dir = match.group(1) ?? '';
      String dirVi = '';
      switch (dir.toLowerCase()) {
        case 'north':
          dirVi = 'đi về hướng Bắc';
          break;
        case 'south':
          dirVi = 'đi về hướng Nam';
          break;
        case 'east':
          dirVi = 'đi về hướng Đông';
          break;
        case 'west':
          dirVi = 'đi về hướng Tây';
          break;
        default:
          dirVi = 'đi thẳng';
      }
      return capitalize(dirVi);
    }

    if (instruction.toLowerCase().contains('turn sharp right')) {
      final street = getStreetName(instruction);
      return 'Rẽ gấp phải${street.isNotEmpty ? ' vào ${capitalizeEachWord(street)}' : ''}';
    }
    if (instruction.toLowerCase().contains('turn sharp left')) {
      final street = getStreetName(instruction);
      return 'Rẽ gấp trái${street.isNotEmpty ? ' vào ${capitalizeEachWord(street)}' : ''}';
    }
    if (instruction.toLowerCase().contains('turn left')) {
      final street = getStreetName(instruction);
      return 'Rẽ trái${street.isNotEmpty ? ' vào ${capitalizeEachWord(street)}' : ''}';
    }
    if (instruction.toLowerCase().contains('turn right')) {
      final street = getStreetName(instruction);
      return 'Rẽ phải${street.isNotEmpty ? ' vào ${capitalizeEachWord(street)}' : ''}';
    }
    if (instruction.toLowerCase().contains('straight')) {
      final distance = getDistance(instruction);
      return 'Đi thẳng${distance.isNotEmpty ? ' $distance' : ''}';
    }
    if (instruction.toLowerCase().contains('destination')) return 'Bạn đã đến nơi';
    if (instruction.toLowerCase().contains('slight left')) {
      final street = getStreetName(instruction);
      return 'Rẽ nhẹ trái${street.isNotEmpty ? ' vào ${capitalizeEachWord(street)}' : ''}';
    }
    if (instruction.toLowerCase().contains('slight right')) {
      final street = getStreetName(instruction);
      return 'Rẽ nhẹ phải${street.isNotEmpty ? ' vào ${capitalizeEachWord(street)}' : ''}';
    }
    if (instruction.toLowerCase().contains('roundabout')) {
      final street = getStreetName(instruction);
      return 'Vào vòng xuyến${street.isNotEmpty ? ' và đi theo ${capitalizeEachWord(street)}' : ''}';
    }
    if (instruction.toLowerCase().contains('keep left')) return 'Giữ bên trái';
    if (instruction.toLowerCase().contains('keep right')) return 'Giữ bên phải';
    if (instruction.toLowerCase().contains('merge')) return 'Nhập làn';
    if (instruction.toLowerCase().contains('exit')) return 'Ra khỏi đường';
    if (instruction.toLowerCase().contains('follow')) {
      final street = getStreetName(instruction);
      return 'Đi theo${street.isNotEmpty ? ' ${capitalizeEachWord(street)}' : ''}';
    }
    if (instruction.toLowerCase().contains('continue')) return 'Tiếp tục đi thẳng';
    if (instruction.toLowerCase().contains('u-turn')) return 'Quay đầu';
    if (instruction.toLowerCase().contains('fork left')) return 'Đi nhánh trái';
    if (instruction.toLowerCase().contains('fork right')) return 'Đi nhánh phải';
    

    return capitalize(instruction);
  }

  String getDistance(String instruction) {
    final regex = RegExp(r'\((\d+\.?\d*) m\)', caseSensitive: false);
    final match = regex.firstMatch(instruction);
    if (match != null) {
      return '${match.group(1)} m';
    }
    return '';
  }

  String getStreetName(String instruction) {
    final regex = RegExp(r'(?:onto|on|left onto|right onto|left on|right on) (.+)', caseSensitive: false);
    final match = regex.firstMatch(instruction);
    if (match != null) {
      return match.group(1) ?? '';
    }
    return '';
  }

  String capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  String capitalizeEachWord(String s) =>
      s.split(' ').map((w) => capitalize(w)).join(' ');

  Future<void> speak(String text) async {
    await flutterTts.setLanguage("vi-VN");
    await flutterTts.speak(text);
  }

  Future<void> fetchRoute() async {
    final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$openRouteApiKey&start=${widget.shipperLng},${widget.shipperLat}&end=${widget.destLng},${widget.destLat}');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final coords = decoded['features'][0]['geometry']['coordinates'] as List;
      final segments = decoded['features'][0]['properties']['segments'] as List;
      final steps = segments.isNotEmpty ? segments[0]['steps'] as List : [];
      setState(() {
        routePoints = coords
            .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();
        instructions = steps
            .map<String>((step) =>
                "${translateInstruction(step['instruction'])} (${(step['distance'] as num).toStringAsFixed(0)} m)")
            .toList();
        currentStep = 0;
      });
      if (instructions.isNotEmpty) {
        speak(instructions[0]);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveToCurrentStep();
        });
      }
    }
  }

  void _moveToCurrentStep() {
    if (routePoints.isNotEmpty) {
      _mapController.move(
        routePoints[currentStep.clamp(0, routePoints.length - 1)],
        zoom,
      );
    }
  }

  void enterFirstPersonMode() {
    setState(() {
      firstPersonMode = true;
    });
    speak(instructions[currentStep]);
    _moveToCurrentStep();
    _animController.forward();
  }

  void exitFirstPersonMode() {
    setState(() {
      firstPersonMode = false;
    });
    flutterTts.stop();
    _mapController.move(
      LatLng(
        (widget.shipperLat + widget.destLat) / 2,
        (widget.shipperLng + widget.destLng) / 2,
      ),
      13,
    );
    _animController.reverse();
  }

  void nextStep() {
    if (currentStep < instructions.length - 1) {
      setState(() {
        currentStep++;
      });
      speak(instructions[currentStep]);
      _moveToCurrentStep();
    }
  }

  void prevStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
      speak(instructions[currentStep]);
      _moveToCurrentStep();
    }
  }

  // Removed unused _buildMarker function

  // ignore: unused_element
  Widget _buildInstructionTile(int idx) {
    final isActive = idx == currentStep;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isActive ? Colors.green[700] : Colors.grey[300],
        child: Text(
          '${idx + 1}',
          style: GoogleFonts.montserrat(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        instructions[idx],
        style: GoogleFonts.montserrat(
          color: isActive ? Colors.green[800] : Colors.black87,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      trailing: isActive
          ? Icon(Icons.volume_up, color: Colors.green)
          : null,
      onTap: () {
        setState(() {
          currentStep = idx;
        });
        speak(instructions[idx]);
        _moveToCurrentStep();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Đường đi đến khách hàng',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        elevation: 2,
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: Icon(
                firstPersonMode ? Icons.map_rounded : Icons.directions_walk_rounded,
                key: ValueKey(firstPersonMode),
                size: 28,
              ),
            ),
            tooltip: firstPersonMode
                ? "Chế độ xem bản đồ"
                : "Chế độ góc nhìn thứ nhất",
            onPressed: instructions.isEmpty
                ? null
                : () {
                    if (firstPersonMode) {
                      exitFirstPersonMode();
                    } else {
                      enterFirstPersonMode();
                    }
                  },
          ),
          IconButton(
            icon: Icon(Icons.my_location, size: 28),
            tooltip: "Quay lại vị trí hiện tại",
            onPressed: _moveToCurrentStep,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: firstPersonMode && routePoints.isNotEmpty
                      ? routePoints[currentStep.clamp(0, routePoints.length - 1)]
                      : LatLng(
                          (widget.shipperLat + widget.destLat) / 2,
                          (widget.shipperLng + widget.destLng) / 2,
                        ),
                  initialZoom: zoom,
                  minZoom: 10,
                  maxZoom: 19,
                  onPositionChanged: (pos, _) {
                    zoom = pos.zoom ?? zoom;
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  if (routePoints.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: Colors.blueAccent,
                          strokeWidth: 6,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (routePoints.isNotEmpty)
                        Marker(
                          point: routePoints.first,
                          width: 60,
                          height: 60,
                          child:FittedBox(
                          child: Column(
                            children: [
                              AnimatedScale(
                                scale: 1.1,
                                duration: Duration(milliseconds: 400),
                                curve: Curves.easeOutBack,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 22,
                                  child: Image.asset('assets/images/shipper.png', width: 32, height: 32),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Shipper',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      if (routePoints.isNotEmpty)
                        Marker(
                          point: routePoints.last,
                          width: 60,
                          height: 60,
                          child: FittedBox(
                            child: Column(
                              children: [
                                AnimatedScale(
                                  scale: 1.1,
                                  duration: Duration(milliseconds: 400),
                                  curve: Curves.easeOutBack,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.white,
                                    radius: 22,
                                    child: Image.asset('assets/images/customer.png', width: 32, height: 32),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Khách',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: firstPersonMode
                ? Container(
                    width: double.infinity,
                    color: Colors.green[700],
                    padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (instructions.isNotEmpty)
                              Icon(Icons.directions, color: Colors.white, size: 28),
                            if (instructions.isNotEmpty) SizedBox(width: 8),
                            Flexible(
                              child: instructions.isNotEmpty
                                  ? Text(
                                      instructions[currentStep],
                                      key: ValueKey(currentStep),
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : Text(
                                      "Đang tải hướng dẫn...",
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.arrow_back),
                              label: Text("Lùi lại", style: GoogleFonts.montserrat()),
                              onPressed: currentStep > 0 ? prevStep : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                            ),
                            SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: Icon(Icons.volume_up),
                              label: Text("Đọc lại", style: GoogleFonts.montserrat()),
                              onPressed: instructions.isEmpty
                                  ? null
                                  : () => speak(instructions[currentStep]),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                            ),
                            SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: Icon(Icons.navigate_next),
                              label: Text("Tiếp theo", style: GoogleFonts.montserrat()),
                              onPressed: (instructions.isEmpty ||
                                      currentStep >= instructions.length - 1)
                                  ? null
                                  : nextStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Expanded(
                    flex: 1,
                    child: ListView.builder(
                      itemCount: instructions.length,
                      itemBuilder: (context, idx) {
                        final isActive = idx == currentStep;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive ? Colors.green[700] : Colors.grey[300],
                            child: Text(
                              '${idx + 1}',
                              style: GoogleFonts.montserrat(
                                color: isActive ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            instructions[idx],
                            style: GoogleFonts.montserrat(
                              color: isActive ? Colors.green[800] : Colors.black87,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                          trailing: isActive
                              ? Icon(Icons.volume_up, color: Colors.green)
                              : null,
                          onTap: () {
                            setState(() {
                              currentStep = idx;
                            });
                            speak(instructions[idx]);
                            _moveToCurrentStep();
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}