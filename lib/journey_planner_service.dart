import 'generated_code/journey_planner.swagger.dart' show JourneyPlanner, Format, NearbyTransitStop;
import 'transit.dart' show getClient;

Future<List<NearbyTransitStop>> nearbyStops(String apikey,
    Location location) async {
  // var res = await client.get(Uri.http(
  //     "au-journeyplanner.silverrailtech.com",
  //     "journeyplannerservice/v2/REST/Datasets/PerthRestricted/NearbyTransitStops",
  //     {
  //       "ApiKey": apikey,
  //       "format": "json",
  //       "GeoCoordinate": "${location.latitude},${location.longitude}"
  //     }));
  //
  // return errorOrResult<NearbyStopsResponse>(res, NearbyStopsResponse.fromJson)
  //     .transitStopPaths;
  JourneyPlanner client = getClient(
      JourneyPlanner.create,
      "http://au-journeyplanner.silverrailtech.com/journeyplannerservice/v2/REST",
      apikey
  );

  return (await client.dataSetsDatasetNearbyTransitStopsGet(
      dataset: 'PerthRestricted',
      format: Format.json,
      geoCoordinate: "${location.latitude},${location.longitude}")).body;
}

class Location {
  num latitude;
  num longitude;

  Location(this.latitude, this.longitude);
}
