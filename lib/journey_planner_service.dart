import 'package:transit_dashboard/errors.dart' show errorOrResult;

import 'generated_code/journey_planner.swagger.dart'
    show JourneyPlanner, Format, NearbyTransitStop;
import 'transit.dart' show getClient, getNowAsString;

Future<List<NearbyTransitStop>> nearbyStops(
    String apikey, Location location) async {
  var client = getClient(
      JourneyPlanner.create,
      "http://au-journeyplanner.silverrailtech.com/journeyplannerservice/v2/REST",
      apikey);

  return errorOrResult(await client.dataSetsDatasetNearbyTransitStopsGet(
          dataset: 'PerthRestricted',
          format: Format.json,
          time: getNowAsString(),
          filterInactiveStops: true,
          timeBand: 30,
          geoCoordinate: "${location.latitude},${location.longitude}"))
      .transitStopPaths!;
}

class Location {
  num latitude;
  num longitude;

  Location(this.latitude, this.longitude);
}
