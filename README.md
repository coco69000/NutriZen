# NutriZen / Podomètre - Application & Sécurité

Application Flutter avec suivi de santé, analyse nutritionnelle IA et fonctionnalités Premium.

---

## 🔒 Configuration & Sécurité des Clés API

### 1. Variables d'Environnement (Lancement local / Build)

Ne committez jamais les clés API réelles dans le dépôt Git.
Utilisez l'option `--dart-define` lors de la compilation Flutter :

```bash
flutter run --dart-define=DEEPSEEK_API_KEY=votre_cle_deepseek --dart-define=USDA_API_KEY=votre_cle_usda
```

Ou en release :

```bash
flutter build apk --release \
  --dart-define=DEEPSEEK_API_KEY=votre_cle_deepseek \
  --dart-define=USDA_API_KEY=votre_cle_usda \
  --obfuscate --split-debug-info=build/app/outputs/symbols
```

### 2. Obfuscation du Code (Release Android / iOS)

Pour empêcher l'ingénierie inverse et la décompilation facile de l'APK/IPA :
- **Android APK** : `flutter build apk --obfuscate --split-debug-info=build/app/outputs/symbols`
- **Android App Bundle** : `flutter build appbundle --obfuscate --split-debug-info=build/app/outputs/symbols`
- **iOS App** : `flutter build ipa --obfuscate --split-debug-info=build/app/outputs/symbols`

---

## 🔥 Déploiement de la Sécurité Firebase

### 1. Déploiement des Règles Firestore (`firestore.rules`)

Les règles de sécurité protègent l'accès aux données utilisateur et empêchent la falsification du statut Premium (`isPremium`) et la réinitialisation des quotas :

```bash
firebase deploy --only firestore:rules
```

### 2. Déploiement des Cloud Functions (`functions/`)

Les requêtes IA et la validation d'accès Premium sont exécutées côté serveur dans les Cloud Functions Firebase :

```bash
# Configuration de la clé API secrète sur le serveur Firebase
firebase functions:config:set deepseek.key="votre_cle_api_secrete"

# Déploiement des Cloud Functions
firebase deploy --only functions
```
