#!/usr/bin/env python3
"""JPL/ERFA independent references. Never imports or invokes our provider/engine.

One Horizons request at a time; raw replies are cached with exact parameters.
Routine Swift tests consume the resulting JSON offline.
"""
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import erfa
import numpy as np
from numpy.polynomial import Polynomial

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Packages/HypergateCore/Tests/HypergateCoreTests/Fixtures"
RAW = ROOT / "docs/reference-data"
OUT.mkdir(parents=True, exist_ok=True)
RAW.mkdir(parents=True, exist_ok=True)
BODIES = {"sun": 10, "moon": 301, "mercury": 199, "venus": 299, "mars": 499,
          "jupiter": 599, "saturn": 699, "uranus": 799, "neptune": 899, "pluto": 999}
GATES = json.loads((ROOT / "docs/accuracy-gates.json").read_text())


def jd(instant):
    return instant.timestamp() / 86400 + 2440587.5


def iso(julian):
    return datetime.fromtimestamp((float(julian) - 2440587.5) * 86400, timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def request(name, body, times=None, observer=False, span=False):
    if times is not None and len(times) > 32:
        return np.concatenate([request(f"{name}-part-{i // 32:03}", body, times[i:i + 32], observer)
                               for i in range(0, len(times), 32)])
    params = {"format": "json", "COMMAND": f"'{body}'", "OBJ_DATA": "'NO'", "CENTER": "'500@399'",
              "EPHEM_TYPE": "'OBSERVER'" if observer else "'VECTORS'", "TIME_TYPE": "'UT'",
              "REF_SYSTEM": "'ICRF'", "CSV_FORMAT": "'YES'", "CAL_FORMAT": "'JD'", "TIME_DIGITS": "'FRACSEC'"}
    if span:
        params.update(START_TIME="'2026-01-01 00:00'", STOP_TIME="'2027-03-01 00:00'", STEP_SIZE="'6h'")
    else:
        params.update(TLIST="'" + " ".join(f"{x:.10f}" for x in times) + "'", TLIST_TYPE="'JD'")
    if observer:
        params.update(QUANTITIES="'30'", APPARENT="'AIRLESS'")
    else:
        params.update(REF_PLANE="'FRAME'", VEC_CORR="'LT+S'", VEC_TABLE="'1'", OUT_UNITS="'AU-D'")
    path = RAW / (name + ".json")
    if path.exists():
        saved = json.loads(path.read_text())
        if saved["request"] != params:
            raise RuntimeError(f"Request changed for {name}; preserve the old reference and version the new fixture.")
        reply = saved["response"]
    else:
        url = "https://ssd.jpl.nasa.gov/api/horizons.api?" + urllib.parse.urlencode(params)
        with urllib.request.urlopen(url, timeout=90) as response:
            reply = json.load(response)
        if "error" in reply or "$$SOE" not in reply.get("result", ""):
            raise RuntimeError(f"Horizons failed {name}: {reply}")
        path.write_text(json.dumps({"request": params, "response": reply}, indent=2) + "\n")
    rows = []
    for row in csv.reader(io.StringIO(reply["result"].split("$$SOE")[1].split("$$EOE")[0])):
        numbers = []
        for cell in row:
            try:
                numbers.append(float(cell))
            except ValueError:
                pass
        if numbers:
            rows.append(numbers)
    array = np.asarray(rows)
    expected = 2 if observer else 4
    if array.ndim != 2 or array.shape[1] != expected:
        raise RuntimeError(f"Unexpected columns in {name}: {array.shape}")
    print(name, len(array), "rows", flush=True)
    return array


def longitude(vectors, offsets):
    dates = vectors[:, 0]
    # Horizons quantity 30 supplies TDB-UT. Remove the geocentric TDB-TT
    # periodic term independently with ERFA before performing date-frame rotation.
    delta = np.interp(dates, offsets[:, 0], offsets[:, 1])
    tdb_tt = erfa.dtdb(dates, np.zeros_like(dates), np.zeros_like(dates), 0.0, 0.0, 0.0)
    tt = dates + (delta - tdb_tt) / 86400
    rotation = erfa.pnm06a(tt, np.zeros_like(tt))
    eqd = np.einsum("nij,nj->ni", rotation, vectors[:, 1:4])
    _, deps = erfa.nut06a(tt, np.zeros_like(tt))
    eps = erfa.obl06(tt, np.zeros_like(tt)) + deps
    y = np.cos(eps) * eqd[:, 1] + np.sin(eps) * eqd[:, 2]
    return np.mod(np.degrees(np.arctan2(y, eqd[:, 0])), 360)


annual = [jd(datetime(year, month, 1, tzinfo=timezone.utc)) for year in range(2000, 2051) for month in [1, 7]]
annual += [jd(datetime(2026, 9, 8, 19, tzinfo=timezone.utc)), jd(datetime(2050, 12, 31, 23, 59, tzinfo=timezone.utc))]
annual.sort()
position_offsets = request("position-time-scales", 10, annual, observer=True)
reference_times = [{"at": iso(t), "ttMinusUTCSeconds": float(offset - erfa.dtdb(t, 0.0, 0.0, 0.0, 0.0, 0.0))}
                   for t, offset in position_offsets]
(OUT / "time-scales.json").write_text(json.dumps(reference_times, indent=2) + "\n")
position_fixtures = []
for body, code in BODIES.items():
    vectors = request("positions-" + body, code, annual)
    values = longitude(vectors, position_offsets)
    position_fixtures += [{"body": body, "at": iso(t), "longitude": float(value)} for t, value in zip(vectors[:, 0], values)]
(OUT / "positions.json").write_text(json.dumps(position_fixtures, indent=2) + "\n")

event_offsets = request("event-time-scales", 10, observer=True, span=True)
series = {}
dates = None
for body, code in BODIES.items():
    vectors = request("event-series-" + body, code, span=True)
    dates = vectors[:, 0]
    series[body] = np.degrees(np.unwrap(np.radians(longitude(vectors, event_offsets))))


def roots(values, kind, bodies, targets=None):
    found = []
    for i in range(4, len(dates) - 5):
        reference = dates[i]
        x = (dates[i - 4:i + 5] - reference) * 24
        y = values[i - 4:i + 5]
        p = Polynomial.fit(x, y, 7).convert()
        if targets is None:
            possibilities = [(p.deriv(), 0)]
        else:
            lo = min(y[3:6]); hi = max(y[3:6])
            possibilities = []
            for target in targets:
                for k in range(math.floor(lo / 360) - 1, math.ceil(hi / 360) + 2):
                    level = target + 360 * k
                    if lo - 1 <= level <= hi + 1:
                        possibilities.append((p - level, target))
        for equation, target in possibilities:
            for root in equation.roots():
                if abs(root.imag) > 1e-7 or not 0 <= root.real < 6:
                    continue
                h = float(root.real)
                instant = reference + h / 24
                rate = float(p.deriv()(h) * 24)
                actual_kind = kind
                if kind == "station":
                    actual_kind = "station_retrograde" if p.deriv(2)(h) < 0 else "station_direct"
                if kind == "ingress" and abs(rate) < 1e-8:
                    continue
                key = (actual_kind, tuple(bodies), target)
                if any(item["key"] == key and abs(item["jd"] - instant) * 86400 < 1 for item in found[-6:]):
                    continue
                found.append({"key": key, "kind": actual_kind, "bodies": bodies, "target": target,
                              "jd": instant, "rate": rate})
    return found


all_events = []
for body, values in series.items():
    all_events += roots(values, "ingress", [body], list(range(0, 360, 30)))
    if body not in ["sun", "moon"]:
        all_events += roots(values, "station", [body])
names = list(BODIES)
for i, a in enumerate(names):
    for b in names[i + 1:]:
        for kind, targets in [("square", [90, 270]), ("opposition", [180])]:
            all_events += roots(series[a] - series[b], kind, [a, b], targets)

# Representative fixtures span every body and every observed station direction.
# Aspect selection keeps fast lunar and slow non-lunar pairs, including retrograde passes.
selected = []
counts = {}
for event in sorted(all_events, key=lambda e: e["jd"]):
    grouping = (event["kind"], tuple(event["bodies"]))
    limit = 2 if event["kind"].startswith("station") else 1
    if counts.get(grouping, 0) >= limit:
        continue
    counts[grouping] = counts.get(grouping, 0) + 1
    selected.append(event)

# Fetch fresh high-density samples around each independently discovered root.
confirmation_times = {body: set() for body in BODIES}
for event in selected:
    step = 1 / 24 if event["kind"].startswith("station") else 1 / 96
    event["times"] = [event["jd"] + k * step for k in range(-4, 5)]
    for body in event["bodies"]:
        confirmation_times[body].update(event["times"])
confirmed = {}
for body, times in confirmation_times.items():
    times = sorted(times)
    parts = [request(f"confirm-{body}-{i // 80:03}", BODIES[body], times[i:i + 80]) for i in range(0, len(times), 80)]
    if parts:
        vectors = np.concatenate(parts)
        confirmed[body] = (vectors[:, 0], longitude(vectors, event_offsets))


def confirmed_series(body, times):
    axis, values = confirmed[body]
    indices = [int(np.argmin(abs(axis - t))) for t in times]
    if any(abs(axis[i] - t) * 86400 > 0.001 for i, t in zip(indices, times)):
        raise RuntimeError("Reference time mismatch")
    return np.degrees(np.unwrap(np.radians(values[indices])))


fixtures = []
for event in selected:
    times = event["times"]
    y = confirmed_series(event["bodies"][0], times)
    if len(event["bodies"]) == 2:
        y = y - confirmed_series(event["bodies"][1], times)
    x = (np.array(times) - event["jd"]) * 86400
    estimates = []
    for degree in [5, 7]:
        p = Polynomial.fit(x, y, degree).convert()
        if event["kind"].startswith("station"):
            equation = p.deriv()
        else:
            level = event["target"] + round((y[4] - event["target"]) / 360) * 360
            equation = p - level
        real = [float(r.real) for r in equation.roots() if abs(r.imag) < 1e-6 and abs(r.real) < abs(x[-1])]
        if not real:
            raise RuntimeError(f"Unable to refine independent root: {event}")
        estimates.append(min(real, key=abs))
    convergence = abs(estimates[0] - estimates[1])
    if convergence > GATES["referenceConvergenceSeconds"]:
        raise RuntimeError(f"Independent reference convergence failed ({convergence}s): {event['key']}")
    instant = event["jd"] + estimates[1] / 86400
    kind = event["kind"]
    gate = GATES["stationSeconds"] if kind.startswith("station") else GATES["moonIngressSeconds"] if kind == "ingress" and event["bodies"] == ["moon"] else GATES["fastCrossingSeconds"] if abs(event["rate"]) >= 1 else GATES["slowCrossingSeconds"]
    fixtures.append({"kind": kind, "bodies": event["bodies"], "at": iso(instant), "target": event["target"],
                     "localRateDegreesPerDay": event["rate"], "toleranceSeconds": gate, "referenceConvergenceSeconds": convergence})
(OUT / "events.json").write_text(json.dumps(fixtures, indent=2) + "\n")
manifest = {"source": "NASA/JPL Horizons DE441 geocentric LT+S vectors", "frame": "ICRF transformed independently with ERFA IAU 2006/2000A to true ecliptic/equinox of date",
            "time": "UTC; Horizons TDB-UT minus ERFA geocentric TDB-TT for frame epoch",
            "numpy": np.__version__, "pyerfa": erfa.__version__, "positionCount": len(position_fixtures), "eventCount": len(fixtures),
            "accuracyGatesSHA256": hashlib.sha256((ROOT / "docs/accuracy-gates.json").read_bytes()).hexdigest(),
            "rawFiles": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(RAW.glob("*.json")) if p.name != "manifest.json"}}
(RAW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("Finished:", len(position_fixtures), "independent positions;", len(fixtures), "independent events", flush=True)
