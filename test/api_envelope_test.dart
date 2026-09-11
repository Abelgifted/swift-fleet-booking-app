// Regression guard for the envelope-parsing bug that broke trip search.
//
// The backend answers every collection endpoint with
//   {Success, Message, Data:{…}}.
// The old parser only looked for list keys on the *top level*, so
// `{Data:{Locations:[…]}}` was returned as a single bogus row — which left
// the location pickers empty and the search button permanently disabled.
//
// The payloads below are verbatim captures from the live Swift Fleet API.
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_booking/models/location.dart';
import 'package:fleet_booking/models/route.dart';
import 'package:fleet_booking/models/trip.dart';
import 'package:fleet_booking/utils/api_envelope.dart';

const _locationsBody = {
  'Success': true,
  'Message': 'Locations retrieved',
  'Data': {
    'Locations': [
      {'Id': '0be4753a-acc7-49a0-8d80-4b116679', 'Name': 'Abuja', 'Code': 'Abuja'},
      {'Id': '20ed097a-70d7-4b46-b457-5213aeaa', 'Name': 'Jos ', 'Code': 'Jos '},
      {'Id': 'be2a816f-6dce-40e3-80f4-c6192916', 'Name': 'Lagos', 'Code': 'Lagos'},
    ],
  },
  'StatusCode': 200,
};

const _routesBody = {
  'Success': true,
  'Message': 'Routes retrieved',
  // Routes put the list directly under Data, locations nest it one deeper.
  'Data': [
    {
      'Id': '77444f1d-0f69-4b18-93e7-9d6f8c',
      'Name': 'Abuja to Lagos',
      'SourceId': '0be4753a-acc7-49a0-8d80-4b116679',
      'SourceName': 'Abuja',
      'DestinationId': 'be2a816f-6dce-40e3-80f4-c6192916',
      'DestinationName': 'Lagos',
      'Fare': 1000.00,
      'EstimatedDuration': 0,
    },
  ],
  'StatusCode': 200,
};

const _emptySearchBody = {
  'Success': true,
  'Message': 'No trips available for the selected route and date',
  'Data': {
    'Trips': <dynamic>[],
    'SourceLocations': [
      {'Id': 'a', 'Name': 'Abuja', 'Code': 'Abuja'},
    ],
    'DestinationLocations': [
      {'Id': 'b', 'Name': 'Lagos', 'Code': 'Lagos'},
    ],
    'SearchDate': '2026-09-11T00:00:00',
  },
  'StatusCode': 200,
};

const _notFoundBody = {
  'Success': false,
  'Message': 'Trip not found',
  'Data': null,
  'StatusCode': 200,
};

void main() {
  group('ApiEnvelope.listFrom', () {
    test('unwraps {Data:{Locations:[…]}} into the real locations', () {
      final items = ApiEnvelope.listFrom(_locationsBody);
      expect(items, hasLength(3),
          reason: 'the envelope must not be mistaken for a single row');
      final places = items
          .whereType<Map<String, dynamic>>()
          .map(Location.fromJson)
          .toList();
      expect(places.map((l) => l.name.trim()), ['Abuja', 'Jos', 'Lagos']);
      expect(places.first.id, '0be4753a-acc7-49a0-8d80-4b116679');
    });

    test('unwraps {Data:[…]} when the list is directly under Data', () {
      final items = ApiEnvelope.listFrom(_routesBody);
      expect(items, hasLength(1));
      final routes = items
          .whereType<Map<String, dynamic>>()
          .map(RouteModel.fromJson)
          .toList();
      expect(routes.single.sourceName, 'Abuja');
      expect(routes.single.destinationName, 'Lagos');
      expect(routes.single.fare, 1000.0);
    });

    test('returns the Trips array, not the sibling location arrays', () {
      final items = ApiEnvelope.listFrom(_emptySearchBody);
      expect(items, isEmpty,
          reason: 'Trips is empty; SourceLocations must not be used instead');
      final trips = items.whereType<Map<String, dynamic>>().map(Trip.fromJson);
      expect(trips, isEmpty);
    });

    test('treats a null Data payload as no rows, not one row', () {
      expect(ApiEnvelope.listFrom(_notFoundBody), isEmpty);
    });

    test('keeps a bare single-object body as exactly one row', () {
      expect(ApiEnvelope.listFrom({'BookingId': 'BK-1'}), hasLength(1));
    });

    test('handles a bare list body', () {
      expect(ApiEnvelope.listFrom([1, 2, 3]), hasLength(3));
    });

    test('degrades to empty for null and scalars', () {
      expect(ApiEnvelope.listFrom(null), isEmpty);
      expect(ApiEnvelope.listFrom('nope'), isEmpty);
      expect(ApiEnvelope.listFrom(42), isEmpty);
    });
  });

  group('ApiEnvelope.messageFrom', () {
    test('lifts the server message out of the envelope', () {
      expect(
        ApiEnvelope.messageFrom(_emptySearchBody),
        'No trips available for the selected route and date',
      );
    });

    test('returns null when there is no message', () {
      expect(ApiEnvelope.messageFrom({'Data': <dynamic>[]}), isNull);
      expect(ApiEnvelope.messageFrom(null), isNull);
      expect(ApiEnvelope.messageFrom({'Message': '   '}), isNull);
    });
  });

  group('ApiEnvelope.parse', () {
    test('returns both halves of the envelope together', () {
      final parsed = ApiEnvelope.parse(_locationsBody);
      expect(parsed.items, hasLength(3));
      expect(parsed.message, 'Locations retrieved');
    });
  });
}
