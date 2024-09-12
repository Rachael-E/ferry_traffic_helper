import 'package:arcgis_maps/arcgis_maps.dart'; // Import your ArcGIS package

class RossOfMullPointsData {
  final double x; // Changed to double to match the original point definition
  final double y; // Changed to double to match the original point definition
  final SpatialReference spatialReference;
  final String name;

  RossOfMullPointsData({
    required this.x,
    required this.y,
    required this.spatialReference,
    required this.name,
  });
}

class RossOfMullPointsList {
  // Create a list of RossOfMullPointsData
  static final List<RossOfMullPointsData> points = [
    RossOfMullPointsData(
      x: -635191.6737653657,
      y: 7652815.622445428,
      spatialReference: SpatialReference.webMercator,
      name: 'Craignure',
    ),
    RossOfMullPointsData(
      x: -632887.821917,
      y: 7646107.109895,
      spatialReference: SpatialReference.webMercator,
      name: 'Lochdon',
    ),
    RossOfMullPointsData(
      x: -640571.110206,
      y: 7640914.033991,
      spatialReference: SpatialReference.webMercator,
      name: 'Lochbuie Road',
    ),
    RossOfMullPointsData(
      x: -665337.267212,
      y: 7636725.150479,
      spatialReference: SpatialReference.webMercator,
      name: 'B8035 Road',
    ),
    RossOfMullPointsData(
      x: -670161.580175,
      y: 7631329.995114,
      spatialReference: SpatialReference.webMercator,
      name: 'Pennyghael',
    ),
    RossOfMullPointsData(
      x: -693945.411266,
      y: 7621802.500231,
      spatialReference: SpatialReference.webMercator,
      name: 'Bunessan',
    ),
    RossOfMullPointsData(
      x: -708658.382205,
      y: 7623408.797508,
      spatialReference: SpatialReference.webMercator,
      name: 'Fionnphort',
    ),
  ];
}
