import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    home: CampusNavScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class CampusNavScreen extends StatefulWidget {
  const CampusNavScreen({super.key});

  @override
  State<CampusNavScreen> createState() => _CampusNavScreenState();
}

class _CampusNavScreenState extends State<CampusNavScreen> {
  // Beacon Configuration: Room Label & Minimum RSSI threshold
  final Map<String, Map<String, dynamic>> beaconConfig = {
    'B1': {'name': 'Class 8', 'threshold': -75},
    'B2': {'name': 'AI Lab', 'threshold': -75},
    'B3': {'name': 'Faculty Cabin', 'threshold': -75},
  };

  final Map<String, int> liveSignals = {};
  String currentRoom = 'Not Detected';
  int currentRssi = -100;
  bool isScanning = false;
  bool isSimulating = false;

  StreamSubscription? scanSubscription;
  Timer? evaluationTimer;
  Timer? simulationTimer;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  // Request runtime location & bluetooth permissions
  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // Toggle Live Hardware BLE Scan
  Future<void> toggleScanning() async {
    if (isScanning) {
      stopScanning();
      return;
    }

    if (isSimulating) stopSimulation();

    // Verify Bluetooth is turned on
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable Bluetooth on your phone')),
      );
      return;
    }

    setState(() => isScanning = true);

    // Listen to incoming advertisement frames
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        String deviceName = r.advertisementData.advName;
        for (String id in beaconConfig.keys) {
          if (deviceName.contains(id)) {
            setState(() {
              liveSignals[id] = r.rssi;
            });
          }
        }
      }
    });

    // Start background scanner
    await FlutterBluePlus.startScan();

    // Check strongest beacon every 1 second
    evaluationTimer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (_) => evaluatePosition(),
    );
  }

  void stopScanning() {
    FlutterBluePlus.stopScan();
    scanSubscription?.cancel();
    evaluationTimer?.cancel();
    setState(() => isScanning = false);
  }

  // Proximity Logic: Pick strongest signal above entry threshold
  void evaluatePosition() {
    int highestRssi = -100;
    String detectedRoom = 'In Corridor / Transition';

    beaconConfig.forEach((beaconId, data) {
      int rssi = liveSignals[beaconId] ?? -100;
      if (rssi > highestRssi && rssi >= data['threshold']) {
        highestRssi = rssi;
        detectedRoom = data['name'];
      }
    });

    setState(() {
      currentRoom = detectedRoom;
      currentRssi = highestRssi;
    });
  }

  // Simulation Fallback Mode
  void toggleSimulation() {
    if (isSimulating) {
      stopSimulation();
      return;
    }

    if (isScanning) stopScanning();

    setState(() => isSimulating = true);

    final demoPath = [
      {'beacon': 'B1', 'room': 'Class 8', 'rssi': -56},
      {'beacon': 'B2', 'room': 'AI Lab', 'rssi': -60},
      {'beacon': 'B3', 'room': 'Faculty Cabin', 'rssi': -52},
      {'beacon': '', 'room': 'In Corridor / Transition', 'rssi': -86},
    ];

    int step = 0;
    simulationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final current = demoPath[step % demoPath.length];
      beaconConfig.forEach((key, _) {
        liveSignals[key] = (key == current['beacon']) ? (current['rssi'] as int) : -90;
      });

      setState(() {
        currentRoom = current['room'] as String;
        currentRssi = current['rssi'] as int;
      });
      step++;
    });
  }

  void stopSimulation() {
    simulationTimer?.cancel();
    setState(() {
      isSimulating = false;
      currentRoom = 'Not Detected';
      currentRssi = -100;
    });
  }

  @override
  void dispose() {
    stopScanning();
    stopSimulation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        centerTitle: true,
        title: const Column(
          children: [
            Text('CampusNav-32', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Edge BLE Indoor Room Finder', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status & Location Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                children: [
                  Text(
                    isScanning ? '● SCANNING ACTIVE' : (isSimulating ? '● SIMULATION ACTIVE' : '○ STANDBY'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isScanning ? Colors.green : (isSimulating ? Colors.amber : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Column(
                      children: [
                        const Text('CURRENT LOCATION', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text(currentRoom, style: const TextStyle(fontSize: 22, color: Color(0xFF58A6FF), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(currentRssi != -100 ? 'RSSI: $currentRssi dBm' : 'RSSI: --', style: const TextStyle(fontSize: 12, color: Color(0xFF7EE787))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isScanning ? Colors.red[700] : const Color(0xFF238636),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: toggleScanning,
                          child: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF30363D)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: toggleSimulation,
                          child: Text(isSimulating ? 'Stop Sim' : 'Simulate Demo', style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Wing Navigation Map
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Wing Floor Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildRoomTile('Class 8', 'Beacon B1'),
                  _buildRoomTile('AI Lab', 'Beacon B2'),
                  _buildRoomTile('Faculty Cabin', 'Beacon B3'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Telemetry Signals Table
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Signal Telemetry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...beaconConfig.keys.map((id) {
                    final rssi = liveSignals[id];
                    final inside = (rssi != null && rssi >= beaconConfig[id]!['threshold']);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$id (${beaconConfig[id]!['name']})', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          Text(rssi != null ? '$rssi dBm' : '--', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          Text(
                            rssi == null ? 'Idle' : (inside ? 'Inside' : 'Far'),
                            style: TextStyle(color: inside ? Colors.green : Colors.amber, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(String roomName, String beaconTag) {
    final bool isSelected = (currentRoom == roomName);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.withValues(alpha: 0.15) : const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSelected ? Colors.green : const Color(0xFF30363D), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(roomName, style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF21262D), borderRadius: BorderRadius.circular(4)),
            child: Text(beaconTag, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}