import 'package:arcgis_maps/arcgis_maps.dart';

class RossOfMullPointsData {
  final ArcGISPoint point;
  final String name;

  RossOfMullPointsData({
    required this.point,
    required this.name,
  });
}

class RossOfMullPointsList {
  // Create a list of key departure points along the Ross of Mull
  static final List<RossOfMullPointsData> points = [
    RossOfMullPointsData(
      point: ArcGISPoint(
        x: -635191.6737653657,
        y: 7652815.622445428,
        spatialReference: SpatialReference.webMercator,
      ),
      name: 'Craignure',
    ),
    RossOfMullPointsData(
      point: ArcGISPoint(
        x: -632887.821917,
        y: 7646107.109895,
        spatialReference: SpatialReference.webMercator,
      ),
      name: 'Lochdon',
    ),
    RossOfMullPointsData(
      point: ArcGISPoint(
        x: -640581.446280,
        y: 7640921.685158,
        spatialReference: SpatialReference.webMercator,
      ),
      name: 'Lochbuie Road',
    ),
    RossOfMullPointsData(
      point: ArcGISPoint(
        x: -665337.267212,
        y: 7636725.150479,
        spatialReference: SpatialReference.webMercator,
      ),
      name: 'B8035 Road End',
    ),
    RossOfMullPointsData(
      point: ArcGISPoint(
        x: -670161.580175,
        y: 7631329.995114,
        spatialReference: SpatialReference.webMercator,
      ),
      name: 'Pennyghael',
    ),
    RossOfMullPointsData(
      point: ArcGISPoint(
        x: -693945.411266,
        y: 7621802.500231,
        spatialReference: SpatialReference.webMercator,
      ),
      name: 'Bunessan',
    ),
    RossOfMullPointsData(
      point: ArcGISPoint(
        x: -708658.382205,
        y: 7623408.797508,
        spatialReference: SpatialReference.webMercator,
      ),
      name: 'Fionnphort',
    ),
  ];
}
