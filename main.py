import requests
from datetime import datetime
from dateutil.parser import parse
from dateutil.tz import gettz
from humanize import naturaltime
from pprint import pprint

perth = gettz("Australia/Perth")

session = requests.Session()
session.params.update(
    {"format": "json", "ApiKey": "ad89905f-d5a7-487f-a876-db39092c6ee0"}
)


def trips_for_stop(stop_uid: str, time: datetime):
    r = session.get(
        "https://realtime.transperth.info/SJP/StopTimetableService.svc/DataSets/PerthRestricted/StopTimetable",
        params={
            "StopUID": "PerthRestricted:11706",
            "IsRealTimeChecked": "true",
            "ReturnNotes": "true",
            "Time": time.isoformat(),
        },
    )

    data = r.json()

    server_time = parse(r.headers["Date"]).astimezone(perth)

    return (server_time, data["Trips"])


def main():
    server_time, trips = trips_for_stop("11706", datetime.now())

    trips = [trip for trip in trips if trip["Summary"]["RouteCode"] == "101"]
    print("current_time:", datetime.now())
    print("server_time:", server_time)

    pprint(trips[0])

    trip = trips[0]

    analyse_trip(server_time, trip)


def analyse_trip(server_time, trip):
    depart_time = parse(trip["DepartTime"]).astimezone(perth)
    estimated_depart_time = parse(
        trip["RealTimeInfo"].get("EstimatedArrivalTime")
        or trip["RealTimeInfo"]["ActualArrivalTime"]
    ).astimezone(perth)

    print(depart_time)
    print(estimated_depart_time)

    delta = estimated_depart_time - depart_time

    cm = delta.total_seconds()

    till = estimated_depart_time - server_time

    print(f"arriving in {naturaltime(-till)}")

    if cm > 0:
        print(f"running {delta} late")
    elif cm < 0:
        print(f"running {delta} early")
    else:
        print("running on time")


if __name__ == "__main__":
    main()
