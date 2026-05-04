// TeleMed_K — one-shot script: update 5 patient CNP identifiers on Medplum.
//
// Run from the repo root:
//   dart tools/update_medplum_cnps.dart
//
// Requires dart CLI (comes with Flutter SDK).
// Credentials are read from env vars so nothing sensitive lives in source:
//   MEDPLUM_CLIENT_ID     (default: d5d39070-c8a4-43a6-92e5-1a78b695ca72)
//   MEDPLUM_CLIENT_SECRET (required)

import 'dart:convert';
import 'dart:io';

const _base     = 'https://telemed-medplum.duckdns.org/fhir/R4';
const _tokenUrl = 'https://telemed-medplum.duckdns.org/oauth2/token';

// New checksum-valid CNPs (county 15 = Dâmbovița, NNN 001-005).
// Old invalid CNPs → new valid CNPs.
const _patients = [
  _Patient(
    medplumId : 'a0e44abc-acc5-442e-a316-be70192fc72b',
    name      : 'Maria Ionescu',
    newCnp    : '2540203150013',  // F born 1954-02-03, check=3
  ),
  _Patient(
    medplumId : '118149bf-26e0-46e1-87de-7149e8066284',
    name      : 'Ion Popescu',
    newCnp    : '1490815150027',  // M born 1949-08-15, check=7
  ),
  _Patient(
    medplumId : '510b8c93-ef4a-43bc-b265-197fcfc03c2b',
    name      : 'Elena Dumitrescu',
    newCnp    : '2621105150032',  // F born 1962-11-05, check=2
  ),
  _Patient(
    medplumId : '6955bb14-46d7-4a9b-b7a4-d98e95051f3f',
    name      : 'Gheorghe Stan',
    newCnp    : '1551220150048',  // M born 1955-12-20, check=8
  ),
  _Patient(
    medplumId : '40d2b51f-5a36-4e13-9755-5e7b6bb9ba85',
    name      : 'Ana Constantin',
    newCnp    : '2480430150058',  // F born 1948-04-30, check=8
  ),
];

final class _Patient {
  final String medplumId;
  final String name;
  final String newCnp;
  const _Patient({required this.medplumId, required this.name, required this.newCnp});
}

Future<void> main() async {
  final clientId     = Platform.environment['MEDPLUM_CLIENT_ID']
      ?? 'd5d39070-c8a4-43a6-92e5-1a78b695ca72';
  final clientSecret = Platform.environment['MEDPLUM_CLIENT_SECRET'] ?? '';

  if (clientSecret.isEmpty) {
    stderr.writeln('ERROR: MEDPLUM_CLIENT_SECRET env var is required.');
    exit(1);
  }

  final client = HttpClient();
  try {
    final token = await _fetchToken(client, clientId, clientSecret);
    print('Token acquired.');

    for (final p in _patients) {
      await _updatePatientCnp(client, token, p);
    }
    print('\nAll 5 patients updated successfully.');
  } finally {
    client.close();
  }
}

Future<String> _fetchToken(HttpClient client, String id, String secret) async {
  final req = await client.postUrl(Uri.parse(_tokenUrl));
  req.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
  req.write('grant_type=client_credentials&client_id=$id&client_secret=${Uri.encodeComponent(secret)}');
  final res  = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) {
    throw Exception('Token fetch failed ${res.statusCode}: $body');
  }
  final json = jsonDecode(body) as Map<String, dynamic>;
  return json['access_token'] as String;
}

Future<void> _updatePatientCnp(HttpClient client, String token, _Patient p) async {
  final url = Uri.parse('$_base/Patient/${p.medplumId}');

  // GET current patient resource.
  final getReq = await client.getUrl(url);
  getReq.headers
    ..set('Authorization', 'Bearer $token')
    ..set('Accept', 'application/fhir+json');
  final getRes  = await getReq.close();
  final getBody = await getRes.transform(utf8.decoder).join();

  if (getRes.statusCode != 200) {
    stderr.writeln('WARN: GET ${p.name} failed ${getRes.statusCode} — skipping');
    return;
  }

  final resource = jsonDecode(getBody) as Map<String, dynamic>;

  // Replace or insert CNP identifier.
  final identifiers = (resource['identifier'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final cnpIdx = identifiers.indexWhere(
      (i) => i['system'] == 'urn:oid:1.2.40.0.10.1.4.3.1');

  if (cnpIdx >= 0) {
    identifiers[cnpIdx] = {
      'system': 'urn:oid:1.2.40.0.10.1.4.3.1',
      'value' : p.newCnp,
    };
  } else {
    identifiers.add({
      'system': 'urn:oid:1.2.40.0.10.1.4.3.1',
      'value' : p.newCnp,
    });
  }
  resource['identifier'] = identifiers;

  // PUT updated resource.
  final putReq = await client.putUrl(url);
  putReq.headers
    ..set('Authorization', 'Bearer $token')
    ..set('Content-Type', 'application/fhir+json')
    ..set('Accept', 'application/fhir+json');
  putReq.write(jsonEncode(resource));
  final putRes  = await putReq.close();
  final putBody = await putRes.transform(utf8.decoder).join();

  if (putRes.statusCode == 200 || putRes.statusCode == 201) {
    print('  ✓ ${p.name}: CNP → ${p.newCnp}');
  } else {
    stderr.writeln('  ✗ ${p.name}: PUT failed ${putRes.statusCode}: $putBody');
  }
}
