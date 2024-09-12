import 'package:ferry_traffic_helper/route_data.dart';
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
  final _passingPlacesGraphicsOverlay = GraphicsOverlay();
  // Create a graphics overlay for the stops.
  final _departurePointsGraphicsOverlay = GraphicsOverlay();
  // Create a graphics overlay for the route.
  final _craignureRouteGraphicsOverlay = GraphicsOverlay();
  final _fionnphortRouteGraphicsOverlay = GraphicsOverlay();

  // Create a list of stops.
  final _carStops = <Stop>[];
  // Create a list of stops.
  final _craignureTrafficStops = <Stop>[];
  final _fionnphortTrafficStops = <Stop>[];

  // Define route parameters for the route.
  // late final RouteParameters _carRouteParameters;
  // Define route parameters for the route.
  late final RouteParameters _craignureTrafficRouteParameters;
  late final RouteParameters _fionnphortTrafficRouteParameters;
  late final Route fionnphortRoute;
  late final Route craignureRoute;
  late final Polyline? craignureRouteGeometry;
  late final Polyline? fionnphortRouteGeometry;

  // A flag to indicate whether the route is generated.
  var _routeGenerated = false;

  final _routeTask = RouteTask.withUrl(
    Uri.parse(
      "https://route-api.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World",
    ),
  );

  final double _bufferDistance = 100.0; // Buffer distance in meters

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Create a column with buttons for generating the route and showing the directions.
            Column(
              children: [
                Expanded(
                  // Add a map view to the widget tree and set a controller.
                  child: ArcGISMapView(
                    controllerProvider: () => _mapViewController,
                    onMapViewReady: onMapViewReady,
                  ),
                ),
                SizedBox(
                  height: 60,
                  // Add the buttons to the column.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Create a button to generate the route.
                      ElevatedButton(
                        onPressed:
                            _routeGenerated ? null : () => generateRoute(),
                        child: const Text('Route'),
                      ),
                      ElevatedButton(
                        onPressed: () => _calculateMeetingPoint(),
                        child: const Text('Meeting Point'),
                      ),
                      // Create a button to show the directions.
                    ],
                  ),
                ),
              ],
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

  void onMapViewReady() async {
    initMap();
    createFionnphortAndCraignureStops();
    await initRouteParameters();
    // Set the ready state variable to true to enable the sample UI.
    setState(() => _ready = true);
  }

  void initMap() {
    // Create a map with a topographic basemap style and an initial viewpoint.
    final map = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISTopographic);

    map.initialViewpoint = Viewpoint.fromCenter(
      ArcGISPoint(
        x: -635191.6737653657,
        y: 7652815.622445428,
        spatialReference: SpatialReference.webMercator,
      ),
      scale: 1e5,
    );
    // Set the map to the map view controller.
    _mapViewController.arcGISMap = map;
    // Add the graphics overlays to the map view.
    _mapViewController.graphicsOverlays.add(_craignureRouteGraphicsOverlay);
    _mapViewController.graphicsOverlays.add(_fionnphortRouteGraphicsOverlay);
    _mapViewController.graphicsOverlays.add(_departurePointsGraphicsOverlay);
  }

  void createFionnphortAndCraignureStops() {
    // Create symbols to use for the start and end stops of the route.
    final routeStartCircleSymbol = SimpleMarkerSymbol(
      style: SimpleMarkerSymbolStyle.square,
      color: const Color.fromARGB(255, 191, 103, 174),
      size: 15.0,
    );
    final routeEndCircleSymbol = SimpleMarkerSymbol(
      style: SimpleMarkerSymbolStyle.circle,
      color: Colors.blue,
      size: 15.0,
    );

    // Configure pre-defined start and end points for the route.
    // Craignure
    final craignurePoint = ArcGISPoint(
      x: -635191.6737653657,
      y: 7652815.622445428,
      spatialReference: SpatialReference.webMercator,
    );

    // Fionnphort
    final fionnphortPoint = ArcGISPoint(
      x: -708658.382205,
      y: 7623408.797508,
      spatialReference: SpatialReference.webMercator,
    );

    final craignureStop = Stop(point: craignurePoint)..name = 'Craignure';
    final fionnphortStop = Stop(point: fionnphortPoint)..name = 'Fionnphort';

    _craignureTrafficStops.add(craignureStop);
    _craignureTrafficStops.add(fionnphortStop);
    _fionnphortTrafficStops.add(fionnphortStop);
    _fionnphortTrafficStops.add(craignureStop);

    // Add the start and end points to the stops graphics overlay.
    _departurePointsGraphicsOverlay.graphics.addAll([
      Graphic(geometry: craignurePoint, symbol: routeStartCircleSymbol),
      Graphic(geometry: fionnphortPoint, symbol: routeEndCircleSymbol),
    ]);
  }

  Future<void> initRouteParameters() async {
    // Create default route parameters.
    _craignureTrafficRouteParameters =
        await _routeTask.createDefaultParameters()
          ..setStops(_craignureTrafficStops)
          ..returnDirections = true
          ..directionsDistanceUnits = UnitSystem.imperial
          ..returnRoutes = true
          ..startTime = DateTime.now()
          ..returnStops = true;

    _fionnphortTrafficRouteParameters =
        await _routeTask.createDefaultParameters()
          ..setStops(_fionnphortTrafficStops)
          ..returnDirections = true
          ..directionsDistanceUnits = UnitSystem.imperial
          ..returnRoutes = true
          ..startTime = DateTime.now()
          ..returnStops = true;
  }

  void resetRoute() {
    // Clear the route graphics overlay.
    _craignureRouteGraphicsOverlay.graphics.clear();
    _fionnphortRouteGraphicsOverlay.graphics.clear();

    setState(() {
      _routeGenerated = false;
    });
  }

  Future<void> generateRoute() async {
    // Create the symbol for the route line.
    final craignureRouteLineSymbol = SimpleLineSymbol(
      style: SimpleLineSymbolStyle.dash,
      color: Colors.blue,
      width: 5.0,
    );

    // final fionnphortRouteLineSymbol = SimpleLineSymbol(
    //   style: SimpleLineSymbolStyle.dashDot,
    //   color: const Color.fromARGB(255, 180, 106, 194),
    //   width: 5.0,
    // );

    //   final driveTimeTravelMode = _routeTask.getRouteTaskInfo().travelModes.firstWhere(
    //   (mode) => mode.name == "Driving Time",
    // );

    // for (var value in driveTimeTravelMode.attributeParameterValues) {
    //   print(value.parameterName + value.parameterValue.toString());
    // }

    // _craignureTrafficRouteParameters.travelMode = driveTimeTravelMode;

    // Reset the route.
    resetRoute();

    // Solve the route using the route parameters.
    final craignureRouteResult = await _routeTask.solveRoute(
        routeParameters: _craignureTrafficRouteParameters);
    if (craignureRouteResult.routes.isEmpty) {
      if (mounted) {
        showAlertDialog('No routes have been generated.', title: 'Info');
      }
      return;
    }

        // Get the first route.
    craignureRouteGeometry = craignureRouteResult.routes.first.routeGeometry;

        if (craignureRouteGeometry != null) {
      final craignureRouteGraphic = Graphic(
          geometry: craignureRouteGeometry, symbol: craignureRouteLineSymbol);
      _craignureRouteGraphicsOverlay.graphics.add(craignureRouteGraphic);
    }

    // final fionnphortRouteResult = await _routeTask.solveRoute(
    //     routeParameters: _fionnphortTrafficRouteParameters);
    // if (fionnphortRouteResult.routes.isEmpty) {
    //   if (mounted) {
    //     showAlertDialog('No routes have been generated.', title: 'Info');
    //   }
    //   return;
    // }


    // fionnphortRouteGeometry = fionnphortRouteResult.routes.first.routeGeometry;

    // Add the route to the route graphics overlay.


    // if (fionnphortRouteGeometry != null) {
    //   final fionnphortRouteGraphic = Graphic(
    //       geometry: fionnphortRouteGeometry, symbol: fionnphortRouteLineSymbol);
    //   _fionnphortRouteGraphicsOverlay.graphics.add(fionnphortRouteGraphic);
    // }

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
    final projectedCraignureLine = _projectPolyline(craignureRouteGeometry);
    // final projectedFionnphortLine = _projectPolyline(fionnphortRouteGeometry);
    final projectedCraignureLineLength =
        GeometryEngine.length(geometry: projectedCraignureLine);

    RouteData routeData = RouteData(
      projectedCraignureLine,
      // projectedFionnphortLine,
      projectedCraignureLineLength,
    );

    // Fastest speeds
    var fastestSpeed = TrafficSpeed(50, 60); // 50, 60
    _calculateAndDisplayMeetingPoint(
        routeData, fastestSpeed, SimpleMarkerSymbolStyle.circle);

    // Slowest speeds
    var slowestSpeed = TrafficSpeed(45, 55); // 45, 55
    _calculateAndDisplayMeetingPoint(
        routeData, slowestSpeed, SimpleMarkerSymbolStyle.triangle);
  }

  void _calculateAndDisplayMeetingPoint(RouteData routeData, TrafficSpeed speed,
      SimpleMarkerSymbolStyle markerSymbol) {
    final relativeSpeed =
        speed.busSpeedFromCraignure + speed.carSpeedFromFionnphort;
    final timeToMeet = routeData.lineLength / relativeSpeed;
    final distanceTravelledByBus = speed.busSpeedFromCraignure * timeToMeet;
    // final distanceTravelledByCar = speed.carSpeedFromFionnphort * timeToMeet; // don't need both to show meeting point on map

    final fromCraignureByBus = GeometryEngine.createPointAlong(
        polyline: routeData.craignureLine, distance: distanceTravelledByBus);
    final locationOfTraffic = GeometryEngine.project(fromCraignureByBus,
        outputSpatialReference: SpatialReference
            .webMercator); // calcualted from Craignure - same point would appear if using Fionnphort Data

    _showRangeOfMeetingPointsOnMap(locationOfTraffic as ArcGISPoint, markerSymbol);
  }

  Polyline _projectPolyline(dynamic routeGeometry) {
    return GeometryEngine.project(routeGeometry as Polyline,
        outputSpatialReference: SpatialReference.webMercator) as Polyline;
  }

  void _showRangeOfMeetingPointsOnMap(ArcGISPoint meetingPoint, SimpleMarkerSymbolStyle symbolstyle) {

    final meetingSymbol = SimpleMarkerSymbol(
      style: symbolstyle,
      color: const Color.fromARGB(255, 8, 135, 139),
      size: 20.0,
    );

    final graphicsOverlay = GraphicsOverlay();
    final meetingPointGraphic =
        Graphic(geometry: meetingPoint, symbol: meetingSymbol);

    graphicsOverlay.graphics.add(meetingPointGraphic);
    _mapViewController.graphicsOverlays.add(graphicsOverlay);
    _mapViewController.setViewpointCenter(meetingPoint, scale: 10000);
  }
}
