# Plan d'Architecture & Implémentation — Module Événementiel Adiaké Express

> **Document de Spécification Fonctionnelle et Technique**
> **Projet** : Adiaké Livraison Express (Famanh)
> **Module** : Gestion des Événements & Billeterie en ligne (Ticketing System)

---

## 1. Vision & Objectifs du Module Événementiel

Le module événementiel d'Adiaké Express permettra de centraliser tous les événements culturels, sportifs, festifs et communautaires de la région d'Adiaké et ses environs (Assinie, Aby, Etuéboué, etc.).

### Objectifs principaux :
1. **Monétisation & Nouvelles Recettes** : Commission sur chaque billet vendu via l'application.
2. **Expérience Utilisateur Unifiée** : Achat de billets instantané en FCFA avec réception d'un **Pass QR Code numérique**.
3. **Contrôle d'Accès Facile** : Validation des billets le jour de l'événement via un scanner QR Code intégré dans l'application ou l'espace gestionnaire.

---

## 2. Modèle de Données & Base de Données (Laravel MySQL)

### 2.1 Table `events` (Événements)
- `id` (BigIncrements)
- `title` (String) — Ex: *Festival des Grillades d'Adiaké 2026*
- `description` (Text) — Détails complets, artistes présentés, programme.
- `organizer_name` (String) — Nom de l'organisateur ou de l'établissement.
- `organizer_phone` (String) — Contact direct pour assistance.
- `category` (String) — *Concert, Sport, Culture, Foire, Soirée VIP, Conférence*.
- `location_name` (String) — Ex: *Place de l'Indépendance d'Adiaké*
- `latitude` / `longitude` (Decimal, nullable) — Pour la géolocalisation.
- `image_url` (String) — Affiche officielle / Visuel HD.
- `starts_at` (DateTime) — Date et heure de début.
- `ends_at` (DateTime) — Date et heure de fin.
- `is_featured` (Boolean) — Événement à la Une sur la page d'accueil.
- `is_active` (Boolean) — Statut de l'événement (*Actif / Annulé / Terminé*).
- `timestamps`

### 2.2 Table `ticket_types` (Catégories de Billet par Événement)
- `id` (BigIncrements)
- `event_id` (Foreign Key -> `events.id`)
- `name` (String) — Ex: *Pass Grand Public*, *Ticket VIP*, *Pass Bateau + Entrée*
- `price_fcfa` (UnsignedInteger) — Prix en Francs CFA (Ex: 2 000 FCFA, 5 000 FCFA).
- `total_quantity` (UnsignedInteger) — Stock total disponible.
- `remaining_quantity` (UnsignedInteger) — Billets restants en stock.
- `benefits` (JSON / Text) — Avantages inclus (*1 Boisson offerte, Accès salon VIP*).
- `timestamps`

### 2.3 Table `event_bookings` (Réservations & Acheteurs)
- `id` (BigIncrements)
- `booking_reference` (String, Unique) — Ex: *EVT-2026-8942*
- `user_id` (Foreign Key -> `users.id`)
- `event_id` (Foreign Key -> `events.id`)
- `ticket_type_id` (Foreign Key -> `ticket_types.id`)
- `quantity` (UnsignedInteger) — Nombre de billets achetés.
- `total_amount_fcfa` (UnsignedInteger) — Montant total payé.
- `payment_method` (String) — *Paiement en espèces à la livraison / remise*.
- `payment_status` (String) — *paid, pending, cancelled*.
- `qr_code_token` (String, Unique) — Token crypté pour la génération du QR Code.
- `is_scanned` (Boolean, default: false) — Statut d'accès à l'événement.
- `scanned_at` (DateTime, nullable) — Date et heure du scan à l'entrée.
- `scanned_by_user_id` (Foreign Key -> `users.id`, nullable) — Identifiant de l'agent d'accueil qui a validé le ticket.
- `timestamps`

---

## 3. Back-office Administrateur (`/admin/events`)

### 3.1 Tableau de Bord Événementiel
- **Compteurs Clés** :
  - Nombre total d'événements à venir.
  - Billets vendus & Recettes globales accumulées (FCFA).
  - Taux de remplissage des événements.
- **Liste & Gestion CRUD des Événements** :
  - Création d'un événement avec téléversement de l'affiche publicitaire.
  - Définition des types de tickets (*Standard*, *VIP*, *VVIP*) et des quotas.
  - Statut en ligne / hors ligne et mise en avant (*Featured*).

### 3.2 Suivi des Ventes & Téléchargement des Listes d'Émargement
- Recherche par nom d'acheteur, téléphone ou référence de ticket (`EVT-...`).
- Exportation PDF/Excel de la liste des participants pour les organisateurs.

---

## 4. Expérience Client sur l'Application Mobile (Flutter)

### 4.1 Portail Événements (Onglet / Card Services)
- NOUVELLE tuile interactive **"Événements"** ajoutée dans le menu des services (`Que souhaitez-vous ?`).
- Carrousel des événements VIP à la Une et liste filtrable par catégorie (*Ce weekend*, *Concerts*, *Culture & Tradition*).

### 4.2 Fiche Détail Événement
- Affiche HD en haut de page avec dégradé sombre.
- Date, Heure, Lieu précis et boutons d'itinéraire GPS.
- Choix de la formule de billet (Sélection quantité avec calcul dynamique du prix total).

### 4.3 Paiement & Validation Instantanée
- Paiement en espèces à la livraison / à la remise du Pass.
- Dès la confirmation du paiement :
  - Notification Push de confirmation d'achat.
  - Génération du billet dans la section **"Mes Tickets & Pass"**.

### 4.4 Portefeuille "Mes Tickets QR Code"
- Affichage du Pass numérique avec **QR Code HD**.
- Fonctionne même hors-ligne (stockage sécurisé local du QR Code).
- Boutons "Partager le billet" et "Ajouter au calendrier".

---

## 5. Scanner & Contrôle d'Accès le Jour J

- Interface dédiée aux contrôleurs/agents à l'entrée du site :
  - Utilisation de la caméra du téléphone pour scanner le QR Code du client.
  - Validation instantanée (*Succès : Billet Valide VIP - Bienvenue !* ou *Erreur : Billet déjà réutilisé ou invalide*).

---

## 6. Planning d'Exécution Proposé

1. **Phase 1 (Backend & DB)** : Migrations tables `events`, `ticket_types`, `event_bookings`, création du contrôleur `AdminEventController` et routes API.
2. **Phase 2 (Back-office Views)** : Interfaces d'administration Blade `/admin/events` avec création/édition d'événements et statistiques.
3. **Phase 3 (Flutter Mobile)** : Écran catalogue `EventCatalogScreen`, fiche détail `EventDetailScreen`, module de paiement et portefeuille de tickets QR Code `MyTicketsScreen`.
4. **Phase 4 (Scanner QR Code)** : Intégration du scanner caméra pour le contrôle à l'entrée.
