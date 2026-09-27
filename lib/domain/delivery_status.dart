import 'package:flutter/material.dart';

enum DeliveryKind { gas, parcel, food }

class DeliveryStatus {
  static const gasFinal = {'delivered_paid', 'empty_returned'};
  static const parcelFinal = {'delivered_paid'};
  static const foodFinal = {'delivered_paid', 'cancelled'};

  static const gasInProgress = {'accepted', 'depot_selected', 'at_depot', 'en_route'};
  static const parcelInProgress = {'accepted', 'picked_up', 'en_route'};
  static const foodInProgress = {'pending', 'accepted', 'en_route', 'stop_picked_up'};

  static bool isFinal(DeliveryKind kind, String status) {
    final s = status.toLowerCase();
    switch (kind) {
      case DeliveryKind.gas:
        return gasFinal.contains(s);
      case DeliveryKind.parcel:
        return parcelFinal.contains(s);
      case DeliveryKind.food:
        return foodFinal.contains(s);
    }
  }

  static bool isInProgress(DeliveryKind kind, String status) {
    final s = status.toLowerCase();
    switch (kind) {
      case DeliveryKind.gas:
        return gasInProgress.contains(s);
      case DeliveryKind.parcel:
        return parcelInProgress.contains(s);
      case DeliveryKind.food:
        return foodInProgress.contains(s);
    }
  }

  static String labelFr(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'assigned':
        return 'Assignée';
      case 'depot_selected':
        return 'Dépôt sélectionné';
      case 'at_depot':
        return 'Au dépôt';
      case 'picked_up':
        return 'Récupéré';
      case 'stop_picked_up':
        return 'Ramassage au restaurant';
      case 'en_route':
        return 'En route';
      case 'delivered_paid':
        return 'Livrée & payée';
      case 'empty_returned':
        return 'Vide retourné';
      case 'cancelled':
        return 'Annulée';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  static Color chipColor(String status) {
    switch (status) {
      case 'delivered_paid':
      case 'empty_returned':
        return const Color(0xFFB9EEAB);
      case 'accepted':
      case 'assigned':
        return const Color(0xFFFFD9D6);
      case 'en_route':
      case 'stop_picked_up':
        return const Color(0xFFFFDEA5);
      case 'cancelled':
        return const Color(0xFFFFDAD6);
      case 'pending':
      default:
        return const Color(0xFFEDEEEF);
    }
  }
}

