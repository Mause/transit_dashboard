import 'package:transit_dashboard/errors.dart' show errorOrResult;

import 'generated_code/journey_planner.swagger.dart'
    show JourneyPlanner, Format, NearbyTransitStop;
import 'transit.dart' show dataset, getClient, getNowAsString;

Future<List<NearbyTransitStop>> nearbyStops(Location location) async {
  var client = getJourneyPlannerService();

  return errorOrResult(await client.dataSetsDatasetNearbyTransitStopsGet(
          dataset: dataset,
          format: Format.json,
          time: getNowAsString(),
          filterInactiveStops: true,
          timeBand: 30,
          geoCoordinate: "${location.latitude},${location.longitude}"))
      .transitStopPaths!;
}

JourneyPlanner getJourneyPlannerService() {
  return getClient(
      JourneyPlanner.create,
      "http://au-journeyplanner.silverrailtech.com/journeyplannerservice/v2/REST",
      'eac7a147-0831-4fcf-8fa8-a5e8ffcfa039');
}

class Location {
  num latitude;
  num longitude;

  Location(this.latitude, this.longitude);
}
