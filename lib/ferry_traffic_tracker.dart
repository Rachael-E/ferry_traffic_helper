
import 'package:ferry_traffic_helper/ferry_schedule.dart';
import 'package:ferry_traffic_helper/ross_of_mull_points.dart';
import 'package:ferry_traffic_helper/traffic_speed.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:arcgis_maps/arcgis_maps.dart';

class FerryTrafficScreen extends StatefulWidget {
  const FerryTrafficScreen({super.key});

  @override
  State<FerryTrafficScreen> createState() => _FerryTrafficScreenState();
}

class _FerryTrafficScreenState extends State<FerryTrafficScreen> {
  
  // Flags and state management for app readiness and user interaction.
  var _ready = false;
  final ValueNotifier<bool> _isRouteGeometryInitializedNotifier =
    ValueNotifier<bool>(false);
  bool _isTimeChosen = false;

// UI elements to display messages and store user-selected values.
  Text _infoMessage = const Text("Pick departure time",
    style: TextStyle(fontWeight: FontWeight.normal));
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(DateTime.now()); 
  final FerrySchedule _ferrySchedule = FerrySchedule();
  RossOfMullPointsData? _selectedPlace;

// Map controllers and overlays for displaying stops, routes, and meeting points.
  final _mapViewController = ArcGISMapView.createController();
  final _stopsGraphicsOverlay = GraphicsOverlay();
  final _routeGraphicsOverlay = GraphicsOverlay();
  final _meetingPointGraphicsOverlay = GraphicsOverlay();
  final _craignureTrafficStops = <Stop>[];
  final _locationPoints = <ArcGISPoint>[];

// Routing parameters and task for calculating and displaying traffic route.
  late RouteParameters _craignureTrafficRouteParameters;
  late Route _route;
  Polyline? _routeGeometry;
  final _routeTask = RouteTask.withUrl(
    Uri.parse(
      "https://route-api.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World",
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Ferry Traffic Finder",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ArcGISMapView(
                controllerProvider: () => _mapViewController,
                onMapViewReady: onMapViewReady,
              ),
            ),

            Positioned(
              bottom: 50,
              left: 50,
              right: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.more_time,
                            color: Color.fromARGB(255, 5, 130, 117)),
                        SizedBox(width: 1),
                      ],
                    ),
                    onPressed: () async {
                      // Time picker pop-up
                      final TimeOfDay? timeofDay = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                        helpText: "When are you leaving?",
                        initialEntryMode: TimePickerEntryMode.inputOnly,
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors.teal,
                                onPrimary: Colors.white,
                                onSurface: Colors.teal[900]!,
                              ),
                              timePickerTheme: TimePickerThemeData(
                                backgroundColor:
                                    Colors.teal[50], // Time picker background
                                hourMinuteTextColor:
                                    WidgetStateColor.resolveWith((states) =>
                                        states.contains(WidgetState.selected)
                                            ? Colors.white
                                            : Colors.teal[900]!),
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.teal[700],
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (timeofDay != null) {
                        setState(() {
                          _selectedTime = timeofDay;
                          _isTimeChosen = true;
                          _showDepartureSelectionDialog(context);
                        });
                      }
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: !_isTimeChosen ? null : () => clearRouteAndMeetingPointGraphics(),
                    child: const Icon(Icons.layers_clear,
                        color: Color.fromARGB(255, 5, 130, 117)),
                  ),
                ],
              ),
            ),

            // Progress indicator
            if (!_ready)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

// Pop-up to select place of departure
  void _showDepartureSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Where are you leaving from?"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: RossOfMullPointsList.points.length,
              itemBuilder: (BuildContext context, int index) {
                final rossOfMullPointInfo = RossOfMullPointsList.points[index];
                Color tileColor =
                    index % 2 == 0 ? Colors.teal[50]! : Colors.teal[100]!;
                return GestureDetector(
                  onTap: () {
                    createLocationPoints(rossOfMullPointInfo.point);
                    generateRoute();
                    _showConfirmationDialog(context);
                    setState(() {
                      _selectedPlace = rossOfMullPointInfo;
                    });
                  },
                  child: Card(
                    elevation: 4, 
                    color: tileColor,
                    margin:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    child: ListTile(
                      leading: Icon(
                        Icons.place,
                        color: Colors.teal[800],
                      ),
                      title: Text(
                        rossOfMullPointInfo.name,
                        style: TextStyle(
                          color: Colors.teal[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          color: Colors.teal),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void onMapViewReady() async {
    initMap();
    final rossOfMullFionnphortPoint = RossOfMullPointsList.points
        .firstWhere((point) => point.name == "Fionnphort");
    // createLocationPoints(rossOfMullFionnphortPoint.point);
    setState(() => _ready = true);
  }

  void initMap() {
    final map = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISTopographic);

    map.initialViewpoint = Viewpoint.fromCenter(
      ArcGISPoint(
        x: 155233, // in BNG
        y: 734855,
        spatialReference: SpatialReference(wkid: 27700), // BNG
      ),
      scale: 700000,
    );
    _mapViewController.arcGISMap = map;
    _mapViewController.graphicsOverlays.add(_routeGraphicsOverlay);
    _mapViewController.graphicsOverlays.add(_stopsGraphicsOverlay);
    _mapViewController.graphicsOverlays.add(_meetingPointGraphicsOverlay);

    _stopsGraphicsOverlay.renderer = SimpleRenderer(
        symbol: SimpleMarkerSymbol(
            style: SimpleMarkerSymbolStyle.diamond,
            color: Colors.teal,
            size: 15.0));
  }

  void createLocationPoints(ArcGISPoint departurePoint) {
    if (_locationPoints.isEmpty) {
      // Craignure location always needed, ferry terminal
      final craignureLocation = RossOfMullPointsList.points
          .firstWhere((point) => point.name == "Craignure");
      _locationPoints.add(craignureLocation.point);
      // Departure point will vary based on user input
      _locationPoints.add(departurePoint);
      _stopsGraphicsOverlay.graphics.add(Graphic(geometry: departurePoint));
      _stopsGraphicsOverlay.graphics.add(Graphic(geometry: craignureLocation.point));
    } else {
      // Replace the second departure point and update its geometry
      _locationPoints[1] = departurePoint;
      _stopsGraphicsOverlay.graphics[0].geometry = departurePoint;
    }
  }

  Future<void> initRouteParameters() async {
    // Create default route parameters.

    if (_craignureTrafficStops.isEmpty) {
      _craignureTrafficStops.add(Stop(point: _locationPoints[0])); // adds Craignure
      _craignureTrafficStops.add(Stop(point: _locationPoints[1])); // adds Fionnphort
    } else {
      _craignureTrafficStops[1] =
        Stop(point: _locationPoints[1]); // change last stop to last point added by user
    }

    _craignureTrafficRouteParameters =
        await _routeTask.createDefaultParameters()
          ..setStops(_craignureTrafficStops)
          ..directionsDistanceUnits = UnitSystem.imperial;
  }

  void clearRouteAndMeetingPointGraphics() {
    _routeGraphicsOverlay.graphics.clear();
    _meetingPointGraphicsOverlay.graphics.clear();
  }

  Future<void> generateRoute() async {
    final routeLineSymbol = SimpleLineSymbol(
      style: SimpleLineSymbolStyle.dash,
      color: Colors.blue,
      width: 5.0,
    );

    await initRouteParameters();

    clearRouteAndMeetingPointGraphics();
    var routeResult = await _routeTask.solveRoute(
        routeParameters: _craignureTrafficRouteParameters);
    if (routeResult.routes.isEmpty) {
      if (mounted) {
        showAlertDialog('No routes have been generated.', title: 'Info');
      }
      return;
    }

    _route = routeResult.routes.first;
    _routeGeometry = _route.routeGeometry;

    if (_routeGeometry != null) {
      final craignureRouteGraphic =
          Graphic(geometry: _routeGeometry, symbol: routeLineSymbol);
      _routeGraphicsOverlay.graphics.add(craignureRouteGraphic);
      _isRouteGeometryInitializedNotifier.value = true;

    }
  }

  void _calculateMeetingPoint() {
    final projectedRoute = _projectPolyline(_routeGeometry);
    final projectedRouteLength = GeometryEngine.length(geometry: projectedRoute);

    var averageTrafficSpeeds = TrafficSpeed(50, 60); // 50 km/h bus speed, 60km/h car speed
    _calculateAndDisplayMeetingPoint(projectedRoute, projectedRouteLength,
        averageTrafficSpeeds, 'assets/bus.png');
  }

  List<double> calculateMeetingDistanceInKm(double carSpeed, double busSpeed, double distance) {
    List<double> listOfMeetingDistances = [];
    var ferryTimesInRange = _ferrySchedule.getFerryDeparturesInRange(_selectedTime);
    double toDouble(TimeOfDay timeOfDay) => timeOfDay.hour + timeOfDay.minute / 60.0;

    for (TimeOfDay ferryTime in ferryTimesInRange) {
      var carDelay = toDouble(ferryTime) - toDouble(_selectedTime);
      // Calculate meeting point based on distance, time delay, and vehicle speed
      var distanceToMeetKms = (distance - (carDelay * busSpeed)) / ((busSpeed / carSpeed) + 1);
      listOfMeetingDistances.add(distanceToMeetKms);
    }

    return listOfMeetingDistances;
  }

  void _calculateAndDisplayMeetingPoint(Polyline projectedRoute,
      double routeLength, TrafficSpeed speed, String pathToImage) {
    var routeLengthInKm = routeLength / 1000;

    var distancesToMeet = calculateMeetingDistanceInKm(
        speed.carSpeedFromFionnphort,
        speed.busSpeedFromCraignure,
        routeLengthInKm);

  if (distancesToMeet.isNotEmpty) {
  int validDistances = 0;  

  for (double distanceToMeetInKm in distancesToMeet) {
    if (distanceToMeetInKm <= routeLengthInKm && distanceToMeetInKm >= 0) {
      final fromCraignureByBus = GeometryEngine.createPointAlong(
          polyline: projectedRoute,
          distance: distanceToMeetInKm * 1000);
      _showRangeOfMeetingPointsOnMap(fromCraignureByBus, pathToImage);
      validDistances++;
    }
  }

  setState(() {
    if (validDistances == 1) {
      _infoMessage = const Text("You'll meet one set of ferry traffic!");
    } else if (validDistances > 1) {
      _infoMessage = Text("You'll meet $validDistances sets of ferry traffic!");
    } else {
      _infoMessage = const Text("You'll dodge the traffic between ferries!");
    }
    // Show the snackbar with the final message
    _showSnackbar(context, _infoMessage);
  });
  } else {
    setState(() {
      _infoMessage = const Text("No ferries!");
      _showSnackbar(context, _infoMessage);
    });
  }
}



  Polyline _projectPolyline(dynamic routeGeometry) {
    return GeometryEngine.project(routeGeometry as Polyline,
        outputSpatialReference: SpatialReference(wkid: 27700)) as Polyline; // British National Grid wkid
  }

  Future<void> _showRangeOfMeetingPointsOnMap(
      ArcGISPoint meetingPoint, String pathToImage) async {
    final image = await ArcGISImage.fromAsset(pathToImage);
    final pictureMarkerSymbol = PictureMarkerSymbol.withImage(image)
      ..height = 40
      ..width = 40;

    final meetingPointGraphic =
        Graphic(geometry: meetingPoint, symbol: pictureMarkerSymbol);

    _meetingPointGraphicsOverlay.graphics.add(meetingPointGraphic);

    final envelopeBuilder =
        EnvelopeBuilder.fromEnvelope(_meetingPointGraphicsOverlay.extent)
          ..expandBy(1.2);

    var viewpoint = Viewpoint.fromTargetExtent(envelopeBuilder.extent);
    _mapViewController.setViewpoint(viewpoint);
  }

  // Confirmation dialog after place is selected
  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return ValueListenableBuilder<bool>(
              valueListenable: _isRouteGeometryInitializedNotifier,
              builder: (context, isInitialized, _) {
                return AlertDialog(
                  title: const Text("Confirm your selections"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.more_time, color: Colors.teal),
                          const SizedBox(width: 10),
                          Text(
                            "Departing at: ${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.teal),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.place, color: Colors.teal),
                          const SizedBox(width: 10),
                          Text(
                            "From: ${_selectedPlace?.name}",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.teal),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: const Text("Cancel"),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the confirmation dialog
                      },
                    ),
                    TextButton(
                      onPressed: isInitialized
                          ? () {
                              _calculateMeetingPoint();
                              _isRouteGeometryInitializedNotifier.value = false;
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isInitialized ? Colors.teal : Colors.grey,
                      ),
                      child: Text(isInitialized ? "Confirm" : "Calculating..."),
                    ),
                  ],
                );
              });
        });
      },
    );
  }

  void _showSnackbar(BuildContext context, Text message) {
    final snackBar = SnackBar(
      content: message,
      duration: const Duration(seconds: 5),
      backgroundColor: Colors.teal,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

    Future<void> showAlertDialog(String message, {String title = 'Alert'}) {
    // Show an alert dialog.
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'OK'),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

}
