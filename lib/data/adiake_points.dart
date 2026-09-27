import 'package:latlong2/latlong.dart';

enum AdiakePointType { gasDepot, pickupPoint }

class AdiakePoint {
  const AdiakePoint({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
  });

  final String id;
  final String name;
  final AdiakePointType type;
  final LatLng location;
}

/// Points par défaut (paramétrables plus tard via écran Admin/Settings).
///
/// NOTE: remplace ces coordonnées par les vrais emplacements quand tu les as.
const adiakeDefaultPoints = <AdiakePoint>[
  AdiakePoint(
    id: 'depot_adiake_centre',
    name: 'Dépôt Gaz • Adiaké Centre',
    type: AdiakePointType.gasDepot,
    location: LatLng(5.2867, -3.3042),
  ),
  AdiakePoint(
    id: 'depot_lagune_est',
    name: 'Dépôt Gaz • Lagune Est',
    type: AdiakePointType.gasDepot,
    location: LatLng(5.2925, -3.2920),
  ),
  AdiakePoint(
    id: 'depot_sortie_aboisso',
    name: 'Dépôt Gaz • Sortie Aboisso',
    type: AdiakePointType.gasDepot,
    location: LatLng(5.2790, -3.3170),
  ),
];

