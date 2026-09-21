import 'package:flutter/material.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String? _startingPoint;
  String? _destination;

  final List<String> _locations = [
    'Main Building',
    'Administration Building',
    'Library',
    'Computer Laboratory',
    'Student Center',
    'Cafeteria',
    'Gymnasium',
  ];

  void _generateRoute() {
    if (_startingPoint == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a starting point and destination.'),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Route generated from $_startingPoint to $_destination.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // =====================================================
              // HEADER
              // =====================================================
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 0),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Campus Map',
                      textAlign: TextAlign.left,

                      style: TextStyle(
                        color: Color(0xFF20262D),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      'Find your destination',
                      textAlign: TextAlign.left,

                      style: TextStyle(color: Color(0xFF8A969E), fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // =====================================================
              // MAP AREA
              // =====================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),

                child: Container(
                  width: double.infinity,
                  height: 272,

                  decoration: BoxDecoration(
                    color: const Color(0xFFE0EAF3),

                    borderRadius: BorderRadius.circular(18),
                  ),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 58,
                        color: Colors.blue.shade700,
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        '2.5D Campus Map',

                        style: TextStyle(
                          color: Color(0xFF52616B),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Campus map will be added here.',

                        style: TextStyle(
                          color: Color(0xFF8A969E),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // =====================================================
              // ROUTE PANEL
              // =====================================================
              Container(
                width: double.infinity,

                padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),

                decoration: const BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ------------------------------------------------
                    // STARTING POINT
                    // ------------------------------------------------
                    const Text(
                      'Starting Point',

                      style: TextStyle(
                        color: Color(0xFF34454F),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 7),

                    _locationDropdown(
                      value: _startingPoint,
                      hint: 'Select starting point',
                      icon: Icons.location_on,
                      onChanged: (value) {
                        setState(() {
                          _startingPoint = value;
                        });
                      },
                    ),

                    const SizedBox(height: 13),

                    // ------------------------------------------------
                    // DESTINATION
                    // ------------------------------------------------
                    const Text(
                      'Destination',

                      style: TextStyle(
                        color: Color(0xFF34454F),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 7),

                    _locationDropdown(
                      value: _destination,
                      hint: 'Select destination',
                      icon: Icons.flag,
                      onChanged: (value) {
                        setState(() {
                          _destination = value;
                        });
                      },
                    ),

                    const SizedBox(height: 15),

                    // ------------------------------------------------
                    // GENERATE ROUTE
                    // ------------------------------------------------
                    SizedBox(
                      width: double.infinity,
                      height: 45,

                      child: ElevatedButton(
                        onPressed: _generateRoute,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0866E8),

                          foregroundColor: Colors.white,

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        child: const Text(
                          'GENERATE ROUTE',

                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // LOCATION DROPDOWN
  // ================================================================

  Widget _locationDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,

      isExpanded: true,

      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF657984)),

      decoration: InputDecoration(
        hintText: hint,

        hintStyle: const TextStyle(color: Color(0xFF9AA6AE), fontSize: 10),

        prefixIcon: Icon(icon, color: const Color(0xFF0866E8), size: 19),

        filled: true,

        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),

          borderSide: const BorderSide(color: Color(0xFFD1E0E7), width: 1),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),

          borderSide: const BorderSide(color: Color(0xFF0866E8), width: 1.2),
        ),
      ),

      items: _locations.map((location) {
        return DropdownMenuItem<String>(
          value: location,

          child: Text(
            location,

            style: const TextStyle(color: Color(0xFF34454F), fontSize: 11),
          ),
        );
      }).toList(),

      onChanged: onChanged,
    );
  }
}
