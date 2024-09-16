import 'package:ferry_traffic_helper/ross_of_mull_points.dart';
import 'package:ferry_traffic_helper/route_data.dart';
import 'package:ferry_traffic_helper/traffic_speed.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/rendering.dart';

class FerryTrafficScreen extends StatefulWidget {
  const FerryTrafficScreen({super.key});

  @override
  State<FerryTrafficScreen> createState() => _FerryTrafficScreenState();
}

class _FerryTrafficScreenState extends State<FerryTrafficScreen> {
  // A flag for when the map view is ready and controls can be used.
  var _ready = false;
  final _mapViewController = ArcGISMapView.createController();
  // final _rossOfMullPointsGraphicsOverlay = GraphicsOverlay();
  // Create a graphics overlay for the stops.
  final _departurePointsGraphicsOverlay = GraphicsOverlay();
  // Create a graphics overlay for the route.
  final _craignureRouteGraphicsOverlay = GraphicsOverlay();
  // final _fionnphortRouteGraphicsOverlay = GraphicsOverlay();
  final _meetingPointGraphicsOverlay = GraphicsOverlay();
  Text infoMesssage = const Text("Select your departure time");
  var stringTimeOfDay = "";

  // Create a list of stops.

  // Create a list of stops.
  var _craignureTrafficStops = <Stop>[];
  var pointStops = <ArcGISPoint>[];
  // final _fionnphortTrafficStops = <Stop>[];

  // Define route parameters for the route.
  // late final RouteParameters _carRouteParameters;
  // Define route parameters for the route.
  late RouteParameters _craignureTrafficRouteParameters;
  // late final Route fionnphortRoute;
  // late final Route craignureRoute;
  Polyline? craignureRouteGeometry;
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
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Create a column with buttons for generating the route and showing the directions.
            Column(
              children: [
                SizedBox(
                  height: 600,
                  // Add a map view to the widget tree and set a controller.
                  child: ArcGISMapView(
                    controllerProvider: () => _mapViewController,
                    onMapViewReady: onMapViewReady,
                  ),
                ),
                // Container(
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
                            Icon(Icons.time_to_leave),
                            SizedBox(width: 5),
                            Icon(Icons.access_time_rounded, color: Colors.black),
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
                              // stringTimeOfDay = localizations.formatTimeOfDay(timeofDay, alwaysUse24HourFormat: true);
                              stringTimeOfDay = timeofDay.format(context);
                              isTimeChosen = true;
                              infoMesssage = Text(
                                  "You are departing: ${selectedTime.hour}:${selectedTime.minute}");
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
                        onPressed:
                            () => generateRoute(stringTimeOfDay, pointStops),
                        child: const Text('Route'),
                      ),
                      ElevatedButton(
                        onPressed: !isTimeChosen
                            ? null
                            : () => _calculateMeetingPoint(),
                        child: const Text('Meeting Point'),
                      ),
                      ElevatedButton(
                        onPressed: !isTimeChosen ? null : () => resetRoute(),
                        child: const Text('Reset'),
                      ),
                      // Create a button to show the directions.
                    ],
                  ),
                ),
                const Text("Oi oi"),
                // ),
                Expanded(
                  flex: 2,
                  // Add the buttons to the column.
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // Set the number of columns
                      childAspectRatio:
                          2.5, // Adjust the aspect ratio as needed
                    ),
                    itemCount: RossOfMullPointsList.points.length,
                    itemBuilder: (context, index) {
                      final rossOfMullPointInfo =
                          RossOfMullPointsList.points[index];
                      return GestureDetector(
                        onTap: () {
                          changeViewpointToTappedPoint(rossOfMullPointInfo.point);
                          showRouteToCraignure(rossOfMullPointInfo.point);
                          // createTemporaryPolylineFromDeparturePoint(rossOfMullPointInfo.point);
                          createRouteStops(rossOfMullPointInfo.point);
                        },
                        child: Card(
                          // Wrap the tile in a Card for better appearance
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // const Icon(Icons.location_on,
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

                  // child: ListView.builder(
                  //   itemCount: RossOfMullPointsList.points.length,
                  //   itemBuilder: (context, index) {
                  //     final point = RossOfMullPointsList.points[index];
                  //     return ListTile(
                  //       leading: Icon(Icons.location_on),
                  //       title: Text(point.name),
                  //       onTap: () {
                  //         _rossOfMullPointsGraphicsOverlay.graphics.clear();
                  //         var arcGISPoint = ArcGISPoint(x: point.x, y: point.y, spatialReference: point.spatialReference);
                  //         _mapViewController.setViewpointCenter(arcGISPoint);
                  //         _rossOfMullPointsGraphicsOverlay.graphics.add(
                  //           Graphic(
                  //             geometry: arcGISPoint,
                  //             symbol: SimpleMarkerSymbol(style: SimpleMarkerSymbolStyle.cross, color: Colors.red, size: 10),
                  //             ));
                  //         print('Selected Point: ${point.x}, ${point.y}');
                  //       },
                  //     );
                  //   },
                  // ),
                )
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

  void showRouteToCraignure(ArcGISPoint point) {

  

  }

  // void createTemporaryPolylineFromDeparturePoint(ArcGISPoint point) {

  //   _temporaryRouteGraphicsOverlay.graphics.clear();

  //   var departurePoint = point;
  //   var extenderPoint1 = ArcGISPoint(
  //     x: departurePoint.x + 100, 
  //     y: departurePoint.y + 100, 
  //     spatialReference: SpatialReference.webMercator);
  //   var extenderPoint2 = ArcGISPoint(
  //     x: departurePoint.x - 100, 
  //     y: departurePoint.y - 100, 
  //     spatialReference: SpatialReference.webMercator);
  //     print("Point: ${(point.x, point.y)}");
  //     print("Point: ${(extenderPoint1.x, extenderPoint1.y)}");
  //     print("Point: ${(extenderPoint2.x, extenderPoint2.y)}");

  //     var pointBuffer = GeometryEngine.buffer(geometry: departurePoint, distance: 50);
  //     var projectedPointBuffer = GeometryEngine.project(pointBuffer, outputSpatialReference: SpatialReference.webMercator);
  //     var intersectionPoints = GeometryEngine.intersection(geometry1: projectedPointBuffer, geometry2: _projectPolyline(craignureRouteGeometry));



  //   var polylineBuilder = PolylineBuilder.fromSpatialReference(SpatialReference.webMercator);
  //   polylineBuilder.addPoint(departurePoint);
  //   polylineBuilder.addPoint(extenderPoint1);
  //   polylineBuilder.addPoint(extenderPoint2);

  //   var polylineToUseAsCut = polylineBuilder.toGeometry() as Polyline;

  //   final temporaryLeftRouteLineSymbol = SimpleLineSymbol(
  //     style: SimpleLineSymbolStyle.dot,
  //     color: Colors.amber,
  //     width: 5.0,
  //   );

  //       final temporaryRightRouteLineSymbol = SimpleLineSymbol(
  //     style: SimpleLineSymbolStyle.dot,
  //     color: Colors.pink,
  //     width: 5.0,
  //   );

  //     final buffSymbol = SimpleFillSymbol(
  //     style: SimpleFillSymbolStyle.backwardDiagonal,
  //     color: Colors.pink,
  //   );

  //   var temporaryPolyline = GeometryEngine.cut(geometry: _projectPolyline(craignureRouteGeometry), cutter: polylineToUseAsCut);
  //   // final firstProjectedTemporaryPolyline = GeometryEngine.project(temporaryPolyline.first,
  //   //     outputSpatialReference: SpatialReference.webMercator); 
  //   // final secondProjectedTemporaryPolyline = GeometryEngine.project(temporaryPolyline[1],
  //   //     outputSpatialReference: SpatialReference.webMercator); 

  //             final lineCuttingGraphic = Graphic(
  //     geometry: polylineToUseAsCut, symbol: temporaryRightRouteLineSymbol);
  //     _temporaryRouteGraphicsOverlay.graphics.add(lineCuttingGraphic);

  //                   final bufferGraphic = Graphic(
  //     geometry: pointBuffer, symbol: buffSymbol);
  //     _temporaryRouteGraphicsOverlay.graphics.add(bufferGraphic);

  //   final leftRouteGraphic = Graphic(
  //     geometry: temporaryPolyline.first, symbol: temporaryLeftRouteLineSymbol);
  //     _temporaryRouteGraphicsOverlay.graphics.add(leftRouteGraphic);
  //     print("Temp ${temporaryPolyline.length}");

  //   final rightRouteGraphic = Graphic(
  //     geometry: temporaryPolyline[1], symbol: temporaryRightRouteLineSymbol);
  //     _temporaryRouteGraphicsOverlay.graphics.add(rightRouteGraphic);





  // }

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
    // _mapViewController.graphicsOverlays.add(_fionnphortRouteGraphicsOverlay);
    _mapViewController.graphicsOverlays.add(_departurePointsGraphicsOverlay);
    // _mapViewController.graphicsOverlays.add(_rossOfMullPointsGraphicsOverlay);
    _mapViewController.graphicsOverlays.add(_meetingPointGraphicsOverlay);

    _departurePointsGraphicsOverlay.renderer = SimpleRenderer(symbol: SimpleMarkerSymbol(
      style: SimpleMarkerSymbolStyle.cross, 
      color: Colors.teal, 
      size: 15.0)
      );
   
  }

  void createRouteStops(ArcGISPoint startPoint) {

        // Create symbols to use for the start and end stops of the route.
    // final routeStartCircleSymbol = SimpleMarkerSymbol(
    //   style: SimpleMarkerSymbolStyle.square,
    //   color: const Color.fromARGB(255, 191, 103, 174),
    //   size: 15.0,
    // );
    // final routeEndCircleSymbol = SimpleMarkerSymbol(
    //   style: SimpleMarkerSymbolStyle.circle,
    //   color: Colors.blue,
    //   size: 15.0,
    // );
    
    if (pointStops.isEmpty) {

    final craignurePoint = RossOfMullPointsList.points
      .firstWhere((point) => point.name == "Craignure");
      pointStops.add(startPoint);
      pointStops.add(craignurePoint.point);
      _departurePointsGraphicsOverlay.graphics.add(Graphic(geometry: startPoint));
      _departurePointsGraphicsOverlay.graphics.add(Graphic(geometry: craignurePoint.point));

    } else {
      pointStops[0] = startPoint;
      _departurePointsGraphicsOverlay.graphics[0].geometry = startPoint;

    }

    print("Number of stops =  ${pointStops.length}");


    // for (var locationPoints in RossOfMullPointsList.points) {

      // var stop = Stop(point: locationPoints.point)..name = locationPoints.name;
      // _craignureTrafficStops.add(stop);
      // _departurePointsGraphicsOverlay.graphics.add(
      //   Graphic(
      //     geometry: locationPoints.point, 
      //     symbol:routeEndCircleSymbol 
      //     )
      //   );
    // }
    // Configure pre-defined start and end points for the route.
    // Craignure
    // final rossOfMullCraignurePoint = RossOfMullPointsList.points
    //     .firstWhere((point) => point.name == "Craignure");
    // final craignurePoint = rossOfMullCraignurePoint.point;

    // // Fionnphort
    // final rossOfMullFionnphortPoint = RossOfMullPointsList.points
    //     .firstWhere((point) => point.name == "Fionnphort");
    // final fionnphortPoint = rossOfMullFionnphortPoint.point;

    // final craignureStop = Stop(point: craignurePoint)..name = 'Craignure';
    // final fionnphortStop = Stop(point: fionnphortPoint)..name = 'Fionnphort';

    // _craignureTrafficStops.add(craignureStop);
    // _craignureTrafficStops.add(fionnphortStop);
    // // _fionnphortTrafficStops.add(fionnphortStop);
    // // _fionnphortTrafficStops.add(craignureStop);

    // // Add the start and end points to the stops graphics overlay.
    // _departurePointsGraphicsOverlay.graphics.addAll([
    //   Graphic(geometry: craignurePoint, symbol: routeStartCircleSymbol),
    //   Graphic(geometry: fionnphortPoint, symbol: routeEndCircleSymbol),
    // ]);
  }

  Future<void> initRouteParameters(String time, List<ArcGISPoint> points) async {

      // Assume time is in the format "HH:mm"
  final currentDate = DateTime.now();
  final timeParts = time.split(':');
  final parsedDateTime = DateTime(
    currentDate.year,
    currentDate.month,
    currentDate.day,
    int.parse(timeParts[0]),  // Hours
    int.parse(timeParts[1]),  // Minutes
  );
    print("Parsed time + $parsedDateTime");
    // Create default route parameters.

    if (_craignureTrafficStops.isEmpty) {
      _craignureTrafficStops.add(Stop(point: points[0]));
      _craignureTrafficStops.add(Stop(point: points[1]));
    } else {
      _craignureTrafficStops[0] = Stop(point: points[0]);
    }
    // _craignureTrafficStops.clear;
    // for (var point in points) {
    //   _craignureTrafficStops.add(
    //     Stop(point: point)
    //     );
    //     }

  _craignureTrafficRouteParameters =
      await _routeTask.createDefaultParameters()
        ..setStops(_craignureTrafficStops)
        // ..setStops(_craignureTrafficStops)
        ..returnDirections = true
        ..directionsDistanceUnits = UnitSystem.imperial
        ..returnRoutes = true
        ..startTime = parsedDateTime
        ..returnStops = true;

  }

  void resetRoute() {
    // Clear the route graphics overlay.
    _craignureRouteGraphicsOverlay.graphics.clear();
    print(_craignureRouteGraphicsOverlay.graphics.length);
    // _fionnphortRouteGraphicsOverlay.graphics.clear();

    setState(() {
      _routeGenerated = false;
    });
  }

  Future<void> generateRoute(String time, List<ArcGISPoint> stops) async {
    // Create the symbol for the route line.
    final craignureRouteLineSymbol = SimpleLineSymbol(
      style: SimpleLineSymbolStyle.dash,
      color: Colors.blue,
      width: 5.0,
    );

    _craignureRouteGraphicsOverlay.graphics.clear();

    await initRouteParameters(time, stops);

          // Reset the route.
    resetRoute();

    // Solve the route using the route parameters.
    var craignureRouteResult = await _routeTask.solveRoute(
        routeParameters: _craignureTrafficRouteParameters);
    if (craignureRouteResult.routes.isEmpty) {
      if (mounted) {
        showAlertDialog('No routes have been generated.', title: 'Info');
      }
      return;
    }

    // Get the first route.
    // if (!isRouteGeometryInitialized) {
      craignureRouteGeometry = craignureRouteResult.routes.first.routeGeometry;
      print(craignureRouteGeometry?.parts.size);
      isRouteGeometryInitialized = true;
    // }

    if (craignureRouteGeometry != null) {
      final craignureRouteGraphic = Graphic(
          geometry: craignureRouteGeometry, symbol: craignureRouteLineSymbol);
          print('Time: ${craignureRouteResult.routes.first.totalTime}');
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

    _showRangeOfMeetingPointsOnMap(
        locationOfTraffic as ArcGISPoint, markerSymbol);
  }

  Polyline _projectPolyline(dynamic routeGeometry) {
    return GeometryEngine.project(routeGeometry as Polyline,
        outputSpatialReference: SpatialReference.webMercator) as Polyline;
  }

  void _showRangeOfMeetingPointsOnMap(
    ArcGISPoint meetingPoint, SimpleMarkerSymbolStyle symbolstyle) {

      if (_meetingPointGraphicsOverlay.graphics.length > 2) {
  _meetingPointGraphicsOverlay.graphics.clear();
}
    final meetingSymbol = SimpleMarkerSymbol(
      style: symbolstyle,
      color: const Color.fromARGB(255, 8, 135, 139),
      size: 20.0,
    );

    // final graphicsOverlay = GraphicsOverlay();
    final meetingPointGraphic =
        Graphic(geometry: meetingPoint, symbol: meetingSymbol);

    _meetingPointGraphicsOverlay.graphics.add(meetingPointGraphic);
    // _mapViewController.graphicsOverlays.add(graphicsOverlay);
    _mapViewController.setViewpointCenter(meetingPoint, scale: 10000);
  }
}
