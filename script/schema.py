#!/usr/bin/env python3
"""Emit and validate the deliberately small JSON Schema v1 vocabulary used here."""
import json
import math
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
bodies = ['sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune', 'pluto']
kinds = ['ingress', 'square', 'opposition', 'station_retrograde', 'station_direct', 'conjunction', 'semisquare', 'sesquiquadrate']
date = {'type': 'string', 'pattern': r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$'}
number = {'type': 'number'}
body_list = {'type': 'array', 'minItems': 1, 'uniqueItems': True, 'items': {'enum': bodies}}

def object_schema(properties, optional=()):
    return {'type': 'object', 'additionalProperties': False, 'required': [key for key in properties if key not in optional], 'properties': properties}

provider = object_schema({'name': {'type': 'string'}, 'revision': {'type': 'string'}, 'convention': {'type': 'string'}, 'earliest': date, 'latestExclusive': date})
event = object_schema({'id': {'type': 'string'}, 'instant': date, 'kind': {'enum': kinds}, 'bodies': body_list,
                       'longitude': number, 'aspectAngle': number, 'previousSign': {'type': 'integer', 'minimum': 0, 'maximum': 11},
                       'enteredSign': {'type': 'integer', 'minimum': 0, 'maximum': 11}},
                      optional=['longitude', 'aspectAngle', 'previousSign', 'enteredSign'])
query = object_schema({'from': date, 'to': date, 'bodies': body_list, 'types': {'type': 'array', 'minItems': 1, 'uniqueItems': True, 'items': {'enum': kinds}}})
events = object_schema({'schemaVersion': {'const': 1}, 'algorithmRevision': {'type': 'string'}, 'provider': provider, 'calculatedAt': date, 'query': query,
                        'coverageEnd': date, 'complete': {'type': 'boolean'}, 'events': {'type': 'array', 'items': event}})
position = object_schema({'body': {'enum': bodies}, 'longitude': {'type': 'number', 'minimum': 0, 'exclusiveMaximum': 360},
                          'latitude': {'type': 'number', 'minimum': -90, 'maximum': 90}, 'velocity': number})
sky = object_schema({'schemaVersion': {'const': 1}, 'provider': provider, 'at': date, 'calculatedAt': date,
                     'positions': {'type': 'array', 'minItems': 1, 'items': position}})
schema = {'$schema': 'https://json-schema.org/draft/2020-12/schema', 'title': 'HypergateBar JSON document v1', 'oneOf': [sky, events]}

def validate(value, rule):
    if 'oneOf' in rule:
        matches = 0
        for candidate in rule['oneOf']:
            try:
                validate(value, candidate)
                matches += 1
            except (AssertionError, TypeError, KeyError):
                pass
        assert matches == 1, 'Document must match exactly one schema branch'
        return
    if 'const' in rule:
        assert value == rule['const'] and isinstance(value, bool) == isinstance(rule['const'], bool)
    if 'enum' in rule:
        assert value in rule['enum']
    kind = rule.get('type')
    types = {'object': dict, 'array': list, 'string': str, 'boolean': bool, 'integer': int, 'number': (int, float)}
    if kind:
        assert isinstance(value, types[kind]) and (kind not in ('integer', 'number') or not isinstance(value, bool))
        if kind == 'number':
            assert math.isfinite(value)
    if kind == 'object':
        assert set(rule['required']) <= set(value)
        assert set(value) <= set(rule['properties'])
        for key, item in value.items():
            validate(item, rule['properties'][key])
    if kind == 'array':
        assert len(value) >= rule.get('minItems', 0)
        if rule.get('uniqueItems'):
            assert len({json.dumps(item, sort_keys=True) for item in value}) == len(value)
        for item in value:
            validate(item, rule['items'])
    if 'pattern' in rule:
        assert re.fullmatch(rule['pattern'], value)
    if 'minimum' in rule:
        assert value >= rule['minimum']
    if 'maximum' in rule:
        assert value <= rule['maximum']
    if 'exclusiveMaximum' in rule:
        assert value < rule['exclusiveMaximum']

if __name__ == '__main__':
    path = root / 'docs/document-v1.schema.json'
    if '--write' in sys.argv:
        path.write_text(json.dumps(schema, indent=2) + '\n')
    else:
        assert json.loads(path.read_text()) == schema, 'Committed schema differs from the reviewed vocabulary'
        for argument in sys.argv[1:]:
            validate(json.loads(pathlib.Path(argument).read_text()), schema)
        print('Schema v1 and supplied documents validated.')
