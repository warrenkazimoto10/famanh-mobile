# Plan de refonte UI — Adiaké Express

> Cadré avec le skill **ui-ux-pro-max**. On garde la marque (navy `#0B5CAB`, vert secondaire, cartes glass) mais on applique des principes modernes : hiérarchie forte, espacement 8dp régulier, **un seul CTA primaire par écran**, chiffres tabulaires pour les prix, skeletons au chargement, transitions 150–300ms, cibles tactiles ≥ 44px.

## Système de design (référence)
- **Type scale** : 12 / 14 / 16 / 18 / 22 / 28 (titres `w800`, corps `w400/500`, labels `w600`).
- **Espacement** : 4 / 8 / 12 / 16 / 24 / 32. Sections séparées par 24.
- **Couleurs sémantiques** (déjà dans `AdiakeColors`) : `primary`, `secondary`, `error`, `surface`, `onSurfaceVariant`. Éviter les hex en dur dans les écrans.
- **Cartes** : rayon 20–24, ombre douce unique (pas d'ombres aléatoires).
- **Prix** : police à chiffres tabulaires + format `1 000` (utilitaire `MoneyText.fmt`).
- **États** : loading (skeleton), vide (illustration + texte + action), erreur (message + « Réessayer »).

---

## ✅ Déjà livré dans cette passe
1. **Mon compte → Changer le mot de passe** : endpoint `PATCH /api/me/password` (vérifie le mot de passe actuel) + carte « Sécurité » + dialogue validé (tests backend inclus).
2. **Cartes type de gaz** : logo + **nom de la marque** + taille + prix ; titre de section « Type de gaz » ; suppression de toutes les mentions « back-office » côté client.
3. Correctifs antérieurs : login plein écran, onboarding sans chevauchement, carte « Livraison Express » lisible, overflow carte Livraison.

---

## 1. Fonctionnalité — Prix de la bouteille (consigne) quand ce n'est PAS un échange
**Règle métier** : si le client **n'a pas de bouteille vide à rendre**, il achète une **bouteille neuve pleine** → on ajoute le **prix de la consigne/bouteille** au total. S'il fait un **échange**, seul le prix du gaz s'applique.

### Données (backend)
- Migration : ajouter `bottle_deposit_fcfa` (int, nullable/0 par défaut) sur **`gas_products`**.
- `GasProduct` `$fillable` += `bottle_deposit_fcfa`.
- `GasOrder` : ajouter `bottle_deposit_fcfa` (int, snapshot au moment de la commande) pour traçabilité.

### Admin (back-office)
- Formulaire produit gaz (`admin/gas/products`) : champ **« Prix de la bouteille (consigne) »** avec validation `integer|min:0|max:1000000`.

### API
- `GET /api/gas/products` renvoie `bottle_deposit_fcfa`.
- `POST /api/gas/orders` : si `has_exchange_bottle = false`, `price_fcfa = (unit_price + bottle_deposit) * qty + delivery_fee` ; sinon sans la consigne. **Calcul fait côté serveur** (ne jamais faire confiance au total client).

### Client (Flutter)
- DTO `GasProduct` += `bottleDepositFcfa`.
- Carte « Échange de bouteille » : quand le toggle est **OFF**, afficher une ligne « Bouteille neuve (consigne) : +X FCFA » et un court texte explicatif.
- Récap **Total estimé** : détailler `gaz + (consigne si neuve) + livraison`.
- Mettre à jour le total en temps réel au changement du toggle / quantité.

### Tests
- Backend : total avec/sans échange ; admin enregistre la consigne ; bornes.

---

## 2. Recherche d'adresse **très précise** (écran « Adresse de livraison »)
Actuellement : carte + champ texte sans autocomplétion → imprécis.
### Approche
- Intégrer un **geocoding / autocomplete** : 
  - Option A (gratuit) : **Nominatim/Photon (OpenStreetMap)** avec biais sur la région d'Adiaké (`viewbox` + `bounded=1`, `countrycodes=ci`).
  - Option B : Google Places Autocomplete (clé API, payant) si budget.
- **UX** :
  - Champ → liste de **suggestions** sous le champ (debounce 300 ms, min 3 caractères).
  - Sélection d'une suggestion → recentre la carte + place le marqueur précis + remplit l'adresse.
  - **Marqueur déplaçable** + bouton « ma position » (déjà présent) → reverse-geocoding pour afficher l'adresse exacte.
  - Afficher lat/lng retenues et un libellé lisible avant « Confirmer ».
- Stocker `delivery_lat/lng` précis (déjà validés `between -90/90`, `-180/180`).

---

## 3. Refonte — Historique des commandes
Problème : design plat, peu hiérarchisé, états vides absents.
### Nouveau design
- **Filtres** en haut (chips horizontales) : Tous · Gaz · Colis · Repas.
- **Carte commande** moderne :
  - Ligne 1 : icône type (pastille colorée) + **titre** (« Gaz · Total 6kg ») + **badge statut** coloré (En attente=ambre, En route=bleu, Livré=vert, Annulé=rouge) avec icône (pas couleur seule).
  - Ligne 2 : `Qté · Montant` (chiffres tabulaires) + date relative à droite.
  - Barre de progression fine du statut (commandé → assigné → en route → livré).
  - Chevron + tap → détail (transition hero).
- **État vide** : illustration + « Aucune commande pour le moment » + bouton « Commander ».
- **Skeleton** au chargement (shimmer existe déjà : `skeleton_loader.dart`).
- **Pull-to-refresh** + pagination.

## 4. Détail d'une commande (nouveau / amélioré)
- **En-tête** : type + statut (grand badge) + n° commande + date.
- **Timeline verticale** des `statusEvents` (point + libellé + heure), l'étape courante mise en avant.
- **Carte livreur** (si assigné) : nom, véhicule, bouton Appeler + lien **Suivi en direct** (carte temps réel).
- **Récapitulatif** : articles/contenu + sous-total + livraison + (consigne) + **Total** (tabulaire).
- **Adresse de livraison** (mini-carte statique).
- **Actions** contextuelles : « Annuler » (si annulable), « Refaire la commande ».
- Respecter : un seul CTA primaire, actions destructives séparées (rouge).

---

## 5. Refonte transversale des vues (pour un rendu vraiment moderne)
Ordre conseillé :
1. **Design tokens** : centraliser type scale + spacing dans le thème (`adiake_theme`), créer des widgets réutilisables `SectionTitle`, `StatusBadge`, `PriceText`, `AppCard` cohérents.
2. **Dashboard client** : hero accueil + « Réserver un service » en cartes block-based (icône, titre, sous-titre, chevron) — déjà amorcé.
3. **Listes** (commandes, restaurants, résidences) : cartes homogènes, états vides + skeletons + pull-to-refresh partout.
4. **Flux de commande** (gaz/colis/food) : header produit, sélection claire, récap collant en bas avec total + CTA unique.
5. **Détail & tracking** : timeline + carte live unifiées.
6. **Profil** : déjà refait ; ajouter section Sécurité (fait) + préférences.
7. **i18n** : brancher `AppLocalizations` (chaînes aujourd'hui en dur).
8. **Accessibilité** : labels sémantiques, contraste 4.5:1, cibles ≥44px, `prefers-reduced-motion`.

---

## Séquencement proposé (par lots livrables)
- **Lot A (métier)** : prix bouteille/consigne (backend + admin + client + tests). 
- **Lot B (UX)** : refonte Historique + Détail commande + états vides/skeletons.
- **Lot C (précision)** : autocomplétion d'adresse (Nominatim/Photon).
- **Lot D (système)** : tokens + composants réutilisables + i18n.

Chaque lot est autonome et testable indépendamment.
