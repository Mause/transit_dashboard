import requests
from datetime import datetime
from dateutil.parser import parse as _parse
from dateutil.tz import gettz
from humanize import naturaltime
from pprint import pprint

perth = gettz("Australia/Perth")

session = requests.Session()
session.params.update(
    {"format": "json", "ApiKey": "ad89905f-d5a7-487f-a876-db39092c6ee0"}
)


def parse(string: str) -> datetime:
    return _parse(string, tzinfos={None: perth})


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

    server_time = parse(r.headers["Date"])

    return (server_time, data["Trips"])


def main():
    server_time, trips = trips_for_stop("11706", datetime.now(tz=perth))

    trips = [trip for trip in trips if trip["Summary"]["RouteCode"] == "101"]
    print("current_time:", datetime.now(tz=perth))
    print("server_time:", server_time)

    pprint(trips[0])

    trip = trips[0]

    analyse_trip(server_time, trip)


def analyse_trip(server_time, trip):
    depart_time = parse(trip["DepartTime"])
    estimated_depart_time = parse(
        trip["RealTimeInfo"].get("EstimatedArrivalTime")
        or trip["RealTimeInfo"]["ActualArrivalTime"]
    )

    print(f"{depart_time=}")
    print(f"{estimated_depart_time=}")

    delta = estimated_depart_time - depart_time

    cm = delta.total_seconds()

    print("arriving in " + naturaltime(estimated_depart_time, when=server_time))

    if cm > 0:
        print(f"running {delta} late")
    elif cm < 0:
        print(f"running {delta} early")
    else:
        print("running on time")


if __name__ == "__main__":
    main()
