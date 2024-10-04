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
  Text infoMesssage = const Text("Pick departure time",
      style: TextStyle(fontWeight: FontWeight.normal));
  var stringTimeOfDay = "";

  // Create a list of stops.
  final _craignureTrafficStops = <Stop>[];
  var pointStops = <ArcGISPoint>[];

  // Define route parameters for the route.
  late RouteParameters _craignureTrafficRouteParameters;
  late Route route;
  FerrySchedule ferrySchedule = FerrySchedule();
  Polyline? routeGeometry;
  bool isRouteGeometryInitialized = false;
  bool isTimeChosen = false;
  // late final Polyline? fionnphortRouteGeometry;
  TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateTime.now());

  // A flag to indicate whether the route is generated.
  var _routeGenerated = false;

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
            // Create a column with buttons for generating the route and showing the directions.
            Container(
              color: const Color.fromARGB(255, 203, 222, 220),
              child: Column(
                children: [
                  SizedBox(
                    height: 550,
                    // Add a map view to the widget tree and set a controller.
                    child: ArcGISMapView(
                      controllerProvider: () => _mapViewController,
                      onMapViewReady: onMapViewReady,
                    ),
                  ),
                  const SizedBox(height: 10),
                  infoMesssage,

                  // Add the buttons to the column.
                  Flexible(
                    flex: 1,
                    child: Row(
                      // crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          child: const Row(
                            children: [
                              Icon(Icons.more_time,
                                  color: Color.fromARGB(255, 5, 130, 117)),
                              SizedBox(width: 1),
                              // Icon(Icons.time_to_leave),
                            ],
                          ),
                          onPressed: () async {
                            final TimeOfDay? timeofDay = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                              helpText: "Enter your departure time",
                              initialEntryMode: TimePickerEntryMode.inputOnly,
                            );
                            if (timeofDay != null) {
                              setState(() {
                                selectedTime = timeofDay;
                                isTimeChosen = true;
                                infoMesssage = Text(
                                    "You are departing: ${selectedTime.hour}:${selectedTime.minute}. Now select place of departure");
                              });
                            }
                            if (selectedTime == TimeOfDay.now()) {
                              setState(() {
                                isTimeChosen = true;
                                infoMesssage =
                                    const Text("You are departing: now");
                              });
                            }
                          },
                        ),
                        // Create a button to generate the route.
                        ElevatedButton(
                          child: const Row(
                            children: [
                              // const Icon(Icons.add_location),
                              SizedBox(width: 1),
                               Icon(Icons.route,
                                  color: Color.fromARGB(255, 5, 130, 117)),
                            ],
                          ),

                          onPressed: () => generateRoute(pointStops),
                          // child: const Text('Route'),
                        ),
                        ElevatedButton(
                          onPressed: !isTimeChosen
                              ? null
                              : () => _calculateMeetingPoint(),
                          child: const Row(
                            children: [
                              const Icon(Icons.waving_hand,
                                  color: Color.fromARGB(255, 5, 130, 117)),
                              SizedBox(width: 1),
                              const Icon(Icons.directions_bus_filled,
                                  color: Color.fromARGB(255, 5, 130, 117)),
                            ],
                          ),
                          // child: const Icon(Icons.waving_hand),
                          // child: const Text('Meeting Point'),
                        ),
                        ElevatedButton(
                          onPressed: !isTimeChosen ? null : () => resetRoute(),
                          child: const Icon(Icons.layers_clear,
                              color: Color.fromARGB(255, 5, 130, 117)),
                        ),
                        // Create a button to show the directions.
                      ],
                    ),
                  ),
                  const Text("Select place of departure:",
                      style: TextStyle(fontWeight: FontWeight.normal)),
                  // ),
                  Expanded(
                    flex: 2,
                    // Add the buttons to the column.
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, // Set the number of columns
                        childAspectRatio:
                            3.5, // Adjust the aspect ratio as needed
                      ),
                      itemCount: RossOfMullPointsList.points.length,
                      itemBuilder: (context, index) {
                        final rossOfMullPointInfo =
                            RossOfMullPointsList.points[index];
                        return GestureDetector(
                          onTap: () {
                            changeViewpointToTappedPoint(
                                rossOfMullPointInfo.point);
                            createRouteStops(rossOfMullPointInfo.point);
                          },
                          child: Card(
                            // Wrap the tile in a Card for better appearance
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                //     size: 18), // Adjust size as needed
                                const SizedBox(
                                    height: 1), // Space between icon and text
                                Text(
                                  rossOfMullPointInfo.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.normal),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
            // Display a progress indicator and prevent interaction until state is ready.
            Visibility(
              visible: !_ready,
              child: SizedBox.expand(
                child: Container(
                  color: Colors.white30,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void changeViewpointToTappedPoint(ArcGISPoint rossOfMullPoint) {
    _mapViewController.setViewpointCenter(rossOfMullPoint, scale: 5000);
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
      _craignureTrafficStops[1] = Stop(point: points[1]); // change last stop to last point added

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

    setState(() {
      _routeGenerated = false;
      infoMesssage = const Text("Select Time");
    });
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
    isRouteGeometryInitialized = true;

    if (routeGeometry != null) {
      final craignureRouteGraphic =
          Graphic(geometry: routeGeometry, symbol: routeLineSymbol);
      _craignureRouteGraphicsOverlay.graphics.add(craignureRouteGraphic);
    }

    setState(() {
      _routeGenerated = true;
    });
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
    _calculateAndDisplayMeetingPoint(
        projectedRoute, projectedRouteLength, averageTrafficSpeeds, 'assets/bus.png');

  }

  List<double> calculateMeetingDistanceInKm(
      double carSpeed, double busSpeed, double distance) {
    List<double> listOfMeetingDistances = [];
    var ferryTimesInRange =
        ferrySchedule.getFerryDeparturesInRange(selectedTime);

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
        speed.carSpeedFromFionnphort, speed.busSpeedFromCraignure, routeLengthInKm);

    if (distancesToMeet.isNotEmpty) {
  for (double distanceToMeetInKm in distancesToMeet) {
    if (distanceToMeetInKm <= routeLengthInKm && distanceToMeetInKm >= 0) {
    final fromCraignureByBus = GeometryEngine.createPointAlong(polyline: projectedRoute, distance: distanceToMeetInKm * 1000); // 12.7 
    _showRangeOfMeetingPointsOnMap(fromCraignureByBus, pathToImage);
    setState(() {
      if (distancesToMeet.length == 1) {
          infoMesssage = const Text("You'll meet one set of ferry traffic! ");
      } else if (distancesToMeet.length > 1) {
        infoMesssage =  Text("You'll meet ${distancesToMeet.length.toString()} sets of ferry traffic!");
      }
    });
    } else {
      setState(() {
                infoMesssage = const Text("You'll dodge the traffic between ferries!");
      });
    }
  }
} else {
setState((){
    infoMesssage = const Text("No ferries!");

});
}
  }

  Polyline _projectPolyline(dynamic routeGeometry) {
    return GeometryEngine.project(routeGeometry as Polyline,
        outputSpatialReference: SpatialReference(wkid: 27700)) as Polyline;
  }

  Future<void> _showRangeOfMeetingPointsOnMap(
      ArcGISPoint meetingPoint, String pathToImage) async {
    if (_meetingPointGraphicsOverlay.graphics.length == 2) {
      _meetingPointGraphicsOverlay.graphics.clear();
    }

    final image = await ArcGISImage.fromAsset(pathToImage);
    final pictureMarkerSymbol = PictureMarkerSymbol.withImage(image);
    pictureMarkerSymbol.height = 40;
    pictureMarkerSymbol.width = 40;

    final meetingPointGraphic =
        Graphic(geometry: meetingPoint, symbol: pictureMarkerSymbol);

    _meetingPointGraphicsOverlay.graphics.add(meetingPointGraphic);
    _mapViewController.setViewpointCenter(meetingPoint, scale: 10000);
  }
}
