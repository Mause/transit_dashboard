import requests
from datetime import datetime
from dateutil.parser import parse
from dateutil.tz import gettz

perth = gettz("Australia/Perth")

session = requests.Session()
session.params.update(
    {"format": "json", "ApiKey": "ad89905f-d5a7-487f-a876-db39092c6ee0"}
)
r = session.get(
    "https://realtime.transperth.info/SJP/StopTimetableService.svc/DataSets/PerthRestricted/StopTimetable",
    params={
        "StopUID": "PerthRestricted:11706",
        "IsRealTimeChecked": "true",
        "ReturnNotes": "true",
        "Time": datetime.now().isoformat(),
    },
)

print(r)
from pprint import pprint

data = r.json()

server_time = parse(r.headers["Date"]).astimezone(perth)
print(server_time)

trips = [trip for trip in data["Trips"] if trip["Summary"]["RouteCode"] == "101"]

pprint(trips[0])

trip = trips[0]

depart_time = parse(trip['DepartTime']).astimezone(perth)
estimated_depart_time = parse(trip['RealTimeInfo']['EstimatedArrivalTime']).astimezone(perth)

print(depart_time)
print(estimated_depart_time)

delta = (estimated_depart_time - depart_time)

cm = delta.total_seconds()

till = estimated_depart_time - server_time

print(f'arriving in {till}')

if cm > 0:
    print(f'running {delta} late')
elif cm < 0:
    print(f'running {delta} early')
else:
    print('running on time')

