import 'dart:math';

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
  // A flag for when the map view is ready and controls can be used.
  var _ready = false;
  final _mapViewController = ArcGISMapView.createController();
  final _departurePointsGraphicsOverlay = GraphicsOverlay();
  final _craignureRouteGraphicsOverlay = GraphicsOverlay();
  final _meetingPointGraphicsOverlay = GraphicsOverlay();
  Text infoMessage = const Text("Pick departure time",
      style: TextStyle(fontWeight: FontWeight.normal));

  // Create a list of stops.
  final _craignureTrafficStops = <Stop>[];
  var pointStops = <ArcGISPoint>[];

  // Define route parameters for the route.
  late RouteParameters _craignureTrafficRouteParameters;
  late Route route;
  FerrySchedule ferrySchedule = FerrySchedule();
  Polyline? routeGeometry;
  // bool isRouteGeometryInitialized = false;
  ValueNotifier<bool> isRouteGeometryInitializedNotifier =
      ValueNotifier<bool>(false);

  bool isTimeChosen = false;
  RossOfMullPointsData? selectedPlace;
  TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateTime.now());

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
            // The map view should be constrained properly
            Positioned.fill(
              child: ArcGISMapView(
                controllerProvider: () => _mapViewController,
                onMapViewReady: onMapViewReady,
              ),
            ),

            // Floating buttons on top of the map
            Positioned(
              bottom: 50, // Distance from the bottom of the screen
              left: 50, // Distance from the left side
              right: 50, // Distance from the right side
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.white, // White background for contrast
                      foregroundColor: Colors.teal, // Icon/text color
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
                        initialTime: selectedTime,
                        helpText: "When are you leaving?",
                        initialEntryMode: TimePickerEntryMode.inputOnly,
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors
                                    .teal, // Header background color (selected)
                                onPrimary: Colors
                                    .white, // Header text color (selected time)
                                onSurface: Colors.teal[
                                    900]!, // Text color for unselected time
                              ),
                              timePickerTheme: TimePickerThemeData(
                                backgroundColor:
                                    Colors.teal[50], // Time picker background
                                hourMinuteTextColor: WidgetStateColor
                                    .resolveWith((states) => states
                                            .contains(WidgetState.selected)
                                        ? Colors
                                            .white // Selected time text color
                                        : Colors.teal[
                                            900]!), // Unselected time text color
                                dialHandColor:
                                    Colors.teal[600], // Dial hand color
                                dialBackgroundColor:
                                    Colors.teal[100], // Dial background color
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      Colors.teal[700], // Button text color
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (timeofDay != null) {
                        setState(() {
                          selectedTime = timeofDay;
                          isTimeChosen = true;
                          _showDestinationSelectionDialog(context);
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
                    onPressed: !isTimeChosen ? null : () => resetRoute(),
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

// Pop-up to select a destination
  void _showDestinationSelectionDialog(BuildContext context) {
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

                // Alternate background colors for items
                Color tileColor =
                    index % 2 == 0 ? Colors.teal[50]! : Colors.teal[100]!;

                return GestureDetector(
                  onTap: () {
                    changeViewpointToTappedPoint(rossOfMullPointInfo.point);
                    createRouteStops(rossOfMullPointInfo.point);
                    generateRoute(pointStops);
                    _showConfirmationDialog(context);

                    setState(() {
                      selectedPlace = rossOfMullPointInfo;
                    });
                  },
                  child: Card(
                    elevation: 4, // Add some elevation to give it depth
                    color: tileColor,
                    margin:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    child: ListTile(
                      leading: Icon(
                        Icons.place,
                        color: Colors.teal[800], // Teal icon
                      ),
                      title: Text(
                        rossOfMullPointInfo.name,
                        style: TextStyle(
                          color: Colors.teal[900], // Dark teal text color
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          color: Colors.teal), // Trailing icon
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

  // Confirmation dialog after place is selected
  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
          return ValueListenableBuilder<bool>(
            valueListenable: isRouteGeometryInitializedNotifier,
            builder: (context, isInitialized, _) {
              return AlertDialog(
                title: const Text("Confirm your selections"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Display selected time
                    Row(
                      children: [
                        const Icon(Icons.more_time, color: Colors.teal),
                        const SizedBox(width: 10),
                        Text(
                          "Departing at: ${selectedTime.hour}:${selectedTime.minute}",
                          style: const TextStyle(fontSize: 16, color: Colors.teal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
              
                    // Display selected place
                    Row(
                      children: [
                        const Icon(Icons.place, color: Colors.teal),
                        const SizedBox(width: 10),
                        Text(
                          "From: ${selectedPlace?.name}",
                          style: const TextStyle(fontSize: 16, color: Colors.teal),
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
                                  isRouteGeometryInitializedNotifier.value = false;

                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          }
                        : null,
                                  style: TextButton.styleFrom(
            // Optionally change the color while disabled
            foregroundColor: isInitialized ? Colors.teal : Colors.grey, // Confirm = teal, Calculating = grey
          ),
                    child: Text(isInitialized ? "Confirm" : "Calculating..."),
                  ),
                ],
              );
            }
          );
        });
      },
    );
  }

  void changeViewpointToTappedPoint(ArcGISPoint rossOfMullPoint) {
    _mapViewController.setViewpointCenter(rossOfMullPoint, scale: 50000);
  }

  void onMapViewReady() async {
    initMap();
    final rossOfMullFionnphortPoint = RossOfMullPointsList.points
        .firstWhere((point) => point.name == "Fionnphort");
    createRouteStops(rossOfMullFionnphortPoint.point);
    // await initRouteParameters();
    // await generateRoute();
    // Set the ready state variable to true to enable the sample UI.
    setState(() => _ready = true);
  }

  void initMap() {
    // Create a map with a topographic basemap style and an initial viewpoint.
    final map = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISTopographic);

    map.initialViewpoint = Viewpoint.fromCenter(
      ArcGISPoint(
        x: 171788, // in BNG
        // x: -635191.6737653657,
        y: 737141,
        // y: 7652815.622445428,
        spatialReference: SpatialReference(wkid: 27700), // BNG
      ),
      scale: 50000,
    );
    _mapViewController.arcGISMap = map;
    _mapViewController.graphicsOverlays.add(_craignureRouteGraphicsOverlay);
    _mapViewController.graphicsOverlays.add(_departurePointsGraphicsOverlay);
    _mapViewController.graphicsOverlays.add(_meetingPointGraphicsOverlay);

    _departurePointsGraphicsOverlay.renderer = SimpleRenderer(
        symbol: SimpleMarkerSymbol(
            style: SimpleMarkerSymbolStyle.cross,
            color: Colors.teal,
            size: 15.0));
  }

  void createRouteStops(ArcGISPoint departurePoint) {
    if (pointStops.isEmpty) {
      final craignureLocation = RossOfMullPointsList.points
          .firstWhere((point) => point.name == "Craignure");
      pointStops.add(craignureLocation.point);
      pointStops.add(departurePoint);
      _departurePointsGraphicsOverlay.graphics
          .add(Graphic(geometry: departurePoint));
      _departurePointsGraphicsOverlay.graphics
          .add(Graphic(geometry: craignureLocation.point));
    } else {
      pointStops[1] = departurePoint;
      _departurePointsGraphicsOverlay.graphics[0].geometry = departurePoint;
    }
  }

  Future<void> initRouteParameters(List<ArcGISPoint> points) async {
    // Create default route parameters.

    if (_craignureTrafficStops.isEmpty) {
      _craignureTrafficStops.add(Stop(point: points[0])); // adds Craignure
      _craignureTrafficStops.add(Stop(point: points[1])); // adds Fionnphort
    } else {
      _craignureTrafficStops[1] =
          Stop(point: points[1]); // change last stop to last point added
    }

    _craignureTrafficRouteParameters =
        await _routeTask.createDefaultParameters()
          ..setStops(_craignureTrafficStops)
          ..returnDirections = false
          ..directionsDistanceUnits = UnitSystem.imperial
          ..returnRoutes = true
          ..returnStops = true;
  }

  void resetRoute() {
    // Clear the route graphics overlay.
    _craignureRouteGraphicsOverlay.graphics.clear();
    _meetingPointGraphicsOverlay.graphics.clear();
  }

  Future<void> generateRoute(List<ArcGISPoint> stops) async {
    // Create the symbol for the route line.
    final routeLineSymbol = SimpleLineSymbol(
      style: SimpleLineSymbolStyle.dash,
      color: Colors.blue,
      width: 5.0,
    );

    _craignureRouteGraphicsOverlay.graphics.clear();

    await initRouteParameters(stops);

    // Reset the route.
    resetRoute();

    // Solve the route using the route parameters.
    var routeResult = await _routeTask.solveRoute(
        routeParameters: _craignureTrafficRouteParameters);
    if (routeResult.routes.isEmpty) {
      if (mounted) {
        showAlertDialog('No routes have been generated.', title: 'Info');
      }
      return;
    }

    // Get the first route.
    route = routeResult.routes.first;
    routeGeometry = route.routeGeometry;

    if (routeGeometry != null) {
      final craignureRouteGraphic =
          Graphic(geometry: routeGeometry, symbol: routeLineSymbol);
      _craignureRouteGraphicsOverlay.graphics.add(craignureRouteGraphic);

      // Update the ValueNotifier to true, notifying all listeners
      isRouteGeometryInitializedNotifier.value = true;

      //     setState(() {
      //     isRouteGeometryInitialized = true;

      // });
    }
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

  void _calculateMeetingPoint() {
    final projectedRoute = _projectPolyline(routeGeometry);
    final projectedRouteLength =
        GeometryEngine.length(geometry: projectedRoute);

    // Fastest speeds
    var averageTrafficSpeeds = TrafficSpeed(50, 60); // 50, 60
    _calculateAndDisplayMeetingPoint(projectedRoute, projectedRouteLength,
        averageTrafficSpeeds, 'assets/bus.png');
  }

  List<double> calculateMeetingDistanceInKm(
      double carSpeed, double busSpeed, double distance) {
    List<double> listOfMeetingDistances = [];
    var ferryTimesInRange =
        ferrySchedule.getFerryDeparturesInRange(selectedTime);
    print(ferryTimesInRange.length);
    for (TimeOfDay ferryTime in ferryTimesInRange) {
      print(ferryTime);
    }

    double toDouble(TimeOfDay myTime) => myTime.hour + myTime.minute / 60.0;

    for (TimeOfDay ferryTime in ferryTimesInRange) {
      var carDelay = toDouble(ferryTime) - toDouble(selectedTime);
      var meetingInKms =
          (distance - (carDelay * busSpeed)) / ((busSpeed / carSpeed) + 1);

      listOfMeetingDistances.add(meetingInKms);
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
      for (double distanceToMeetInKm in distancesToMeet) {
        if (distanceToMeetInKm <= routeLengthInKm && distanceToMeetInKm >= 0) {
          final fromCraignureByBus = GeometryEngine.createPointAlong(
              polyline: projectedRoute,
              distance: distanceToMeetInKm * 1000); // 12.7
          _showRangeOfMeetingPointsOnMap(fromCraignureByBus, pathToImage);

          setState(() {
            if (distancesToMeet.length == 1) {
              infoMessage =
                  const Text("You'll meet one set of ferry traffic! ");
            } else if (distancesToMeet.length > 1) {
              infoMessage = Text(
                  "You'll meet ${distancesToMeet.length.toString()} sets of ferry traffic!");
            }
          });
        } else {
          setState(() {
            infoMessage =
                const Text("You'll dodge the traffic between ferries!");
            // _showSnackbar(context, infoMesssage);
          });
        }
      }
      _showSnackbar(context, infoMessage);
    } else {
      setState(() {
        infoMessage = const Text("No ferries!");
        _showSnackbar(context, infoMessage);
      });
    }
  }

  void _showSnackbar(BuildContext context, Text message) {
    final snackBar = SnackBar(
      content: message,
      duration: const Duration(seconds: 3), // You can adjust the display time
      backgroundColor: Colors.teal,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Polyline _projectPolyline(dynamic routeGeometry) {
    return GeometryEngine.project(routeGeometry as Polyline,
        outputSpatialReference: SpatialReference(wkid: 27700)) as Polyline;
  }

  Future<void> _showRangeOfMeetingPointsOnMap(
      ArcGISPoint meetingPoint, String pathToImage) async {
    final image = await ArcGISImage.fromAsset(pathToImage);
    final pictureMarkerSymbol = PictureMarkerSymbol.withImage(image);
    pictureMarkerSymbol.height = 40;
    pictureMarkerSymbol.width = 40;

    final meetingPointGraphic =
        Graphic(geometry: meetingPoint, symbol: pictureMarkerSymbol);

    _meetingPointGraphicsOverlay.graphics.add(meetingPointGraphic);

    final envelopeBuilder =
        EnvelopeBuilder.fromEnvelope(_meetingPointGraphicsOverlay.extent)
          ..expandBy(1.2);

    var viewpoint = Viewpoint.fromTargetExtent(envelopeBuilder.extent);
    _mapViewController.setViewpoint(viewpoint);
    print("graphics overlay: ${_meetingPointGraphicsOverlay.graphics.length}");
    // _mapViewController.setViewpointGeometry(_meetingPointGraphicsOverlay.extent)
    // _mapViewController.setViewpointCenter(meetingPoint, scale: 50000);
  }
}
