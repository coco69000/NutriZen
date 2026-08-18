//main.dart
import 'dart:io';

// 1. DONNEZ UN ALIAS EXPLICITE Ã€ FLUTTER
import 'package:flutter/material.dart' as flutter;
// Gardez aussi l'import normal pour que le reste du fichier fonctionne sans prÃ©fixe
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/menu_planning_tab.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/activities/exercise_library_screen.dart';
import 'services/service_locator.dart';
import 'services/exercise_library_service.dart';
import 'onboarding_flow_screen.dart';

// Firebase imports... (inchangÃ©s)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';

// NOUVEAU: Notifier global pour le mode de thÃ¨me (Clair / Sombre / SystÃ¨me)
final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(
  ThemeMode.system,
);

class AppStateProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  List<FoodEntry> allFoodEntries = [];
  List<ActivityEntry> allActivities = [];
  List<WeightEntry> allWeightEntries = [];

  AppStateProvider(this._firestoreService) {
    loadData();
  }

  DateTime selectedMonth = DateTime.now();

  Future<void> loadData() async {
    allFoodEntries = await _firestoreService.getCollectionForMonth<FoodEntry>(
      'foodEntries',
      selectedMonth,
      FoodEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    allActivities = await _firestoreService.getCollection<ActivityEntry>(
      'activities',
      ActivityEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    allWeightEntries = await _firestoreService.getCollection<WeightEntry>(
      'weightEntries',
      WeightEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    notifyListeners();
  }

  Future<void> loadFoodEntriesForMonth(DateTime month) async {
    selectedMonth = month;
    allFoodEntries = await _firestoreService.getCollectionForMonth<FoodEntry>(
      'foodEntries',
      month,
      FoodEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    notifyListeners();
  }

  Future<void> addFoodEntry(FoodEntry entry) async {
    allFoodEntries.add(entry);
    notifyListeners();
    await _firestoreService.addDocument(
      'foodEntries',
      entry,
      (e) => e.toFirestore(),
    );
  }

  Future<void> addActivityEntry(ActivityEntry entry) async {
    allActivities.add(entry);
    notifyListeners();
    await _firestoreService.addDocument(
      'activities',
      entry,
      (e) => e.toFirestore(),
    );
  }

  Future<void> addWeightEntry(WeightEntry entry) async {
    final existingIndex = allWeightEntries.indexWhere(
      (e) => isSameDay(e.date, entry.date),
    );
    if (existingIndex != -1) {
      allWeightEntries[existingIndex] = entry;
    } else {
      allWeightEntries.add(entry);
    }
    notifyListeners();
    if (existingIndex != -1) {
      await _firestoreService.setDocument(
        'weightEntries',
        allWeightEntries[existingIndex].id,
        entry,
        WeightEntry.fromFirestore,
        (e) => e.toFirestore(),
      );
    } else {
      await _firestoreService.addDocument(
        'weightEntries',
        entry,
        (e) => e.toFirestore(),
      );
    }
  }
}

// 1. Ajoute cette classe juste au-dessus de void main()
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. AJOUTE CETTE LIGNE ICI (TrÃ¨s important !)
  if (kDebugMode) { HttpOverrides.global = MyHttpOverrides(); }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('fr_FR', null);

  // Initialisation des services IA et Intelligence Locale
  await SL.initAll();

  // NOUVEAU: VÃ©rifier si l'onboarding est terminÃ©
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingCompleted =
      prefs.getBool('onboardingCompleted') ?? false;

  // Charger le thÃ¨me depuis les prÃ©fÃ©rences
  final String? savedTheme = prefs.getString('app_theme_mode');
  if (savedTheme == 'light') {
    appThemeNotifier.value = ThemeMode.light;
  } else if (savedTheme == 'dark') {
    appThemeNotifier.value = ThemeMode.dark;
  } else {
    appThemeNotifier.value = ThemeMode.system;
  }

  runApp(NutritionApp(onboardingCompleted: onboardingCompleted));
}

class NutritionApp extends StatelessWidget {
  final bool onboardingCompleted;

  const NutritionApp({super.key, required this.onboardingCompleted});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, _) {
        return flutter.MaterialApp(
          title: 'NutriZen',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // --- THÃˆME CLAIR (MODERNE) ---
          theme: flutter.ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: flutter.Colors.teal,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            scaffoldBackgroundColor: flutter.Colors.grey.shade50,
            cardTheme: const CardThemeData(
              elevation: 2.0,
              margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20.0)),
              ),
            ),
            appBarTheme: flutter.AppBarTheme(
              backgroundColor: flutter.Colors.teal.shade700,
              foregroundColor: flutter.Colors.white,
              centerTitle: true,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              titleTextStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: flutter.Colors.white,
              ),
            ),
            elevatedButtonTheme: flutter.ElevatedButtonThemeData(
              style: flutter.ElevatedButton.styleFrom(
                foregroundColor: flutter.Colors.white,
                backgroundColor: flutter.Colors.teal.shade600,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            textButtonTheme: flutter.TextButtonThemeData(
              style: flutter.TextButton.styleFrom(
                foregroundColor: flutter.Colors.teal.shade700,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            floatingActionButtonTheme: flutter.FloatingActionButtonThemeData(
              backgroundColor: flutter.Colors.teal.shade700,
              foregroundColor: flutter.Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // --- THÃˆME SOMBRE (MODERNE) ---
          darkTheme: flutter.ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: flutter.Colors.tealAccent,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardTheme: const CardThemeData(
              color: Color(0xFF1E1E1E),
              elevation: 4.0,
              margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20.0)),
              ),
            ),
            appBarTheme: const flutter.AppBarTheme(
              backgroundColor: Color(0xFF1F1F1F),
              foregroundColor: flutter.Colors.white,
              centerTitle: true,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              titleTextStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: flutter.Colors.white,
              ),
            ),
            elevatedButtonTheme: flutter.ElevatedButtonThemeData(
              style: flutter.ElevatedButton.styleFrom(
                foregroundColor: const Color(0xFF121212),
                backgroundColor: flutter.Colors.tealAccent.shade400,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            textButtonTheme: flutter.TextButtonThemeData(
              style: flutter.TextButton.styleFrom(
                foregroundColor: flutter.Colors.tealAccent.shade200,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            floatingActionButtonTheme: flutter.FloatingActionButtonThemeData(
              backgroundColor: flutter.Colors.tealAccent.shade400,
              foregroundColor: const Color(0xFF121212),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          home:
              onboardingCompleted
                  ? const AuthWrapper()
                  : const OnboardingFlowScreen(),
        );
      },
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get user => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Sign-in error: ${e.message}');
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      // SUPPRIMÃ‰ : La crÃ©ation du document est maintenant gÃ©rÃ©e par le flow d'onboarding
      // ou par le AuthScreen classique.

      // Laisser l'initialisation de l'abonnement ici est une bonne idÃ©e.
      await SubscriptionService(
        userId: userCredential.user!.uid,
      )._initializeSubscription();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Registration error: ${e.message}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? userId;

  FirestoreService({required this.userId});

  // Base collection reference for the current user
  CollectionReference<T> _userCollection<T>(
    String collectionName,
    T Function(Map<String, dynamic>, String) fromFirestore,
    Map<String, dynamic> Function(T) toFirestore,
  ) {
    if (userId == null) {
      throw Exception("User is not authenticated. Cannot access Firestore.");
    }
    return _db
        .collection('users')
        .doc(userId)
        .collection(collectionName)
        .withConverter<T>(
          fromFirestore:
              (snapshot, _) => fromFirestore(snapshot.data()!, snapshot.id),
          toFirestore: (model, _) => toFirestore(model),
        );
  }

  // Generic methods for CRUD operations
  Future<List<T>> getCollection<T>(
    String collectionName,
    T Function(Map<String, dynamic>, String) fromFirestore,
    Map<String, dynamic> Function(T) toFirestore,
  ) async {
    try {
      final snapshot =
          await _userCollection<T>(
            collectionName,
            fromFirestore,
            toFirestore,
          ).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("Error fetching $collectionName: $e");
      return [];
    }
  }

  Future<List<T>> getCollectionForMonth<T>(
    String collectionName,
    DateTime focusMonth,
    T Function(Map<String, dynamic>, String) fromFirestore,
    Map<String, dynamic> Function(T) toFirestore,
  ) async {
    try {
      final startOfMonth = DateTime(focusMonth.year, focusMonth.month, 1);
      final endOfMonth = DateTime(focusMonth.year, focusMonth.month + 1, 0, 23, 59, 59);

      final snapshot = await _userCollection<T>(
        collectionName,
        fromFirestore,
        toFirestore,
      )
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("Error fetching paginated $collectionName: $e");
      return [];
    }
  }

  Future<void> addDocument<T>(
    String collectionName,
    T data,
    Map<String, dynamic> Function(T) toFirestore,
  ) async {
    if (userId == null) return;
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection(collectionName)
          .add(toFirestore(data));
    } catch (e) {
      print("Error adding document to $collectionName: $e");
      rethrow;
    }
  }

  Future<void> setDocument<T>(
    String collectionName,
    String docId,
    T data,
    T Function(Map<String, dynamic>, String) fromFirestore,
    Map<String, dynamic> Function(T) toFirestore,
  ) async {
    try {
      await _userCollection<T>(
        collectionName,
        fromFirestore,
        toFirestore,
      ).doc(docId).set(toFirestore(data) as T);
    } catch (e) {
      print("Error setting document in $collectionName (ID: $docId): $e");
    }
  }

  Future<void> updateDocument<T>(
    String collectionName,
    String docId,
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>, String) fromFirestore,
    Map<String, dynamic> Function(T) toFirestore,
  ) async {
    try {
      await _userCollection<T>(
        collectionName,
        fromFirestore,
        toFirestore,
      ).doc(docId).update(data);
    } catch (e) {
      print("Error updating document in $collectionName (ID: $docId): $e");
    }
  }

  Future<void> deleteDocument<T>(
    String collectionName,
    String docId,
    T Function(Map<String, dynamic>, String) fromFirestore,
    Map<String, dynamic> Function(T) toFirestore,
  ) async {
    try {
      await _userCollection<T>(
        collectionName,
        fromFirestore,
        toFirestore,
      ).doc(docId).delete();
    } catch (e) {
      print("Error deleting document from $collectionName (ID: $docId): $e");
    }
  }

  // Specific method for daily goals (usually a single document per user)
  Future<DailyGoal?> getDailyGoals() async {
    if (userId == null) return null;
    try {
      final doc =
          await _db
              .collection('users')
              .doc(userId)
              .collection('goals')
              .doc('currentGoals')
              .get();
      if (doc.exists) {
        return DailyGoal.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print("Error fetching daily goals: $e");
      return null;
    }
  }

  Future<void> updateDailyGoals(DailyGoal goals) async {
    if (userId == null) return;
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('goals')
          .doc('currentGoals')
          .set(goals.toFirestore());
    } catch (e) {
      print("Error updating daily goals: $e");
    }
  }

  // User Profile
  Future<UserProfile?> getUserProfile() async {
    if (userId == null) return null;
    try {
      // Get user email from FirebaseAuth
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';

      final doc =
          await _db
              .collection('users')
              .doc(userId)
              .collection('profile')
              .doc('userProfile')
              .get();

      if (doc.exists) {
        var profile = UserProfile.fromFirestore(doc.data()!, doc.id);
        profile.email = email; // Ensure email is up-to-date
        return profile;
      }
      return null;
    } catch (e) {
      print("Error fetching user profile: $e");
      return null;
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    if (userId == null) return;
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('userProfile')
          .set(profile.toFirestore());
    } catch (e) {
      print("Error updating user profile: $e");
    }
  }

  // Onboarding status
  Future<bool> getOnboardingStatus() async {
    if (userId == null) return false;
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.data()?['onboardingComplete'] ?? false;
    } catch (e) {
      print("Error getting onboarding status: $e");
      return false;
    }
  }

  // main.dart

  // ... dans la classe FirestoreService

  Future<void> setOnboardingComplete() async {
    if (userId == null) return;
    try {
      // CORRECTION: Utiliser .set avec merge:true au lieu de .update
      // Cela crÃ©e le document s'il n'existe pas, ou met Ã  jour le champ s'il existe.
      await _db.collection('users').doc(userId).set({
        'onboardingComplete': true,
      }, SetOptions(merge: true));
      print("Onboarding status set to TRUE for user $userId");
    } catch (e) {
      print("Error setting onboarding complete: $e");
      // Il est bon de relancer l'erreur pour que le code appelant puisse la gÃ©rer si nÃ©cessaire
      rethrow;
    }
  }
}

class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  SubscriptionService({required this.userId});

  // Get current subscription status
  Stream<bool> get isPremiumStream {
    return _db
        .collection('users')
        .doc(userId)
        .collection('subscription')
        .doc('status')
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return snapshot.data()?['isPremium'] ?? false;
          }
          return false;
        });
  }

  Future<bool> getIsPremium() async {
    final doc =
        await _db
            .collection('users')
            .doc(userId)
            .collection('subscription')
            .doc('status')
            .get();
    return doc.exists && (doc.data()?['isPremium'] ?? false);
  }

  // Initialize subscription for new users (called on registration)
  Future<void> _initializeSubscription() async {
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('subscription')
        .doc('status');
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'isPremium': false,
        'startDate': FieldValue.serverTimestamp(),
      });
    }
  }

  // Set subscription status (e.g., after purchase)
  Future<void> setPremiumStatus(bool isPremium) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('subscription')
        .doc('status')
        .set({
          'isPremium': isPremium,
          'updateDate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}

class UsageTrackerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;
  int currentStreak = 0;

  // Calcul du bonus : 5 de base + 3 appels supplÃ©mentaires tous les 5 jours de sÃ©rie
  int get deepSeekLimit => 5 + ((currentStreak ~/ 5) * 3);

  UsageTrackerService({required this.userId});

  String _getTodayDocId() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<int> getApiCallCount(String apiType) async {
    final todayDoc =
        await _db
            .collection('users')
            .doc(userId)
            .collection('usageTracking')
            .doc(_getTodayDocId())
            .get();
    if (todayDoc.exists) {
      return (todayDoc.data()?[apiType] ?? 0) as int;
    }
    return 0;
  }

  Future<void> incrementApiCall(String apiType) async {
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('usageTracking')
        .doc(_getTodayDocId());
    await docRef.set({
      apiType: FieldValue.increment(1),
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> getPhotoAnalysisCount() => getApiCallCount('photo_analysis_ia');
  Future<void> incrementPhotoAnalysis() =>
      incrementApiCall('photo_analysis_ia');

  Future<int> getScanAnalysisCount() => getApiCallCount('scan_analysis_ia');
  Future<void> incrementScanAnalysis() => incrementApiCall('scan_analysis_ia');

  Future<int> getDeepSeekApiCallCount() =>
      getApiCallCount('deepseek_api_calls');
  Future<void> incrementDeepSeekApiCall() =>
      incrementApiCall('deepseek_api_calls');
}

// =============================================================================
// MODÃˆLES DE DONNÃ‰ES MIS Ã€ JOUR (avec fromFirestore et toFirestore)
// =============================================================================

const uuid = Uuid();

enum MealType { breakfast, lunch, dinner, snack, unknown }

extension MealTypeExtension on MealType {
  String toCapitalizedString() {
    switch (this) {
      case MealType.breakfast:
        return 'Petit-dÃ©jeuner';
      case MealType.lunch:
        return 'DÃ©jeuner';
      case MealType.dinner:
        return 'DÃ®ner';
      case MealType.snack:
        return 'Collation';
      case MealType.unknown:
        return 'Inconnu';
    }
  }
}

class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final double proteins;
  final double carbs;
  final double fats;
  final DateTime timestamp;
  final MealType mealType;
  final bool isAiEstimated;
  final String? source;

  FoodEntry({
    String? id,
    required this.name,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.timestamp,
    this.mealType = MealType.unknown,
    this.isAiEstimated = false,
    this.source,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'name': name,
    'calories': calories,
    'proteins': proteins,
    'carbs': carbs,
    'fats': fats,
    'timestamp': Timestamp.fromDate(timestamp),
    'mealType': mealType.name,
    'isAiEstimated': isAiEstimated,
    'source': source,
  };

  factory FoodEntry.fromFirestore(Map<String, dynamic> json, String docId) =>
      FoodEntry(
        id: json['id'] ?? docId,
        name: json['name'],
        calories: json['calories'],
        proteins: (json['proteins'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fats: (json['fats'] as num).toDouble(),
        timestamp: (json['timestamp'] as Timestamp).toDate(),
        mealType: MealType.values.firstWhere(
          (e) => e.name == json['mealType'],
          orElse: () => MealType.unknown,
        ),
        isAiEstimated: json['isAiEstimated'],
        source: json['source'],
      );
}

class ScannedProduct {
  final String id;
  final String name;
  final String barcode;
  final String? imageUrl;
  final String? nutriScore;
  final DateTime scannedDate;
  final Map<String, dynamic>? rawData; // Store as Map for flexibility

  ScannedProduct({
    String? id,
    required this.name,
    required this.barcode,
    this.imageUrl,
    this.nutriScore,
    required this.scannedDate,
    this.rawData,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'imageUrl': imageUrl,
    'nutriScore': nutriScore,
    'scannedDate': Timestamp.fromDate(scannedDate),
    'rawData': rawData,
  };

  factory ScannedProduct.fromFirestore(
    Map<String, dynamic> json,
    String docId,
  ) => ScannedProduct(
    id: json['id'] ?? docId,
    name: json['name'],
    barcode: json['barcode'],
    imageUrl: json['imageUrl'],
    nutriScore: json['nutriScore'],
    scannedDate: (json['scannedDate'] as Timestamp).toDate(),
    rawData: json['rawData'] as Map<String, dynamic>?,
  );
}

class FastingSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final String notes;
  final Duration? targetDuration; // New: for tracking if target was met

  FastingSession({
    String? id,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.notes = '',
    this.targetDuration,
  }) : id = id ?? uuid.v4();

  bool get isTargetReached =>
      targetDuration != null && duration >= targetDuration!;

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'startTime': Timestamp.fromDate(startTime),
    'endTime': Timestamp.fromDate(endTime),
    'durationSeconds': duration.inSeconds,
    'notes': notes,
    'targetDurationSeconds': targetDuration?.inSeconds,
  };

  factory FastingSession.fromFirestore(
    Map<String, dynamic> json,
    String docId,
  ) => FastingSession(
    id: json['id'] ?? docId,
    startTime: (json['startTime'] as Timestamp).toDate(),
    endTime: (json['endTime'] as Timestamp).toDate(),
    duration: Duration(seconds: json['durationSeconds']),
    notes: json['notes'],
    targetDuration:
        json['targetDurationSeconds'] != null
            ? Duration(seconds: json['targetDurationSeconds'])
            : null,
  );
}

// NEW: Fasting Program (Premium)
enum FastingProgramType { beginner, regular, expert, custom }

class FastingProgram {
  final String id;
  final String name;
  final FastingProgramType type;
  final String description;
  final List<Duration>
  durationsPerDay; // e.g., [Duration(hours: 16), Duration(hours: 18)] for a week
  final bool isPremium;

  FastingProgram({
    String? id,
    required this.name,
    required this.type,
    required this.description,
    required this.durationsPerDay,
    this.isPremium = false,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'name': name,
    'type': type.name,
    'description': description,
    'durationsPerDaySeconds': durationsPerDay.map((d) => d.inSeconds).toList(),
    'isPremium': isPremium,
  };

  factory FastingProgram.fromFirestore(
    Map<String, dynamic> json,
    String docId,
  ) => FastingProgram(
    id: json['id'] ?? docId,
    name: json['name'],
    type: FastingProgramType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => FastingProgramType.custom,
    ),
    description: json['description'],
    durationsPerDay:
        (json['durationsPerDaySeconds'] as List<dynamic>)
            .map((e) => Duration(seconds: e as int))
            .toList(),
    isPremium: json['isPremium'] ?? false,
  );
}

class DailyGoal {
  int targetCalories;
  double targetProteins;
  double targetCarbs;
  double targetFats;
  double targetWeight;
  String weightGoalType; // 'lose', 'gain', 'maintain'
  double targetWater; // en litres
  Duration? targetFastingDuration;
  double? targetMuscleGain; // NOUVEAU: Objectif de prise de muscle en kg
  double?
  weeklyEnergyExpenditureGoal; // NOUVEAU: DÃ©pense Ã©nergÃ©tique hebdomadaire

  DailyGoal({
    this.targetCalories = 2000,
    this.targetProteins = 100.0,
    this.targetCarbs = 200.0,
    this.targetFats = 60.0,
    this.targetWeight = 70.0,
    this.weightGoalType = 'maintain',
    this.targetWater = 2.0,
    this.targetFastingDuration = const Duration(hours: 16),
    this.targetMuscleGain,
    this.weeklyEnergyExpenditureGoal,
  });

  DailyGoal copyWith({
    int? targetCalories,
    double? targetProteins,
    double? targetCarbs,
    double? targetFats,
    double? targetWeight,
    String? weightGoalType,
    double? targetWater,
    Duration? targetFastingDuration,
    double? targetMuscleGain,
    double? weeklyEnergyExpenditureGoal,
  }) {
    return DailyGoal(
      targetCalories: targetCalories ?? this.targetCalories,
      targetProteins: targetProteins ?? this.targetProteins,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFats: targetFats ?? this.targetFats,
      targetWeight: targetWeight ?? this.targetWeight,
      weightGoalType: weightGoalType ?? this.weightGoalType,
      targetWater: targetWater ?? this.targetWater,
      targetFastingDuration:
          targetFastingDuration ?? this.targetFastingDuration,
      targetMuscleGain: targetMuscleGain ?? this.targetMuscleGain,
      weeklyEnergyExpenditureGoal:
          weeklyEnergyExpenditureGoal ?? this.weeklyEnergyExpenditureGoal,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'targetCalories': targetCalories,
    'targetProteins': targetProteins,
    'targetCarbs': targetCarbs,
    'targetFats': targetFats,
    'targetWeight': targetWeight,
    'weightGoalType': weightGoalType,
    'targetWater': targetWater,
    'targetFastingDurationSeconds': targetFastingDuration?.inSeconds,
    'targetMuscleGain': targetMuscleGain,
    'weeklyEnergyExpenditureGoal': weeklyEnergyExpenditureGoal,
  };

  factory DailyGoal.fromFirestore(Map<String, dynamic> json, String docId) =>
      DailyGoal(
        targetCalories: json['targetCalories'] ?? 2000,
        targetProteins: (json['targetProteins'] as num?)?.toDouble() ?? 100.0,
        targetCarbs: (json['targetCarbs'] as num?)?.toDouble() ?? 200.0,
        targetFats: (json['fats'] as num?)?.toDouble() ?? 60.0,
        targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 70.0,
        weightGoalType: json['weightGoalType'] ?? 'maintain',
        targetWater: (json['targetWater'] as num?)?.toDouble() ?? 2.0,
        targetFastingDuration:
            json['targetFastingDurationSeconds'] != null
                ? Duration(seconds: json['targetFastingDurationSeconds'])
                : const Duration(hours: 16),
        targetMuscleGain: (json['targetMuscleGain'] as num?)?.toDouble(),
        weeklyEnergyExpenditureGoal:
            (json['weeklyEnergyExpenditureGoal'] as num?)?.toDouble(),
      );
}

// NOUVEAU: ModÃ¨le pour l'historique d'un objectif
enum GoalStatus { inProgress, achieved, failed }

class GoalHistoryEntry {
  final String id;
  final String goalType; // 'lose', 'gain', 'maintain'
  final double startWeight;
  final double targetWeight;
  final DateTime startDate;
  final DateTime? endDate;
  final GoalStatus status;

  GoalHistoryEntry({
    String? id,
    required this.goalType,
    required this.startWeight,
    required this.targetWeight,
    required this.startDate,
    this.endDate,
    this.status = GoalStatus.inProgress,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'goalType': goalType,
    'startWeight': startWeight,
    'targetWeight': targetWeight,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'status': status.name,
  };

  factory GoalHistoryEntry.fromMap(Map<String, dynamic> map) =>
      GoalHistoryEntry(
        id: map['id'],
        goalType: map['goalType'],
        startWeight: (map['startWeight'] as num).toDouble(),
        targetWeight: (map['targetWeight'] as num).toDouble(),
        startDate: (map['startDate'] as Timestamp).toDate(),
        endDate:
            map['endDate'] != null
                ? (map['endDate'] as Timestamp).toDate()
                : null,
        status: GoalStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => GoalStatus.inProgress,
        ),
      );
}

class UserProfile {
  String id;
  String? firstName;
  String? lastName;
  String? email;
  int age;
  double weight;
  double height;
  String gender;
  String activityLevel;
  String physicalCondition;
  String fastingExperience;
  List<String> dietaryPreferences;
  List<String> healthConditions;

  // MODIFIÃ‰: Anciens et nouveaux champs pour les habitudes de vie
  int mealsPerDay;
  String dietQuality; // 'saine', 'moyenne', 'peu_saine'
  bool tendsToEatSugary;
  bool tendsToEatSalty;
  int sleepHours;
  String stressLevel;
  String mainMotivation;
  int planStrictness;
  // NOUVEAU: Champs pour les habitudes culinaires
  String? likesCooking; // 'loves', 'likes', 'dislikes'
  String?
  cookingFrequency; // 'daily', 'few_times_week', 'weekends_only', 'rarely'
  String likedSports;
  String dislikedSports;

  double? bodyFatPercentage;
  List<String> availableEquipment;
  bool gymMode;

  List<GoalHistoryEntry> goalHistory;

  UserProfile({
    String? id,
    this.firstName,
    this.lastName,
    this.email,
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.activityLevel,
    this.physicalCondition = 'mince',
    this.fastingExperience = 'beginner',
    this.dietaryPreferences = const [],
    this.healthConditions = const [],
    this.mealsPerDay = 3,
    this.dietQuality = 'moyenne',
    this.tendsToEatSugary = false,
    this.tendsToEatSalty = false,
    this.sleepHours = 7,
    this.stressLevel = 'moderate',
    this.mainMotivation = 'health',
    this.planStrictness = 3,
    // NOUVEAU
    this.likesCooking = 'likes',
    this.cookingFrequency = 'few_times_week',
    this.likedSports = '',
    this.dislikedSports = '',
    this.bodyFatPercentage,
    this.availableEquipment = const [],
    this.gymMode = false,
    this.goalHistory = const [],
  }) : id = id ?? uuid.v4();

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  double get bmi {
    if (height <= 0) return 0;
    return weight / ((height / 100) * (height / 100));
  }

  double? get ffmi {
    if (bodyFatPercentage == null || height <= 0) return null;
    double leanMass = weight * (1 - (bodyFatPercentage! / 100));
    return leanMass / ((height / 100) * (height / 100));
  }

  double? get leanBodyMass {
    if (bodyFatPercentage == null) return null;
    return weight * (1 - (bodyFatPercentage! / 100));
  }

  String get bmiCategory {
    final imcValue = bmi;
    if (imcValue <= 0) return "DonnÃ©es invalides";
    if (imcValue < 18.5) return "Maigreur";
    if (imcValue < 25) return "Poids normal";
    if (imcValue < 30) return "Surpoids";
    if (imcValue < 35) return "ObÃ©sitÃ© modÃ©rÃ©e (Classe I)";
    if (imcValue < 40) return "ObÃ©sitÃ© sÃ©vÃ¨re (Classe II)";
    return "ObÃ©sitÃ© morbide (Classe III)";
  }

  bool get isUnderweight => bmi < 18.5;
  bool get isOverweight => bmi >= 25;
  bool get isObese => bmi >= 30;

  double get minNormalWeight {
    if (height <= 0) return 0;
    return 18.5 * (height / 100) * (height / 100);
  }

  double get maxNormalWeight {
    if (height <= 0) return 0;
    return 24.9 * (height / 100) * (height / 100);
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    int? age,
    double? weight,
    double? height,
    String? gender,
    String? activityLevel,
    String? physicalCondition,
    String? fastingExperience,
    List<String>? dietaryPreferences,
    List<String>? healthConditions,
    int? mealsPerDay,
    String? dietQuality,
    bool? tendsToEatSugary,
    bool? tendsToEatSalty,
    int? sleepHours,
    String? stressLevel,
    String? mainMotivation,
    int? planStrictness,
    // NOUVEAU
    String? likesCooking,
    String? cookingFrequency,
    String? likedSports,
    String? dislikedSports,
    double? bodyFatPercentage,
    List<String>? availableEquipment,
    bool? gymMode,
    List<GoalHistoryEntry>? goalHistory,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      physicalCondition: physicalCondition ?? this.physicalCondition,
      fastingExperience: fastingExperience ?? this.fastingExperience,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      healthConditions: healthConditions ?? this.healthConditions,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      dietQuality: dietQuality ?? this.dietQuality,
      tendsToEatSugary: tendsToEatSugary ?? this.tendsToEatSugary,
      tendsToEatSalty: tendsToEatSalty ?? this.tendsToEatSalty,
      sleepHours: sleepHours ?? this.sleepHours,
      stressLevel: stressLevel ?? this.stressLevel,
      mainMotivation: mainMotivation ?? this.mainMotivation,
      planStrictness: planStrictness ?? this.planStrictness,
      // NOUVEAU
      likesCooking: likesCooking ?? this.likesCooking,
      cookingFrequency: cookingFrequency ?? this.cookingFrequency,
      likedSports: likedSports ?? this.likedSports,
      dislikedSports: dislikedSports ?? this.dislikedSports,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      gymMode: gymMode ?? this.gymMode,
      goalHistory: goalHistory ?? this.goalHistory,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'firstName': firstName,
    'lastName': lastName,
    'age': age,
    'weight': weight,
    'height': height,
    'gender': gender,
    'activityLevel': activityLevel,
    'physicalCondition': physicalCondition,
    'fastingExperience': fastingExperience,
    'dietaryPreferences': dietaryPreferences,
    'healthConditions': healthConditions,
    'mealsPerDay': mealsPerDay,
    'dietQuality': dietQuality,
    'tendsToEatSugary': tendsToEatSugary,
    'tendsToEatSalty': tendsToEatSalty,
    'sleepHours': sleepHours,
    'stressLevel': stressLevel,
    'mainMotivation': mainMotivation,
    'planStrictness': planStrictness,
    // NOUVEAU
    'likesCooking': likesCooking,
    'cookingFrequency': cookingFrequency,
    'likedSports': likedSports,
    'dislikedSports': dislikedSports,
    if (bodyFatPercentage != null) 'bodyFatPercentage': bodyFatPercentage,
    'availableEquipment': availableEquipment,
    'gymMode': gymMode,
    'goalHistory': goalHistory.map((e) => e.toMap()).toList(),
  };

  factory UserProfile.fromFirestore(Map<String, dynamic> json, String docId) =>
      UserProfile(
        id: json['id'] ?? docId,
        firstName: json['firstName'],
        lastName: json['lastName'],
        age: json['age'] ?? 25,
        weight: (json['weight'] as num?)?.toDouble() ?? 70.0,
        height: (json['height'] as num?)?.toDouble() ?? 170.0,
        gender: json['gender'] ?? 'male',
        activityLevel: json['activityLevel'] ?? 'moderate',
        physicalCondition: json['physicalCondition'] ?? 'mince',
        fastingExperience: json['fastingExperience'] ?? 'beginner',
        dietaryPreferences: List<String>.from(json['dietaryPreferences'] ?? []),
        healthConditions: List<String>.from(json['healthConditions'] ?? []),
        availableEquipment: List<String>.from(json['availableEquipment'] ?? []),
        gymMode: json['gymMode'] ?? false,
        mealsPerDay: json['mealsPerDay'] ?? 3,
        dietQuality: json['dietQuality'] ?? 'moyenne',
        tendsToEatSugary: json['tendsToEatSugary'] ?? false,
        tendsToEatSalty: json['tendsToEatSalty'] ?? false,
        sleepHours: json['sleepHours'] ?? 7,
        stressLevel: json['stressLevel'] ?? 'moderate',
        mainMotivation: json['mainMotivation'] ?? 'health',
        planStrictness: json['planStrictness'] ?? 3,
        // NOUVEAU
        likesCooking: json['likesCooking'] ?? 'likes',
        cookingFrequency: json['cookingFrequency'] ?? 'few_times_week',
        likedSports: json['likedSports'] ?? '',
        dislikedSports: json['dislikedSports'] ?? '',
        bodyFatPercentage: (json['bodyFatPercentage'] as num?)?.toDouble(),
        goalHistory:
            (json['goalHistory'] as List<dynamic>?)
                ?.map((e) => GoalHistoryEntry.fromMap(e))
                .toList() ??
            [],
      );
}

class SetNewGoalScreen extends StatefulWidget {
  final UserProfile userProfile;
  final DailyGoal currentGoals;
  final FirestoreService firestoreService;
  final VoidCallback onGoalSet;

  const SetNewGoalScreen({
    super.key,
    required this.userProfile,
    required this.currentGoals,
    required this.firestoreService,
    required this.onGoalSet,
  });

  @override
  State<SetNewGoalScreen> createState() => _SetNewGoalScreenState();
}

class _SetNewGoalScreenState extends State<SetNewGoalScreen> {
  late String _goalType;
  late double _targetWeight;
  final _formKey = GlobalKey<FormState>();
  final _targetWeightController = TextEditingController();

  String? _recommendationMessage;

  @override
  void initState() {
    super.initState();
    // Recommandation intelligente pour le prochain objectif
    if (widget.userProfile.isOverweight) {
      _goalType = 'lose';
      _targetWeight =
          widget.userProfile.weight * 0.95; // Proposer une perte de 5%
    } else {
      _goalType = 'maintain';
      _targetWeight = widget.userProfile.weight;
    }
    _targetWeightController.text = _targetWeight.toStringAsFixed(1);
    _validateTargetWeight(_targetWeightController.text);
  }

  void _validateTargetWeight(String value) {
    final target = double.tryParse(value);
    if (target == null) return;

    setState(() {
      _recommendationMessage = null; // Reset
      final currentBmi = widget.userProfile.bmi;
      final targetBmi =
          target /
          ((widget.userProfile.height / 100) *
              (widget.userProfile.height / 100));

      if (currentBmi >= 30 && targetBmi < 25) {
        // ObÃ©sitÃ© -> Normal
        _recommendationMessage =
            "C'est un super objectif ! Pour y arriver plus sereinement, que diriez-vous de viser d'abord le seuil de surpoids (autour de ${widget.userProfile.maxNormalWeight.toStringAsFixed(1)} kg) ?";
      } else if (currentBmi >= 25 && targetBmi < 18.5) {
        // Surpoids -> Maigreur
        _recommendationMessage =
            "Attention, cet objectif vous placerait en situation de maigreur. Il serait plus prudent de viser le bas de la fourchette de poids normal (autour de ${widget.userProfile.minNormalWeight.toStringAsFixed(1)} kg).";
      }
    });
  }

  Future<void> _saveNewGoal() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final updatedHistory = List<GoalHistoryEntry>.from(
      widget.userProfile.goalHistory,
    );
    // On archive l'ancien objectif
    final lastGoalIndex = updatedHistory.lastIndexWhere(
      (g) => g.status == GoalStatus.achieved,
    );
    if (lastGoalIndex != -1) {
      // L'ancien objectif est dÃ©jÃ  marquÃ© comme 'achieved', pas besoin de le modifier.
    }

    // On crÃ©e le nouvel objectif
    final newGoal = GoalHistoryEntry(
      goalType: _goalType,
      startWeight: widget.userProfile.weight,
      targetWeight: _targetWeight,
      startDate: DateTime.now(),
    );
    updatedHistory.add(newGoal);

    final updatedProfile = widget.userProfile.copyWith(
      goalHistory: updatedHistory,
    );
    final updatedGoals = widget.currentGoals.copyWith(
      weightGoalType: _goalType,
      targetWeight: _targetWeight,
    );

    try {
      await widget.firestoreService.updateUserProfile(updatedProfile);
      await widget.firestoreService.updateDailyGoals(updatedGoals);
      widget.onGoalSet(); // RafraÃ®chit les donnÃ©es dans l'app
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nouvel objectif dÃ©fini ! En route vers le succÃ¨s !"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DÃ©finir un nouvel objectif')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'FÃ©licitations pour votre progression ! Quel est votre prochain dÃ©fi ?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              DropdownButtonFormField<String>(
                initialValue: _goalType,
                decoration: const InputDecoration(
                  labelText: 'Mon prochain objectif',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'lose',
                    child: Text('Perdre du poids'),
                  ),
                  DropdownMenuItem(
                    value: 'maintain',
                    child: Text('Maintenir mon poids'),
                  ),
                  DropdownMenuItem(
                    value: 'gain',
                    child: Text('Prendre du muscle'),
                  ),
                ],
                onChanged: (v) => setState(() => _goalType = v!),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _targetWeightController,
                decoration: const InputDecoration(
                  labelText: 'Poids Cible (kg)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: _validateTargetWeight,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ requis.';
                  final target = double.tryParse(v);
                  if (target == null) return 'Valeur invalide.';
                  if (_goalType == 'lose' &&
                      target >= widget.userProfile.weight) {
                    return 'La cible doit Ãªtre infÃ©rieure Ã  votre poids actuel.';
                  }
                  if (_goalType == 'gain' &&
                      target <= widget.userProfile.weight) {
                    return 'La cible doit Ãªtre supÃ©rieure Ã  votre poids actuel.';
                  }
                  return null;
                },
                onSaved: (v) => _targetWeight = double.parse(v!),
              ),
              if (_recommendationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      _recommendationMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blue.shade800),
                    ),
                  ),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveNewGoal,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Valider et continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MealPlanEntry {
  final String id;
  final DateTime date;
  final MealType mealType;
  final String mealName;
  final String description;
  final int estimatedCalories;
  final double estimatedProteins;
  final double estimatedCarbs;
  final double estimatedFats;
  final String? imageUrl;
  final String? recipeInstructions;
  final int? prepTime;
  final List<String>? utensils;
  final List<String>? ingredients;
  final String source;

  MealPlanEntry({
    String? id,
    required this.date,
    required this.mealType,
    required this.mealName,
    this.description = '',
    this.estimatedCalories = 0,
    this.estimatedProteins = 0.0,
    this.estimatedCarbs = 0.0,
    this.estimatedFats = 0.0,
    this.imageUrl,
    this.recipeInstructions,
    this.prepTime,
    this.utensils,
    this.ingredients,
    this.source = 'IA',
  }) : id = id ?? uuid.v4();

  FoodEntry toFoodEntry() {
    return FoodEntry(
      name: mealName,
      calories: estimatedCalories,
      proteins: estimatedProteins,
      carbs: estimatedCarbs,
      fats: estimatedFats,
      timestamp: date,
      mealType: mealType,
      isAiEstimated: true,
      source: source,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'date': Timestamp.fromDate(date),
    'mealType': mealType.name,
    'mealName': mealName,
    'description': description,
    'estimatedCalories': estimatedCalories,
    'estimatedProteins': estimatedProteins,
    'estimatedCarbs': estimatedCarbs,
    'estimatedFats': estimatedFats,
    'imageUrl': imageUrl,
    'recipeInstructions': recipeInstructions,
    'prepTime': prepTime,
    'utensils': utensils,
    'ingredients': ingredients,
    'source': source,
  };

  factory MealPlanEntry.fromFirestore(
    Map<String, dynamic> json,
    String docId,
  ) => MealPlanEntry(
    id: json['id'] ?? docId,
    date: (json['date'] as Timestamp).toDate(),
    mealType: MealType.values.firstWhere(
      (e) => e.name == json['mealType'],
      orElse: () => MealType.unknown,
    ),
    mealName: json['mealName'],
    description: json['description'] ?? '',
    estimatedCalories: json['estimatedCalories'] ?? 0,
    estimatedProteins: (json['estimatedProteins'] as num?)?.toDouble() ?? 0.0,
    estimatedCarbs: (json['estimatedCarbs'] as num?)?.toDouble() ?? 0.0,
    estimatedFats: (json['estimatedFats'] as num?)?.toDouble() ?? 0.0,
    imageUrl: json['imageUrl'],
    recipeInstructions: json['recipeInstructions'],
    prepTime: json['prepTime'] as int?,
    utensils:
        (json['utensils'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    ingredients:
        (json['ingredients'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
    source: json['source'] ?? 'IA',
  );
}

class ActivityEntry {
  final String id;
  final String description;
  final double caloriesBurned;
  final Duration duration;
  final String activityType;
  final DateTime timestamp;
  final bool isAiEstimated;

  ActivityEntry({
    String? id,
    required this.description,
    required this.caloriesBurned,
    required this.duration,
    required this.activityType,
    required this.timestamp,
    this.isAiEstimated = false,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'description': description,
    'caloriesBurned': caloriesBurned,
    'durationSeconds': duration.inSeconds,
    'activityType': activityType,
    'timestamp': Timestamp.fromDate(timestamp),
    'isAiEstimated': isAiEstimated,
  };

  factory ActivityEntry.fromFirestore(
    Map<String, dynamic> json,
    String docId,
  ) => ActivityEntry(
    id: json['id'] ?? docId,
    description: json['description'],
    caloriesBurned: (json['caloriesBurned'] as num).toDouble(),
    duration: Duration(seconds: json['durationSeconds']),
    activityType: json['activityType'],
    timestamp: (json['timestamp'] as Timestamp).toDate(),
    isAiEstimated: json['isAiEstimated'],
  );
}

class WeightEntry {
  final String id;
  final DateTime date;
  final double weight; // en kg

  WeightEntry({String? id, required this.date, required this.weight})
    : id = id ?? uuid.v4();

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'date': Timestamp.fromDate(date),
    'weight': weight,
  };

  factory WeightEntry.fromFirestore(Map<String, dynamic> json, String docId) =>
      WeightEntry(
        id: json['id'] ?? docId,
        date: (json['date'] as Timestamp).toDate(),
        weight: (json['weight'] as num).toDouble(),
      );
}

class WaterEntry {
  final String id;
  final DateTime timestamp;
  final double amount; // en litres

  WaterEntry({String? id, required this.timestamp, required this.amount})
    : id = id ?? uuid.v4();

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'timestamp': Timestamp.fromDate(timestamp),
    'amount': amount,
  };

  factory WaterEntry.fromFirestore(Map<String, dynamic> json, String docId) =>
      WaterEntry(
        id: json['id'] ?? docId,
        timestamp: (json['timestamp'] as Timestamp).toDate(),
        amount: (json['amount'] as num).toDouble(),
      );
}

class UserTab {
  final String id;
  final String title;
  final IconData icon;
  final WidgetBuilder builder; // Builder function for the tab content
  bool isVisible;

  UserTab({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    this.isVisible = true,
  });

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'title': title,
    'iconCodePoint': icon.codePoint,
    'isVisible': isVisible,
  };

  factory UserTab.fromFirestore(
    Map<String, dynamic> json,
    String docId,
    Map<String, WidgetBuilder> availableBuilders,
  ) {
    if (!availableBuilders.containsKey(json['id'])) {
      throw Exception(
        "Builder for tab ID '${json['id']}' not found. Cannot restore tab.",
      );
    }
    return UserTab(
      id: json['id'] ?? docId,
      title: json['title'],
      icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
      builder: availableBuilders[json['id']]!,
      isVisible: json['isVisible'] ?? true,
    );
  }

  UserTab copyWith({
    bool? isVisible,
    String? id,
    String? title,
    IconData? icon,
    WidgetBuilder? builder,
  }) {
    return UserTab(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      builder: builder ?? this.builder,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

// =============================================================================
// AUTHENTIFICATION & WRAPPER
// =============================================================================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            // Si l'utilisateur n'est pas connectÃ©, il va Ã  l'Ã©cran de connexion/inscription.
            return const AuthScreen();
          } else {
            // Si l'utilisateur est connectÃ©, il va DIRECTEMENT Ã  l'application.
            return ChangeNotifierProvider<AppStateProvider>(
              create:
                  (_) => AppStateProvider(FirestoreService(userId: user.uid)),
              child: MyAppTabsWrapper(userId: user.uid),
            );
          }
        }
        // Pendant le chargement initial, on affiche un indicateur de progression.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _errorMessage = '';
  // SUPPRIMÃ‰: La variable _isLogin n'est plus nÃ©cessaire, cet Ã©cran ne gÃ¨re que la connexion.
  bool _isLoading = false;

  // CORRECTION: La fonction ne gÃ¨re plus que la connexion.
  // Dans main.dart, Ã  l'intÃ©rieur de class _AuthScreenState

  void _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. On tente la connexion
      UserCredential? userCredential = await _auth.signInWithEmailAndPassword(
        _email,
        _password,
      );

      // 2. Si Ã§a rÃ©ussit et que le widget est toujours affichÃ©
      if (userCredential != null && userCredential.user != null && mounted) {
        // IMPORTANT : On signale que l'onboarding est fini (pour les prochaines ouvertures d'app)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboardingCompleted', true);

        // 3. ON FORCE LA NAVIGATION vers l'Ã©cran principal
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (context) => ChangeNotifierProvider<AppStateProvider>(
                  create:
                      (_) => AppStateProvider(
                        FirestoreService(userId: userCredential.user!.uid),
                      ),
                  child: MyAppTabsWrapper(userId: userCredential.user!.uid),
                ),
          ),
          (route) =>
              false, // Ceci supprime tous les Ã©crans prÃ©cÃ©dents (login, onboarding) de l'historique
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'Aucun compte trouvÃ© pour cet email. VÃ©rifiez votre adresse.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Mot de passe incorrect. VÃ©rifiez vos identifiants.';
          break;
        case 'invalid-email':
          msg = 'Adresse email invalide.';
          break;
        case 'user-disabled':
          msg = 'Ce compte a Ã©tÃ© dÃ©sactivÃ©. Contactez le support.';
          break;
        case 'too-many-requests':
          msg = 'Trop de tentatives. Veuillez rÃ©essayer dans quelques minutes.';
          break;
        default:
          msg =
              e.message ??
              'Une erreur est survenue. VÃ©rifiez vos identifiants.';
      }
      setState(() {
        _errorMessage = msg;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Une erreur inattendue est survenue: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // CORRECTION: Le titre est maintenant fixe.
        title: const Text('Connexion'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      // CORRECTION: Le titre est maintenant fixe.
                      'Bienvenue',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Les champs prÃ©nom/nom ont dÃ©jÃ  Ã©tÃ© retirÃ©s, ce qui est correct.
                    TextFormField(
                      key: const ValueKey('email'),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Adresse E-mail',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !value.contains('@')) {
                          return 'Veuillez entrer une adresse e-mail valide.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _email = value!.trim();
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('password'),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractÃ¨res.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _password = value!;
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: _submitAuthForm,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          // CORRECTION: Le texte du bouton est maintenant fixe.
                          child: const Text('Se connecter'),
                        ),
                    const SizedBox(height: 10),
                    TextButton(
                      // CORRECTION MAJEURE: Le bouton navigue directement vers l'onboarding.
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const OnboardingFlowScreen(),
                          ),
                        );
                      },
                      // CORRECTION: Le texte du bouton est maintenant fixe.
                      child: const Text('Pas encore de compte ? S\'inscrire'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyAppTabsWrapper extends StatefulWidget {
  final String userId;

  const MyAppTabsWrapper({super.key, required this.userId});

  @override
  State<MyAppTabsWrapper> createState() => _MyAppTabsWrapperState();
}

class _MyAppTabsWrapperState extends State<MyAppTabsWrapper>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _tabsInitialized = false;
  bool _tabsLoading = true;

  // Firebase Services
  late FirestoreService _firestoreService;
  late SubscriptionService _subscriptionService;
  late UsageTrackerService _usageTrackerService;

  // Global state for the app (fetched from Firebase)
  List<FoodEntry> _allFoodEntries = [];
  List<FastingSession> _allFastingSessions = [];
  List<ScannedProduct> _allScannedProducts = [];
  DailyGoal _currentGoals = DailyGoal();
  List<MealPlanEntry> _mealPlans = [];
  List<ActivityEntry> _allActivities = [];
  List<WeightEntry> _allWeightEntries = [];
  List<WaterEntry> _allWaterEntries = [];
  UserProfile? _userProfile; // NEW: User Profile
  bool _isPremium = false; // Subscription status
  int _currentStreak = 0;

  // NOUVEAU: Liste dynamique des onglets
  List<UserTab> _userTabs = [];

  // Map des builders disponibles (pour recrÃ©er les onglets Ã  partir de Firestore)
  late Map<String, WidgetBuilder> _availableTabBuilders;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService(userId: widget.userId);
    _subscriptionService = SubscriptionService(userId: widget.userId);
    _usageTrackerService = UsageTrackerService(userId: widget.userId);

    _initializeAppData();

    // Listen to subscription changes
    _subscriptionService.isPremiumStream.listen((isPremium) {
      if (mounted) {
        setState(() {
          _isPremium = isPremium;
        });
      }
    });
  }

  // --- Gestionnaires d'Ã©tat pour les listes (avec Firebase) ---
  Future<void> _addFoodEntry(FoodEntry entry) async {
    await _firestoreService.addDocument(
      'foodEntries',
      entry,
      (e) => e.toFirestore(),
    );
    await _loadFoodEntries(); // Reload data

    // NOUVEAU : Analyse "Juste-Ã -Temps" par l'IA locale
    await SL.expertSystem.analyzeMealForSpike(entry.carbs);
    await SL.habitService.recordMealTime(entry.name, DateTime.now());

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${entry.name}" ajoutÃ© au suivi.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteFoodEntry(String id) async {
    await _firestoreService.deleteDocument(
      'foodEntries',
      id,
      FoodEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    await _loadFoodEntries();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Aliment supprimÃ©."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _addFastingSession(FastingSession session) async {
    await _firestoreService.addDocument(
      'fastingSessions',
      session,
      (s) => s.toFirestore(),
    );
    await _loadFastingSessions();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session de jeÃ»ne enregistrÃ©e !"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteFastingSession(String id) async {
    await _firestoreService.deleteDocument(
      'fastingSessions',
      id,
      FastingSession.fromFirestore,
      (s) => s.toFirestore(),
    );
    await _loadFastingSessions();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Session de jeÃ»ne supprimÃ©e."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _addScannedProduct(ScannedProduct product) async {
    await _firestoreService.addDocument(
      'scannedProducts',
      product,
      (p) => p.toFirestore(),
    );
    await _loadScannedProducts();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${product.name}" ajoutÃ© Ã  l\'historique des scans.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _deleteScannedProduct(String id) async {
    await _firestoreService.deleteDocument(
      'scannedProducts',
      id,
      ScannedProduct.fromFirestore,
      (p) => p.toFirestore(),
    );
    await _loadScannedProducts();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Produit scannÃ© supprimÃ©."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _addMealPlanEntry(MealPlanEntry entry) async {
    await _firestoreService.addDocument(
      'mealPlans',
      entry,
      (e) => e.toFirestore(),
    );
    await _loadMealPlans();
  }

  Future<void> _deleteMealPlanEntry(String id) async {
    await _firestoreService.deleteDocument(
      'mealPlans',
      id,
      MealPlanEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    await _loadMealPlans();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Repas planifiÃ© supprimÃ©."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _addActivityEntry(ActivityEntry entry) async {
    await _firestoreService.addDocument(
      'activities',
      entry,
      (e) => e.toFirestore(),
    );
    await _loadActivities();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ActivitÃ© "${entry.description}" ajoutÃ©e.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _updateAndGetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastLoginStr = prefs.getString('lastLoginDate');
    int streak = prefs.getInt('loginStreak') ?? 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastLoginStr != null) {
      final lastLogin = DateTime.parse(lastLoginStr);
      final difference = today.difference(lastLogin).inDays;

      if (difference == 1) {
        streak += 1; // Jour consÃ©cutif
      } else if (difference > 1) {
        streak = 1; // SÃ©rie brisÃ©e, on rÃ©initialise Ã  1
      }
      // Si difference == 0, l'utilisateur s'est dÃ©jÃ  connectÃ© aujourd'hui, on ne change rien.
    } else {
      streak = 1; // PremiÃ¨re connexion
    }

    await prefs.setString('lastLoginDate', today.toIso8601String());
    await prefs.setInt('loginStreak', streak);

    if (mounted) {
      setState(() {
        _currentStreak = streak;
      });
    }

    _usageTrackerService.currentStreak = streak;
  }

  Future<void> _syncHealthData() async {
    try {
      final hasPermissions = await SL.activityService.requestPermissions();
      if (!hasPermissions) return;

      final steps = await SL.activityService.getTodaySteps();
      if (steps <= 0) return;

      final bool stepEntryExists = _allActivities.any(
        (a) =>
            isSameDay(a.timestamp, DateTime.now()) &&
            a.activityType == 'Marche_Auto',
      );

      if (stepEntryExists) return;

      final double caloriesFromSteps = steps * 0.04;
      final stepActivity = ActivityEntry(
        description: 'Marche quotidienne ($steps pas)',
        caloriesBurned: caloriesFromSteps,
        duration: Duration(minutes: (steps / 100).round()),
        activityType: 'Marche_Auto',
        timestamp: DateTime.now(),
        isAiEstimated: false,
      );
      await _addActivityEntry(stepActivity);
    } catch (e) {
      debugPrint('Erreur de synchronisation Health/Google Fit: $e');
    }
  }

  Future<void> _deleteActivityEntry(String id) async {
    await _firestoreService.deleteDocument(
      'activities',
      id,
      ActivityEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    await _loadActivities();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("ActivitÃ© supprimÃ©e."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _addWeightEntry(WeightEntry entry) async {
    final existingEntry = _allWeightEntries.firstWhereOrNull(
      (e) => isSameDay(e.date, entry.date),
    );
    if (existingEntry != null) {
      await _firestoreService.setDocument(
        'weightEntries',
        existingEntry.id,
        entry,
        WeightEntry.fromFirestore,
        (e) => e.toFirestore(),
      );
    } else {
      await _firestoreService.addDocument(
        'weightEntries',
        entry,
        (e) => e.toFirestore(),
      );
    }
    await _loadWeightEntries();

    // NOUVEAU: Appel Ã  la vÃ©rification d'objectif aprÃ¨s l'enregistrement
    _checkGoalAchievement(entry.weight);

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Poids de ${entry.weight.toStringAsFixed(1)} kg enregistrÃ©.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // AJOUTEZ ces nouvelles mÃ©thodes dans la classe _MyAppTabsWrapperState
  void _checkGoalAchievement(double newWeight) {
    if (_userProfile == null) return;

    final inProgressGoal = _userProfile!.goalHistory.firstWhereOrNull(
      (g) => g.status == GoalStatus.inProgress,
    );
    if (inProgressGoal == null) return;

    bool goalAchieved = false;
    if (inProgressGoal.goalType == 'lose' &&
        newWeight <= inProgressGoal.targetWeight) {
      goalAchieved = true;
    } else if (inProgressGoal.goalType == 'gain' &&
        newWeight >= inProgressGoal.targetWeight) {
      goalAchieved = true;
    }

    if (goalAchieved) {
      final updatedHistory = List<GoalHistoryEntry>.from(
        _userProfile!.goalHistory,
      );
      final index = updatedHistory.indexWhere((g) => g.id == inProgressGoal.id);
      if (index != -1) {
        updatedHistory[index] = GoalHistoryEntry(
          id: inProgressGoal.id,
          goalType: inProgressGoal.goalType,
          startWeight: inProgressGoal.startWeight,
          targetWeight: inProgressGoal.targetWeight,
          startDate: inProgressGoal.startDate,
          endDate: DateTime.now(),
          status: GoalStatus.achieved,
        );

        final updatedProfile = _userProfile!.copyWith(
          goalHistory: updatedHistory,
        );

        _firestoreService.updateUserProfile(updatedProfile).then((_) {
          _loadUserProfile(); // Recharger le profil pour que l'UI soit Ã  jour
          _showGoalAchievedDialog();
        });
      }
    }
  }

  Future<void> _showGoalAchievedDialog() async {
    // S'assurer que le contexte est toujours valide
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text('ðŸŽ‰ FÃ©licitations ! ðŸŽ‰'),
            content: const Text(
              'Vous avez atteint votre objectif. Continuez sur cette lancÃ©e !',
            ),
            actions: [
              ElevatedButton(
                child: const Text('Poursuivre mes efforts'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _proposeNewGoal();
                },
              ),
            ],
          ),
    );
  }

  void _proposeNewGoal() {
    if (!mounted || _userProfile == null) return;

    // Affiche le nouvel Ã©cran minimaliste au lieu de l'Ã©cran de profil complet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SetNewGoalScreen(
              userProfile: _userProfile!,
              currentGoals: _currentGoals,
              firestoreService: _firestoreService,
              onGoalSet:
                  _onUserProfileUpdated, // La fonction de rafraÃ®chissement est passÃ©e en callback
            ),
      ),
    );
  }

  Future<void> _deleteWeightEntry(String id) async {
    await _firestoreService.deleteDocument(
      'weightEntries',
      id,
      WeightEntry.fromFirestore,
      (w) => w.toFirestore(),
    );
    await _loadWeightEntries();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Poids supprimÃ©."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _addWaterEntry(WaterEntry entry) async {
    await _firestoreService.addDocument(
      'waterEntries',
      entry,
      (e) => e.toFirestore(),
    );
    await _loadWaterEntries();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.amount.toStringAsFixed(1)} L d\'eau ajoutÃ©s.'),
        backgroundColor: Colors.lightBlue,
      ),
    );
  }

  Future<void> _handleScanProduct(String source) async {
    // 1. On attend une List<String> au lieu d'un String
    final List<String>? scannedBarcodes = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );

    if (scannedBarcodes == null || scannedBarcodes.isEmpty) return;

    // 2. Si un seul produit a Ã©tÃ© scannÃ©, comportement classique
    if (scannedBarcodes.length == 1) {
      bool canScan = _isPremium;
      if (!canScan) {
        final count = await _usageTrackerService.getScanAnalysisCount();
        if (count < UserLimits.freeScanAnalysisPerDay) {
          canScan = true;
          await _usageTrackerService.incrementScanAnalysis();
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Limite de 5 scans IA atteinte (Free). Passez Premium !",
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ProductDetailPage(
                barcode: scannedBarcodes.first,
                onProductScanned: _addScannedProduct,
                onAddFoodEntry: _addFoodEntry,
                isPremiumUser: _isPremium,
                usageTrackerService: _usageTrackerService,
              ),
        ),
      );
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Traitement de ${scannedBarcodes.length} produits en arriÃ¨re-plan...",
          ),
          backgroundColor: Colors.teal,
        ),
      );
      // Ici, tu pourras plus tard boucler sur scannedBarcodes pour les ajouter Ã  un inventaire.
    }
  }

  // --- Fonctions de chargement des donnÃ©es depuis Firestore ---
  DateTime _selectedFoodMonth = DateTime.now();

  Future<void> _loadFoodEntries() async {
    await _loadFoodEntriesForMonth(_selectedFoodMonth);
  }

  Future<void> _loadFoodEntriesForMonth(DateTime month) async {
    _selectedFoodMonth = DateTime(month.year, month.month, 1);
    final entries = await _firestoreService.getCollectionForMonth<FoodEntry>(
      'foodEntries',
      _selectedFoodMonth,
      FoodEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    if (mounted) setState(() => _allFoodEntries = entries);
  }

  Future<void> _loadFastingSessions() async {
    final sessions = await _firestoreService.getCollection<FastingSession>(
      'fastingSessions',
      FastingSession.fromFirestore,
      (s) => s.toFirestore(),
    );
    if (mounted) setState(() => _allFastingSessions = sessions);
  }

  Future<void> _loadScannedProducts() async {
    final products = await _firestoreService.getCollection<ScannedProduct>(
      'scannedProducts',
      ScannedProduct.fromFirestore,
      (p) => p.toFirestore(),
    );
    if (mounted) setState(() => _allScannedProducts = products);
  }

  Future<void> _loadDailyGoals() async {
    final goals = await _firestoreService.getDailyGoals();
    if (goals != null) {
      if (mounted) setState(() => _currentGoals = goals);
    } else {
      await _firestoreService.updateDailyGoals(_currentGoals);
    }
  }

  Future<void> _loadMealPlans() async {
    final plans = await _firestoreService.getCollection<MealPlanEntry>(
      'mealPlans',
      MealPlanEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    if (mounted) setState(() => _mealPlans = plans);
  }

  Future<void> _loadActivities() async {
    final activities = await _firestoreService.getCollection<ActivityEntry>(
      'activities',
      ActivityEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    if (mounted) setState(() => _allActivities = activities);
  }

  Future<void> _loadWeightEntries() async {
    final weightEntries = await _firestoreService.getCollection<WeightEntry>(
      'weightEntries',
      WeightEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    if (mounted) setState(() => _allWeightEntries = weightEntries);
  }

  Future<void> _loadWaterEntries() async {
    final waterEntries = await _firestoreService.getCollection<WaterEntry>(
      'waterEntries',
      WaterEntry.fromFirestore,
      (e) => e.toFirestore(),
    );
    if (mounted) setState(() => _allWaterEntries = waterEntries);
  }

  Future<void> _loadUserProfile() async {
    final profile = await _firestoreService.getUserProfile();
    if (profile != null) {
      if (mounted) setState(() => _userProfile = profile);
    } else {
      final defaultProfile = UserProfile(
        age: 25,
        weight: 70.0,
        height: 170.0,
        gender: 'male',
        activityLevel: 'moderate',
      );
      await _firestoreService.updateUserProfile(defaultProfile);
      if (mounted) setState(() => _userProfile = defaultProfile);
    }
  }

  // NOUVEAU: Initialisation des onglets par dÃ©faut
  List<UserTab> _getDefaultTabs() {
    return [
      UserTab(
        id: 'dashboard',
        title: 'Tableau de Bord',
        icon: Icons.dashboard,
        builder:
            (context) => DashboardTab(
              allFoodEntries: _allFoodEntries,
              allFastingSessions: _allFastingSessions,
              currentGoals: _currentGoals,
              allScannedProducts: _allScannedProducts,
              allActivities: _allActivities,
              allWeightEntries: _allWeightEntries,
              allWaterEntries: _allWaterEntries,
              addWaterEntry: _addWaterEntry,
              onScanProduct: _handleScanProduct,
              onMonthChanged: (selectedMonth) async {
                await _loadFoodEntriesForMonth(selectedMonth);
              },
              onViewScanHistory: () {
                if (_tabController != null &&
                    _userTabs.any((tab) => tab.id == 'scan_history')) {
                  final visibleTabs =
                      _userTabs.where((tab) => tab.isVisible).toList();
                  final index = visibleTabs.indexWhere(
                    (tab) => tab.id == 'scan_history',
                  );
                  if (index != -1) _tabController!.animateTo(index);
                }
              },
              foodEntriesCount: _allFoodEntries.length,
              activityEntriesCount: _allActivities.length,
              userProfile: _userProfile,
              isPremiumUser: _isPremium,
              usageTrackerService: _usageTrackerService,
            ),
      ),
      UserTab(
        id: 'calories',
        title: 'Calories',
        icon: Icons.timeline,
        builder:
            (context) => CaloriesTab(
              foodLog: _allFoodEntries,
              scannedProductsHistory: _allScannedProducts,
              addFoodEntry: _addFoodEntry,
              deleteFoodEntry: _deleteFoodEntry,
              onScanProduct: _handleScanProduct,
              isPremiumUser: _isPremium,
              usageTrackerService: _usageTrackerService,
            ),
      ),
      UserTab(
        id: 'fasting',
        title: 'JeÃ»ne',
        icon: Icons.watch_later_outlined,
        builder:
            (context) =>
                _userProfile == null
                    ? const Center(child: CircularProgressIndicator())
                    : FastingTab(
                      fastingHistory: _allFastingSessions,
                      addFastingSession: _addFastingSession,
                      deleteFastingSession: _deleteFastingSession,
                      isPremiumUser: _isPremium,
                      currentGoals: _currentGoals,
                      firestoreService: _firestoreService,
                      userProfile: _userProfile!,
                    ),
      ),
      UserTab(
        id: 'activities',
        title: 'ActivitÃ©s',
        icon: Icons.fitness_center,
        builder:
            (context) => ActivitiesTab(
              activities: _allActivities,
              addActivity: _addActivityEntry,
              deleteActivity: _deleteActivityEntry,
              isPremiumUser: _isPremium,
              usageTrackerService: _usageTrackerService,
              userProfile: _userProfile,
              currentGoals: _currentGoals,
            ),
      ),
      UserTab(
        id: 'evolution',
        title: 'Ã‰volution',
        icon: Icons.show_chart,
        builder:
            (context) => EvolutionTab(
              allWeightEntries: _allWeightEntries,
              addWeightEntry: _addWeightEntry,
              deleteWeightEntry: _deleteWeightEntry,
              currentGoals: _currentGoals,
              isPremiumUser: _isPremium,
              usageTrackerService: _usageTrackerService,
              // PARAMÃˆTRES CORRIGÃ‰S
              userProfile: _userProfile,
              allFoodEntries: _allFoodEntries,
            ),
      ),
      UserTab(
        id: 'scan_history',
        title: 'Historique Scans',
        icon: Icons.qr_code_scanner,
        builder:
            (context) => ScanHistoryTab(
              scannedProducts: _allScannedProducts,
              deleteScannedProduct: _deleteScannedProduct,
              onRescanProduct: _handleScanProduct,
            ),
      ),
      UserTab(
        id: 'menu_planning',
        title: 'Menus & IA',
        icon: Icons.restaurant_menu,
        builder:
            (context) =>
                _userProfile == null
                    ? const Center(child: CircularProgressIndicator())
                    : MenuPlanningTab(
                      mealPlans: _mealPlans,
                      addMealPlanEntry: _addMealPlanEntry,
                      deleteMealPlanEntry: _deleteMealPlanEntry,
                      addFoodEntryToTracker: _addFoodEntry,
                      currentGoals: _currentGoals,
                      isPremiumUser: _isPremium,
                      usageTrackerService: _usageTrackerService,
                      userProfile: _userProfile!,
                    ),
      ),
      UserTab(
        id: 'subscription',
        title: 'Abonnement',
        icon: Icons.workspace_premium,
        builder:
            (context) => SubscriptionPage(
              isPremiumUser: _isPremium,
              subscriptionService: _subscriptionService,
              usageTrackerService: _usageTrackerService,
            ),
      ),
    ];
  }

  Future<void> _initializeAppData() async {
    if (!_tabsLoading && _tabsInitialized) return;

    await _loadUserProfile();

    _availableTabBuilders = {
      'dashboard':
          (context) => DashboardTab(
            allFoodEntries: _allFoodEntries,
            allFastingSessions: _allFastingSessions,
            currentGoals: _currentGoals,
            allScannedProducts: _allScannedProducts,
            allActivities: _allActivities,
            allWeightEntries: _allWeightEntries,
            allWaterEntries: _allWaterEntries,
            addWaterEntry: _addWaterEntry,
            onScanProduct: _handleScanProduct,
            onMonthChanged: (selectedMonth) async {
              await _loadFoodEntriesForMonth(selectedMonth);
            },
            onViewScanHistory: () {
              if (_tabController != null &&
                  _userTabs.any((tab) => tab.id == 'scan_history')) {
                final visibleTabs =
                    _userTabs.where((tab) => tab.isVisible).toList();
                final index = visibleTabs.indexWhere(
                  (tab) => tab.id == 'scan_history',
                );
                if (index != -1) _tabController!.animateTo(index);
              }
            },
            foodEntriesCount: _allFoodEntries.length,
            activityEntriesCount: _allActivities.length,
            userProfile: _userProfile,
            isPremiumUser: _isPremium,
            usageTrackerService: _usageTrackerService,
          ),
      'calories':
          (context) => CaloriesTab(
            foodLog: _allFoodEntries,
            scannedProductsHistory: _allScannedProducts,
            addFoodEntry: _addFoodEntry,
            deleteFoodEntry: _deleteFoodEntry,
            onScanProduct: _handleScanProduct,
            isPremiumUser: _isPremium,
            usageTrackerService: _usageTrackerService,
          ),
      'fasting':
          (context) =>
              _userProfile == null
                  ? const Center(child: CircularProgressIndicator())
                  : FastingTab(
                    fastingHistory: _allFastingSessions,
                    addFastingSession: _addFastingSession,
                    deleteFastingSession: _deleteFastingSession,
                    isPremiumUser: _isPremium,
                    currentGoals: _currentGoals,
                    firestoreService: _firestoreService,
                    userProfile: _userProfile!,
                  ),
      'activities':
          (context) => ActivitiesTab(
            activities: _allActivities,
            addActivity: _addActivityEntry,
            deleteActivity: _deleteActivityEntry,
            isPremiumUser: _isPremium,
            usageTrackerService: _usageTrackerService,
            userProfile: _userProfile,
            currentGoals: _currentGoals,
          ),
      'evolution':
          (context) => EvolutionTab(
            allWeightEntries: _allWeightEntries,
            addWeightEntry: _addWeightEntry,
            deleteWeightEntry: _deleteWeightEntry,
            currentGoals: _currentGoals,
            isPremiumUser: _isPremium,
            usageTrackerService: _usageTrackerService,
            // PARAMÃˆTRES CORRIGÃ‰S
            userProfile: _userProfile,
            allFoodEntries: _allFoodEntries,
          ),
      'scan_history':
          (context) => ScanHistoryTab(
            scannedProducts: _allScannedProducts,
            deleteScannedProduct: _deleteScannedProduct,
            onRescanProduct: _handleScanProduct,
          ),
      'menu_planning':
          (context) =>
              _userProfile == null
                  ? const Center(child: CircularProgressIndicator())
                  : MenuPlanningTab(
                    mealPlans: _mealPlans,
                    addMealPlanEntry: _addMealPlanEntry,
                    deleteMealPlanEntry: _deleteMealPlanEntry,
                    addFoodEntryToTracker: _addFoodEntry,
                    currentGoals: _currentGoals,
                    isPremiumUser: _isPremium,
                    usageTrackerService: _usageTrackerService,
                    userProfile: _userProfile!,
                  ),
      'subscription':
          (context) => SubscriptionPage(
            isPremiumUser: _isPremium,
            subscriptionService: _subscriptionService,
            usageTrackerService: _usageTrackerService,
          ),
    };

    await Future.wait([
      _loadFoodEntries(),
      _loadFastingSessions(),
      _loadScannedProducts(),
      _loadDailyGoals(),
      _loadMealPlans(),
      _loadActivities(),
      _loadWeightEntries(),
      _loadWaterEntries(),
      _loadUserTabs(),
      _subscriptionService.getIsPremium().then((value) => _isPremium = value),
    ]);

    await _updateAndGetStreak();
    await _syncHealthData();
    _recreateTabController();

    if (mounted) {
      setState(() {
        _tabsLoading = false;
        _tabsInitialized = true;
      });
    }
  }

  Future<void> _loadUserTabs() async {
    final querySnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('userTabs')
            .orderBy('orderIndex')
            .get();

    List<UserTab> loadedTabs = [];
    if (querySnapshot.docs.isNotEmpty) {
      for (var doc in querySnapshot.docs) {
        try {
          loadedTabs.add(
            UserTab.fromFirestore(doc.data(), doc.id, _availableTabBuilders),
          );
        } catch (e) {
          print("Error loading tab from Firestore: $e, data: ${doc.data()}");
        }
      }
    }

    if (loadedTabs.isEmpty) {
      _userTabs = _getDefaultTabs();
      await _saveUserTabs();
    } else {
      final defaultTabs = _getDefaultTabs();
      final Map<String, UserTab> defaultTabMap = {
        for (var tab in defaultTabs) tab.id: tab,
      };

      List<UserTab> finalTabs = [];
      for (var loadedTab in loadedTabs) {
        if (defaultTabMap.containsKey(loadedTab.id)) {
          finalTabs.add(
            UserTab(
              id: loadedTab.id,
              title: defaultTabMap[loadedTab.id]!.title,
              icon: defaultTabMap[loadedTab.id]!.icon,
              builder: defaultTabMap[loadedTab.id]!.builder,
              isVisible: loadedTab.isVisible,
            ),
          );
          defaultTabMap.remove(loadedTab.id);
        }
      }
      finalTabs.addAll(
        defaultTabMap.values.map((tab) => tab.copyWith(isVisible: true)),
      );

      _userTabs = finalTabs;
    }
  }

  Future<void> _saveUserTabs() async {
    final batch = FirebaseFirestore.instance.batch();
    final userTabsCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('userTabs');

    final existingTabs = await userTabsCollection.get();
    for (var doc in existingTabs.docs) {
      batch.delete(doc.reference);
    }

    for (int i = 0; i < _userTabs.length; i++) {
      final tab = _userTabs[i];
      batch.set(userTabsCollection.doc(tab.id), {
        ...tab.toFirestore(),
        'orderIndex': i,
      });
    }
    await batch.commit();
  }

  void _recreateTabController() {
    if (!mounted) return;

    final visibleTabs = _userTabs.where((tab) => tab.isVisible).toList();

    _tabController?.dispose();

    _tabController = TabController(
      length: visibleTabs.isEmpty ? 1 : visibleTabs.length,
      vsync: this,
    );

    if (_tabController!.index >= visibleTabs.length && visibleTabs.isNotEmpty) {
      _tabController!.animateTo(0);
    }
  }

  void _updateUserTabs(List<UserTab> updatedTabs) {
    setState(() {
      _userTabs = updatedTabs;
      _recreateTabController();
      _saveUserTabs();
    });
  }

  void _showThemeSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ThÃ¨me de l\'application'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('SystÃ¨me'),
                onTap: () async {
                  appThemeNotifier.value = ThemeMode.system;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('app_theme_mode', 'system');
                  if (mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: const Text('Clair'),
                onTap: () async {
                  appThemeNotifier.value = ThemeMode.light;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('app_theme_mode', 'light');
                  if (mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Sombre'),
                onTap: () async {
                  appThemeNotifier.value = ThemeMode.dark;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('app_theme_mode', 'dark');
                  if (mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('FERMER'),
            ),
          ],
        );
      },
    );
  }

  void _showRewardsDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                const Text('ðŸ”¥ '),
                Text(
                  'SÃ©rie Actuelle : $_currentStreak j',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Maintenez votre sÃ©rie en vous connectant chaque jour pour gagner des rÃ©compenses !",
                ),
                const SizedBox(height: 16),
                _buildRewardItem(
                  3,
                  '1 appel IA bonus / jour',
                  _currentStreak >= 3,
                ),
                _buildRewardItem(
                  7,
                  '3 appels IA bonus / jour',
                  _currentStreak >= 7,
                ),
                _buildRewardItem(
                  15,
                  '5 appels IA bonus / jour',
                  _currentStreak >= 15,
                ),
                _buildRewardItem(
                  30,
                  'Badge Utilisateur Assidu',
                  _currentStreak >= 30,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  Widget _buildRewardItem(int days, String reward, bool unlocked) {
    return ListTile(
      leading: Icon(
        unlocked ? Icons.check_circle : Icons.lock,
        color: unlocked ? Colors.green : Colors.grey,
      ),
      title: Text(
        reward,
        style: TextStyle(
          fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
          color: unlocked ? Colors.black : Colors.grey,
        ),
      ),
      subtitle: Text('Atteindre $days jours'),
    );
  }

  Future<void> _onUserProfileUpdated() async {
    setState(() {
      _tabsLoading = true;
    });
    await _initializeAppData();
    setState(() {
      _tabsLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabsLoading || _tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Mettre Ã  jour le streak dans le tracker d'usage
    _usageTrackerService.currentStreak = _currentStreak;

    final List<UserTab> visibleTabs =
        _userTabs.where((tab) => tab.isVisible).toList();

    if (visibleTabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NutriZen'),
          leading: IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => UserProfileScreen(
                        userId: widget.userId,
                        firestoreService: _firestoreService,
                        onProfileUpdated: _onUserProfileUpdated,
                        initialProfile: _userProfile!,
                        initialGoals: _currentGoals,
                        allWeightEntries: _allWeightEntries,
                        isPremiumUser: _isPremium,
                        usageTrackerService: _usageTrackerService,
                      ),
                ),
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.brightness_6),
              onPressed: () => _showThemeSettings(context),
            ),
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => TabManagementScreen(
                          allTabs: _userTabs,
                          availableTabBuilders: _availableTabBuilders,
                        ),
                  ),
                );
                if (result != null && result is List<UserTab>) {
                  _updateUserTabs(result);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService().signOut();
              },
            ),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Aucun onglet visible. Veuillez gÃ©rer vos onglets via le menu en haut Ã  droite pour les afficher.",
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: visibleTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NutriZen'),
          leading: IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => UserProfileScreen(
                        userId: widget.userId,
                        firestoreService: _firestoreService,
                        onProfileUpdated: _onUserProfileUpdated,
                        initialProfile: _userProfile!,
                        initialGoals: _currentGoals,
                        allWeightEntries: _allWeightEntries,
                        isPremiumUser: _isPremium,
                        usageTrackerService: _usageTrackerService,
                      ),
                ),
              );
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: InkWell(
                  onTap: _showRewardsDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Text('ðŸ”¥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          '$_currentStreak j',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.brightness_6),
              onPressed: () => _showThemeSettings(context),
            ),
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => TabManagementScreen(
                          allTabs: _userTabs,
                          availableTabBuilders: _availableTabBuilders,
                        ),
                  ),
                );
                if (result != null && result is List<UserTab>) {
                  _updateUserTabs(result);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService().signOut();
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey.shade300,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            tabs:
                visibleTabs
                    .map((tab) => Tab(icon: Icon(tab.icon), text: tab.title))
                    .toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: visibleTabs.map((tab) => tab.builder(context)).toList(),
        ),
      ),
    );
  }
}
// =============================================================================
// NOUVEAU: Page de gestion des onglets
// =============================================================================

class TabManagementScreen extends StatefulWidget {
  final List<UserTab> allTabs;
  final Map<String, WidgetBuilder> availableTabBuilders;

  const TabManagementScreen({
    super.key,
    required this.allTabs,
    required this.availableTabBuilders,
  });

  @override
  State<TabManagementScreen> createState() => _TabManagementScreenState();
}

class _TabManagementScreenState extends State<TabManagementScreen> {
  late List<UserTab> _currentTabs;

  @override
  void initState() {
    super.initState();
    _currentTabs = widget.allTabs.map((tab) => tab.copyWith()).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final UserTab item = _currentTabs.removeAt(oldIndex);
      _currentTabs.insert(newIndex, item);
    });
  }

  void _toggleTabVisibility(String tabId, bool isVisible) {
    setState(() {
      final index = _currentTabs.indexWhere((tab) => tab.id == tabId);
      if (index != -1) {
        _currentTabs[index] = _currentTabs[index].copyWith(
          isVisible: isVisible,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<UserTab> visibleTabs =
        _currentTabs.where((tab) => tab.isVisible).toList();
    final List<UserTab> hiddenTabs =
        _currentTabs.where((tab) => !tab.isVisible).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('GÃ©rer les Onglets')),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: visibleTabs.length,
              onReorder: _onReorder,
              header: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Onglets Visibles (maintenez et glissez pour rÃ©organiser)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              itemBuilder: (context, index) {
                final tab = visibleTabs[index];
                return Card(
                  key: ValueKey(tab.id),
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: CheckboxListTile(
                    value: tab.isVisible,
                    onChanged: (bool? value) {
                      _toggleTabVisibility(tab.id, value ?? false);
                    },
                    secondary: Icon(tab.icon),
                    title: Text(tab.title),
                    subtitle: const Text('Visible'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              },
            ),
          ),
          const Divider(height: 32, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              'Onglets CachÃ©s (cochez pour rendre visible)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: hiddenTabs.length,
              itemBuilder: (context, index) {
                final tab = hiddenTabs[index];
                return Card(
                  key: ValueKey(tab.id),
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: CheckboxListTile(
                    value: tab.isVisible,
                    onChanged: (bool? value) {
                      _toggleTabVisibility(tab.id, value ?? false);
                    },
                    secondary: Icon(tab.icon),
                    title: Text(tab.title),
                    subtitle: const Text('CachÃ©'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context, _currentTabs);
        },
        label: const Text('Appliquer les Modifications'),
        icon: const Icon(Icons.check),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// =============================================================================
// Onglet Tableau de Bord (DashboardTab)
// =============================================================================
// =============================================================================
// Onglet Tableau de Bord (DashboardTab) - VERSION COMPLÃˆTE RÃ‰Ã‰CRITE
// =============================================================================
class DashboardTab extends StatefulWidget {
  final List<FoodEntry> allFoodEntries;
  final List<FastingSession> allFastingSessions;
  final DailyGoal currentGoals;
  final List<ScannedProduct> allScannedProducts;
  final List<ActivityEntry> allActivities;
  final List<WeightEntry> allWeightEntries;
  final List<WaterEntry> allWaterEntries;
  final Function(WaterEntry) addWaterEntry;
  final Function(String) onScanProduct;
  final VoidCallback onViewScanHistory;
  final ValueChanged<DateTime> onMonthChanged;
  final int foodEntriesCount;
  final int activityEntriesCount;
  final UserProfile? userProfile;
  final bool isPremiumUser;
  final UsageTrackerService usageTrackerService;

  const DashboardTab({
    super.key,
    required this.allFoodEntries,
    required this.allFastingSessions,
    required this.currentGoals,
    required this.allScannedProducts,
    required this.allActivities,
    required this.allWeightEntries,
    required this.allWaterEntries,
    required this.addWaterEntry,
    required this.onScanProduct,
    required this.onViewScanHistory,
    required this.onMonthChanged,
    required this.foodEntriesCount,
    required this.activityEntriesCount,
    required this.userProfile,
    required this.isPremiumUser,
    required this.usageTrackerService,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // NOUVEAU: Ã‰tats pour l'analyse IA Globale
  bool _isAnalyzingGlobal = false;
  Map<String, dynamic>? _globalAiAnalysisResult;

  // NOUVEAU: Ã‰tats pour le dÃ©fi du jour par l'IA
  bool _isLoadingDailyChallenge = false;
  Map<String, dynamic>? _dailyChallengeResult;
  bool _isDailyChallengeCompleted = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDailyChallengeState();
  }

  Future<void> _loadDailyChallengeState() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastDateStr = prefs.getString('daily_challenge_date');
    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      final now = DateTime.now();

      if (lastDate.year == now.year &&
          lastDate.month == now.month &&
          lastDate.day == now.day) {
        final String? challengeJson = prefs.getString('daily_challenge_result');
        if (challengeJson != null) {
          setState(() {
            _dailyChallengeResult = json.decode(challengeJson);
            _isDailyChallengeCompleted =
                prefs.getBool('daily_challenge_completed') ?? false;
          });
        }
      } else {
        await prefs.remove('daily_challenge_date');
        await prefs.remove('daily_challenge_result');
        await prefs.remove('daily_challenge_completed');
      }
    }
  }

  Future<void> _saveDailyChallengeState() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString('daily_challenge_date', now.toIso8601String());
    if (_dailyChallengeResult != null) {
      await prefs.setString(
        'daily_challenge_result',
        json.encode(_dailyChallengeResult),
      );
    }
    await prefs.setBool(
      'daily_challenge_completed',
      _isDailyChallengeCompleted,
    );
  }

  Map<String, dynamic> _getGoalAdherence() {
    double percentage = 0.0;
    String message = "Commencez à suivre vos données pour voir votre progression !";
    bool goalReached = false;

    if (widget.userProfile != null && widget.userProfile!.goalHistory.isNotEmpty) {
      final currentGoal = widget.userProfile!.goalHistory.lastWhereOrNull(
        (g) => g.status == GoalStatus.inProgress,
      );

      if (currentGoal != null) {
        double currentWeight = widget.userProfile!.weight;
        
        if (widget.allWeightEntries.isNotEmpty) {
          final sortedEntries = List<WeightEntry>.from(widget.allWeightEntries)
            ..sort((a, b) => a.date.compareTo(b.date));
          currentWeight = sortedEntries.last.weight;
        }

        final startWeight = currentGoal.startWeight;
        final targetWeight = currentGoal.targetWeight;

        if (currentGoal.goalType == 'lose') {
          if (startWeight > targetWeight) {
            percentage = ((startWeight - currentWeight) / (startWeight - targetWeight) * 100).clamp(0, 100).toDouble();
          }
          if (currentWeight <= targetWeight) goalReached = true;
        } else if (currentGoal.goalType == 'gain') {
          if (targetWeight > startWeight) {
            percentage = ((currentWeight - startWeight) / (targetWeight - startWeight) * 100).clamp(0, 100).toDouble();
          }
          if (currentWeight >= targetWeight) goalReached = true;
        } else {
          final diff = (currentWeight - targetWeight).abs();
          percentage = (100 - (diff * 10)).clamp(0, 100).toDouble(); // 1kg d'écart = 90%
          
          if (percentage >= 90) {
            message = "Équilibre parfait ! Vous maintenez votre poids idéal.";
          } else {
            message = "Attention, vous vous éloignez de votre zone de maintien.";
          }
          goalReached = false; 
        }

        if (goalReached && currentGoal.goalType != 'maintain') {
          message = "🎉 Félicitations ! Objectif atteint !";
          percentage = 100.0;
        } else if (currentGoal.goalType != 'maintain') {
          if (percentage >= 85) {
            message = "Excellent ! Vous êtes très proche de votre objectif final.";
          } else if (percentage >= 50) {
            message = "Vous avez fait plus de la moitié du chemin. Continuez !";
          } else if (percentage > 0) {
            message = "Vous êtes sur la bonne voie. Restez motivé !";
          }
        }
      }
    }

    return {
      'percentage': percentage,
      'delayDays': 0,
      'message': message,
      'goalReached': goalReached,
    };
  }

  // NOUVEAU: Logique pour estimer le temps avant d'atteindre l'objectif de poids
  String _getGoalTimeProjection() {
    if (widget.allWeightEntries.length < 2 || widget.userProfile == null) {
      return 'DonnÃ©es insuffisantes.';
    }

    final sortedEntries = List<WeightEntry>.from(widget.allWeightEntries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final currentWeight = sortedEntries.last.weight;
    final goalType = widget.currentGoals.weightGoalType;

    // Calcul du rythme de progression rÃ©el basÃ© sur les 2 derniÃ¨res semaines
    double weeklyChangeRate = 0;
    final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
    final entryTwoWeeksAgo = sortedEntries.lastWhereOrNull(
      (e) => e.date.isBefore(twoWeeksAgo),
    );
    if (entryTwoWeeksAgo != null) {
      final weightDiff = currentWeight - entryTwoWeeksAgo.weight;
      final daysDiff =
          sortedEntries.last.date.difference(entryTwoWeeksAgo.date).inDays;
      if (daysDiff > 0) {
        weeklyChangeRate = (weightDiff / daysDiff) * 7;
      }
    }

    // Si pas de changement rÃ©cent, on prend une valeur saine par dÃ©faut pour la projection
    if (weeklyChangeRate == 0) {
      weeklyChangeRate =
          goalType == 'lose' ? -0.5 : (goalType == 'gain' ? 0.2 : 0);
    }

    if (goalType == 'lose') {
      final targetWeight = widget.currentGoals.targetWeight;
      final weightToLose = currentWeight - targetWeight;
      if (weightToLose <= 0) return "Objectif atteint !";
      if (weeklyChangeRate >= 0) return "Rythme insuffisant";
      final weeksNeeded = (weightToLose / weeklyChangeRate.abs()).ceil();
      return "Atteint dans env. $weeksNeeded sem.";
    } else if (goalType == 'gain') {
      final targetGain = widget.currentGoals.targetMuscleGain ?? 0;
      final currentGain = currentWeight - (widget.userProfile!.weight);
      final muscleToGain = targetGain - currentGain;
      if (muscleToGain <= 0) return "Objectif atteint !";
      if (weeklyChangeRate <= 0) return "Rythme insuffisant";
      final weeksNeeded = (muscleToGain / weeklyChangeRate.abs()).ceil();
      return "Atteint dans env. $weeksNeeded sem.";
    } else {
      return "Maintien en cours";
    }
  }

  // NOUVEAU: Logique pour la dÃ©pense Ã©nergÃ©tique hebdomadaire
  Map<String, double> _getWeeklyEnergyExpenditure() {
    final now = DateTime.now();
    // Assure que le Lundi est bien le premier jour de la semaine
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final caloriesBurnedThisWeek = widget.allActivities
        .where((a) => a.timestamp.isAfter(startOfWeek))
        .fold(0.0, (sum, item) => sum + item.caloriesBurned);

    final goal = widget.currentGoals.weeklyEnergyExpenditureGoal ?? 2500;

    return {'burned': caloriesBurnedThisWeek, 'goal': goal};
  }

  Map<String, double> _getDailyNutritionSummary(DateTime day) {
    final List<FoodEntry> dailyEntries =
        widget.allFoodEntries
            .where((entry) => isSameDay(entry.timestamp, day))
            .toList();

    double currentCalories = 0;
    double currentProteins = 0;
    double currentCarbs = 0;
    double currentFats = 0;

    for (var entry in dailyEntries) {
      currentCalories += entry.calories;
      currentProteins += entry.proteins;
      currentCarbs += entry.carbs;
      currentFats += entry.fats;
    }

    return {
      'calories': currentCalories,
      'proteins': currentProteins,
      'carbs': currentCarbs,
      'fats': currentFats,
    };
  }

  double _getDailyWaterConsumption(DateTime day) {
    return widget.allWaterEntries
        .where((entry) => isSameDay(entry.timestamp, day))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double _getDailyCaloriesBurned(DateTime day) {
    return widget.allActivities
        .where((activity) => isSameDay(activity.timestamp, day))
        .fold(0.0, (sum, item) => sum + item.caloriesBurned);
  }

  Map<String, dynamic> _getEnvironmentalImpactSummary(DateTime day) {
    final List<ScannedProduct> dailyScans =
        widget.allScannedProducts
            .where((product) => isSameDay(product.scannedDate, day))
            .toList();

    if (dailyScans.isEmpty) {
      return {'hasData': false, 'co2_kg': 0.0, 'eco_score_grade': 'N/A'};
    }

    final Random random = Random();
    double baseCo2 = 5.0;
    String ecoScoreGrade = 'C';

    final int goodScores =
        dailyScans
            .where((p) => (p.nutriScore == 'A' || p.nutriScore == 'B'))
            .length;
    final int badScores =
        dailyScans
            .where((p) => (p.nutriScore == 'D' || p.nutriScore == 'E'))
            .length;

    if (goodScores > badScores * 2) {
      baseCo2 = 3.0 + random.nextDouble() * 3.0;
      ecoScoreGrade = ['A', 'B'][random.nextInt(2)];
    } else if (badScores > goodScores * 2) {
      baseCo2 = 8.0 + random.nextDouble() * 5.0;
      ecoScoreGrade = ['D', 'E'][random.nextInt(2)];
    } else {
      baseCo2 = 5.0 + random.nextDouble() * 4.0;
      ecoScoreGrade = 'C';
    }

    final double co2 = baseCo2 + random.nextDouble() * 2.0;
    return {'hasData': true, 'co2_kg': co2, 'eco_score_grade': ecoScoreGrade};
  }

  int _calculateManualLifestyleScore() {
    final numDailyFoods =
        widget.allFoodEntries
            .where((e) => isSameDay(e.timestamp, _selectedDay!))
            .length;
    final numDailyActivities =
        widget.allActivities
            .where((a) => isSameDay(a.timestamp, _selectedDay!))
            .length;

    if (numDailyFoods == 0 && numDailyActivities == 0) return 0;

    int score = 0;
    score += (numDailyFoods * 5).clamp(0, 30);
    score += (numDailyActivities * 7).clamp(0, 25);

    final dailyWater = _getDailyWaterConsumption(_selectedDay!);
    if (dailyWater >= widget.currentGoals.targetWater) {
      score += 15;
    } else {
      score += (dailyWater / widget.currentGoals.targetWater * 15)
          .toInt()
          .clamp(0, 15);
    }

    final numDailyFasts =
        widget.allFastingSessions
            .where((s) => isSameDay(s.endTime, _selectedDay!))
            .length;
    if (numDailyFasts > 0) score += 10;

    final envSummary = _getEnvironmentalImpactSummary(_selectedDay!);
    if (envSummary['hasData']) {
      final ecoScoreGrade = envSummary['eco_score_grade'];
      if (ecoScoreGrade == 'A') {
        score += 20;
      } else if (ecoScoreGrade == 'B')
        score += 15;
      else if (ecoScoreGrade == 'C')
        score += 10;
      else if (ecoScoreGrade == 'D')
        score += 5;
    }

    return score.clamp(0, 100);
  }

  Map<String, dynamic> _getAILifestyleScore() {
    // Si une vÃ©ritable analyse IA globale est disponible, on l'utilise
    if (_globalAiAnalysisResult != null) {
      return {
        'hasData': true,
        'score':
            _globalAiAnalysisResult!['score'] ??
            _calculateManualLifestyleScore(),
        'comment': _globalAiAnalysisResult!['comment'] ?? "Aucun commentaire.",
        'reliability': '95', // L'IA DeepSeek est trÃ¨s fiable
        'isRealAI': true,
      };
    }

    final manualScore = _calculateManualLifestyleScore();
    if (manualScore == 0) {
      return {
        'hasData': false,
        'score': 0,
        'comment': 'Ajoutez des donnÃ©es pour obtenir une analyse.',
        'reliability': '0',
        'isRealAI': false,
      };
    }

    // Affichage d'un conseil gÃ©nÃ©rique en attendant la vraie IA
    String genericComment;
    if (manualScore > 80) {
      genericComment =
          "Excellent ! Vos indicateurs rÃ©cents sont trÃ¨s positifs.";
    } else if (manualScore > 60)
      genericComment =
          "Bon niveau. Quelques ajustements pourraient vous faire progresser.";
    else if (manualScore > 40)
      genericComment =
          "Niveau moyen. Essayez d'amÃ©liorer votre alimentation ou activitÃ©.";
    else
      genericComment =
          "Attention, vos donnÃ©es indiquent qu'un meilleur suivi serait bÃ©nÃ©fique.";

    return {
      'hasData': true,
      'score': manualScore,
      'comment': genericComment,
      'reliability': 'BasÃ©e sur un calcul basique.',
      'isRealAI': false,
    };
  }

  Future<void> _generateGlobalAIAnalysis() async {
    final manualScore = _calculateManualLifestyleScore();
    if (manualScore == 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Oups, veuillez ajouter quelques donnÃ©es (repas, eau, etc.) avant de lancer l'analyse IA.",
          ),
        ),
      );
      return;
    }

    if (!widget.isPremiumUser) {
      final dailyCalls =
          await widget.usageTrackerService.getDeepSeekApiCallCount();
      if (dailyCalls >= widget.usageTrackerService.deepSeekLimit) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Limite d'appels IA atteinte pour aujourd'hui. Passez Premium !",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isAnalyzingGlobal = true);

    try {
      // Construction d'un prompt exhaustif
      final info = widget.userProfile;
      final profileStr =
          info != null
              ? "${info.age} ans, ${info.gender}, ${info.weight}kg pour ${info.height}cm."
              : "Profil non renseignÃ©.";
      final goalStr = widget.currentGoals.weightGoalType;

      // Extraction de toutes les donnÃ©es du jour pour les envoyer Ã  l'IA
      final dailyNutritionSummary = _getDailyNutritionSummary(
        _selectedDay ?? DateTime.now(),
      );
      final dailyWaterActivity = _getDailyWaterConsumption(
        _selectedDay ?? DateTime.now(),
      );
      final caloriesBurned = _getDailyCaloriesBurned(
        _selectedDay ?? DateTime.now(),
      );

      final FastingSession? activeFastingSession = widget.allFastingSessions
          .firstWhereOrNull(
            (session) =>
                session.startTime.isBefore(DateTime.now()) &&
                session.endTime.isAfter(DateTime.now()),
          );
      final String fastingStateStr =
          activeFastingSession != null
              ? "En cours jusqu'Ã  \${DateFormat('HH:mm').format(activeFastingSession.endTime)}"
              : "Aucun jeÃ»ne en cours";

      final String prompt = '''
      Tu es l'IA globale de l'application de santÃ©. Tu croises toutes les donnÃ©es de l'utilisateur pour lui fournir un bilan quotidien pointu.
      
      PROFIL: $profileStr
      OBJECTIF ACTUEL: $goalStr (Calories visÃ©es: ${widget.currentGoals.targetCalories} kcal)
      
      BILAN DU JOUR (CROSS-ONGLETS) :
      - Nutrition : ${dailyNutritionSummary['calories']?.toInt()} kcal consommÃ©es (ProtÃ©ines: ${dailyNutritionSummary['proteins']?.toInt()}g, Glucides: ${dailyNutritionSummary['carbs']?.toInt()}g, Lipides: ${dailyNutritionSummary['fats']?.toInt()}g)
      - Eau bue : $dailyWaterActivity Litres sur un objectif de ${widget.currentGoals.targetWater}L
      - Sport/ActivitÃ© : $caloriesBurned kcal brÃ»lÃ©es
      - JeÃ»ne : $fastingStateStr
      
      CONSIGNES:
      - Mets en lien ses repas avec ses dÃ©penses sportives, sa consommation d'eau, son jeÃ»ne Ã©ventuel, et l'objectif visÃ©.
      - Ã‰value la synergie entre tous ces domaines (les onglets de l'application) et l'objectif visÃ©.
      - Propose une action concrÃ¨te Ã  faire pour optimiser demain (ex: "prÃ©vois un jeÃ»ne plus court si tu as beaucoup de sport de prÃ©vu", "bois un peu plus d'eau pour compenser tes efforts", etc).
      - Donne une note globale sur 100 de son style de vie aujourd'hui en Ã©tant strict mais juste.
      - Sois encourageant et prÃ©cis.
      
      Retourne un JSON strict comme ceci:
      {
         "score": <entier_entre_0_et_100>,
         "comment": "<string_ton_analyse_globale_sur_mesure_et_pertinente>"
      }
      ''';

      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.6,
      );

      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();
        setState(() {
          _globalAiAnalysisResult = result;
        });
      } else {
        throw Exception('RÃ©ponse IA vide');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Oups, l'IA a rencontrÃ© une erreur: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingGlobal = false);
    }
  }

  // NOUVELLE FONCTIONNALITÃ‰: GÃ©nÃ©ration du dÃ©fi quotidien par l'IA
  Future<void> _generateDailyChallengeWithAI() async {
    if (!widget.isPremiumUser) {
      final dailyCalls =
          await widget.usageTrackerService.getDeepSeekApiCallCount();
      if (dailyCalls >= widget.usageTrackerService.deepSeekLimit) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Limite d'appels IA atteinte pour aujourd'hui."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoadingDailyChallenge = true);

    try {
      final info = widget.userProfile;
      final profileStr =
          info != null ? "${info.age} ans, ${info.gender}" : "Inconnu";
      final goalStr = widget.currentGoals.weightGoalType;

      final String prompt = '''
      Tu es un coach sportif et bien-Ãªtre ultra-motivant et crÃ©atif.
      Profil : $profileStr, Objectif : $goalStr.
      
      Propose un PETIT DÃ‰FI UNIQUE, inattendu et faisable aujourd'hui en moins de 5 minutes.
      Exemples: "Faire 15 squats avant le dÃ©jeuner", "Boire 1 grand verre d'eau au rÃ©veil", "Faire 3 minutes d'Ã©tirement en respirant profondÃ©ment", "Remplacer sa collation par un fruit".
      Ne donne qu'un seul dÃ©fi, simple Ã  actionner pour donner un sentiment d'accomplissement (gamification).
      
      Retourne UNIQUEMENT du JSON strict :
      {
        "title": "Titre trÃ¨s court et dynamique",
        "description": "Explication rapide de comment le faire",
        "difficulty": "Facile, Moyen ou Difficile"
      }
      ''';

      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.8,
      );

      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();
        setState(() {
          _dailyChallengeResult = result;
          _isDailyChallengeCompleted = false;
        });
        await _saveDailyChallengeState();
      }
    } catch (e) {
      print("Erreur crÃ©ation dÃ©fi: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDailyChallenge = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyNutritionSummary = _getDailyNutritionSummary(_selectedDay!);
    final dailyWaterConsumption = _getDailyWaterConsumption(_selectedDay!);
    final dailyCaloriesBurned = _getDailyCaloriesBurned(_selectedDay!);
    final envSummary = _getEnvironmentalImpactSummary(_selectedDay!);
    final aiLifestyleData = _getAILifestyleScore();
    final manualLifestyleScore = _calculateManualLifestyleScore();
    // NOUVEAU: RÃ©cupÃ©ration des donnÃ©es hebdomadaires
    final weeklyEnergyData = _getWeeklyEnergyExpenditure();
    final goalAdherenceData = _getGoalAdherence();

    final int consumedCalories = dailyNutritionSummary['calories']!.toInt();
    final int targetCalories = widget.currentGoals.targetCalories;
    final int netCalories = consumedCalories - dailyCaloriesBurned.toInt();

    final FastingSession? activeFastingSession = widget.allFastingSessions
        .firstWhereOrNull(
          (session) =>
              session.startTime.isBefore(DateTime.now()) &&
              session.endTime.isAfter(DateTime.now()),
        );

    return Scaffold(
      body: ListView(
        children: [
          // En-tÃªte : date, kcal net, scanner
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.darken(0.1),
                  Theme.of(context).colorScheme.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16.0, 48.0, 16.0, 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDay!),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Net : $netCalories kcal',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '($consumedCalories ingÃ©rÃ©s âˆ’ ${dailyCaloriesBurned.toInt()} brÃ»lÃ©s)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => widget.onScanProduct('from_dashboard_fab'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scanner un produit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCalendar(),
                const SizedBox(height: 24),
                // NOUVEAU: Le dÃ©fi du jour gÃ©nÃ©rÃ© par IA
                _buildDailyChallengeCard(context),
                const SizedBox(height: 24),
                // NOUVEAU: Ajout du widget de suivi du programme ici
                _buildGoalAdherenceCard(
                  context,
                  percentage: goalAdherenceData['percentage'],
                  delayDays: goalAdherenceData['delayDays'],
                  message: goalAdherenceData['message'],
                  goalReached: goalAdherenceData['goalReached'] ?? false,
                ),
                const SizedBox(height: 24),
                Text(
                  'RÃ©capitulatif Quotidien',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDailyRecapCard(
                  context: context,
                  caloriesConsumed: consumedCalories,
                  caloriesBurned: dailyCaloriesBurned.toInt(),
                  waterConsumed: dailyWaterConsumption,
                  waterTarget: widget.currentGoals.targetWater,
                  ecoScoreGrade: envSummary['eco_score_grade'],
                ),
                const SizedBox(height: 24),
                // NOUVEAU: Ajout de la carte de dÃ©pense Ã©nergÃ©tique hebdomadaire
                _buildWeeklyExpenditureCard(context, weeklyEnergyData),
                const SizedBox(height: 24),
                Text(
                  'Progression Nutritionnelle',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCaloriesProgressCard(
                  context,
                  consumedCalories,
                  targetCalories,
                ),
                const SizedBox(height: 16),
                _buildMacrosGraphCard(
                  context,
                  dailyNutritionSummary['proteins']!,
                  widget.currentGoals.targetProteins,
                  dailyNutritionSummary['carbs']!,
                  widget.currentGoals.targetCarbs,
                  dailyNutritionSummary['fats']!,
                  widget.currentGoals.targetFats,
                ),
                const SizedBox(height: 24),
                Text(
                  'Objectifs & Impact',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildWeightGoalCard(context),
                const SizedBox(height: 16),
                _buildImpactCard(context, envSummary),
                const SizedBox(height: 16),
                _buildFastingSummaryCard(context, activeFastingSession),
                const SizedBox(height: 24),
                _buildLifestyleScoreCard(
                  context: context,
                  hasData: aiLifestyleData['hasData'],
                  aiScore: aiLifestyleData['score'],
                  aiComment: aiLifestyleData['comment'],
                  aiReliability: aiLifestyleData['reliability'],
                  manualScore: manualLifestyleScore,
                  isRealAI: aiLifestyleData['isRealAI'] ?? false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onViewScanHistory,
        icon: const Icon(Icons.history),
        label: const Text('Historique des Scans'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // NOUVELLE FONCTIONNALITÃ‰: Le widget du DÃ©fi du Jour GamifiÃ©
  Widget _buildDailyChallengeCard(BuildContext context) {
    if (_dailyChallengeResult == null && !_isLoadingDailyChallenge) {
      return Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.purple.shade50,
        child: InkWell(
          onTap: _generateDailyChallengeWithAI,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  radius: 25,
                  child: const Icon(Icons.flash_on, color: Colors.purple),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "DÃ©fi du Jour IA",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        "Cliquez ici pour gÃ©nÃ©rer votre dÃ©fi !",
                        style: TextStyle(
                          color: Color(0xFF6A1B9A), // purple.shade800
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.purple),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoadingDailyChallenge) {
      return Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: Colors.purple),
                SizedBox(height: 16),
                Text(
                  "L'IA prÃ©pare votre dÃ©fi du jour...",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final title = _dailyChallengeResult!['title'] ?? "DÃ©fi mystÃ¨re";
    final desc = _dailyChallengeResult!['description'] ?? "";
    final diff = _dailyChallengeResult!['difficulty'] ?? "Moyen";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors:
              _isDailyChallengeCompleted
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [Colors.purple.shade400, Colors.purple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isDailyChallengeCompleted
                          ? Icons.emoji_events
                          : Icons.local_fire_department,
                      color: Colors.amber,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "DÃ©fi Quotidien",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    diff,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed:
                    _isDailyChallengeCompleted
                        ? null
                        : () async {
                          setState(() {
                            _isDailyChallengeCompleted = true;
                          });
                          await _saveDailyChallengeState();
                          if (!mounted) return;
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "ðŸŽ‰ DÃ©fi du jour accompli ! Bravo !",
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                icon: Icon(
                  _isDailyChallengeCompleted ? Icons.check_circle : Icons.done,
                ),
                label: Text(
                  _isDailyChallengeCompleted
                      ? "DÃ©fi Accompli !"
                      : "Je l'ai fait !",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor:
                      _isDailyChallengeCompleted
                          ? Colors.green
                          : Colors.purple.shade700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalAdherenceCard(
    BuildContext context, {
    required double percentage,
    required int delayDays,
    required String message,
    bool goalReached = false,
  }) {
    Color progressColor;
    if (goalReached) {
      progressColor = Colors.green.shade600;
    } else if (percentage >= 85) {
      progressColor = Colors.blue.shade600;
    } else if (percentage >= 50) {
      progressColor = Colors.orange.shade600;
    } else {
      progressColor = Colors.red.shade600;
    }

    return Card(
      elevation: 4.0,
      color: progressColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  goalReached
                      ? Icons.workspace_premium
                      : Icons.flag_circle_outlined,
                  color: progressColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Progression vers l'objectif",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "${percentage.toStringAsFixed(0)}%",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ],
            ),
            if (goalReached)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _proposeNewGoalWithAI(context);
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('GÃ©nÃ©rer un nouvel objectif via l\'IA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _proposeNewGoalWithAI(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Nouvel Objectif IA'),
            content: const Text(
              'FÃ©licitations pour avoir atteint votre objectif ! L\'application peut faire appel Ã  l\'IA pour vous suggÃ©rer un nouveau dÃ©fi adaptÃ© Ã  votre mÃ©tabolisme actuel.\n\nVoulez-vous aller dans l\'onglet "Mes Objectifs" pour cela ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Plus tard'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Allez dans l\'onglet "Profil > Mes Objectifs" et cliquez sur "DÃ©duire l\'objectif avec l\'IA"',
                      ),
                    ),
                  );
                },
                child: const Text('C\'est parti'),
              ),
            ],
          ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 6.0, 8.0, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Historique journalier',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
              child: Text(
                'Touchez un jour pour afficher ses donnÃ©es nutritionnelles.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            TableCalendar(
              locale: 'fr_FR',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
                widget.onMonthChanged(DateTime(focusedDay.year, focusedDay.month, 1));
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: TextStyle(color: Colors.red.shade400),
                outsideTextStyle: TextStyle(color: Colors.grey.shade400),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: Theme.of(context).textTheme.titleLarge!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // placeholder to separate from menu planning's _buildCalendar

  Widget _buildDailyRecapCard({
    required BuildContext context,
    required int caloriesConsumed,
    required int caloriesBurned,
    required double waterConsumed,
    required double waterTarget,
    required String? ecoScoreGrade,
  }) {
    Color waterColor =
        waterConsumed >= waterTarget
            ? Colors.blue.shade700
            : Colors.lightBlue.shade300;
    String waterStatus =
        waterConsumed >= waterTarget
            ? 'Objectif atteint'
            : 'Manque ${(waterTarget - waterConsumed).toStringAsFixed(1)} L';

    Color ecoColor = Colors.grey;
    if (ecoScoreGrade != null) {
      switch (ecoScoreGrade) {
        case 'A':
          ecoColor = Colors.green.shade600;
          break;
        case 'B':
          ecoColor = Colors.lightGreen.shade600;
          break;
        case 'C':
          ecoColor = Colors.orange.shade600;
          break;
        case 'D':
          ecoColor = Colors.deepOrange.shade600;
          break;
        case 'E':
          ecoColor = Colors.red.shade600;
          break;
      }
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RÃ©sumÃ© de la JournÃ©e',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(height: 24),
            _RecapItem(
              icon: Icons.fastfood,
              label: 'Calories consommÃ©es',
              value: '$caloriesConsumed kcal',
              color: Theme.of(context).colorScheme.primary,
            ),
            _RecapItem(
              icon: Icons.local_fire_department,
              label: 'Calories brÃ»lÃ©es',
              value: '$caloriesBurned kcal',
              color: Colors.orange.shade700,
            ),
            _RecapItem(
              icon: Icons.water_drop,
              label: 'Consommation d\'eau',
              value:
                  '${waterConsumed.toStringAsFixed(1)} L sur ${waterTarget.toStringAsFixed(1)} L',
              color: waterColor,
              subtext: waterStatus,
              onTap: () async {
                double? amount = await _showAddWaterDialog(context);
                if (amount != null && amount > 0) {
                  widget.addWaterEntry(
                    WaterEntry(timestamp: _selectedDay!, amount: amount),
                  );
                }
              },
            ),
            _RecapItem(
              icon: Icons.eco,
              label: 'Eco-Score Quotidien',
              value: ecoScoreGrade ?? 'N/A',
              color: ecoColor,
            ),
          ],
        ),
      ),
    );
  }

  // NOUVEAU: Widget pour la carte de dÃ©pense Ã©nergÃ©tique hebdomadaire
  Widget _buildWeeklyExpenditureCard(
    BuildContext context,
    Map<String, double> weeklyData,
  ) {
    final double burned = weeklyData['burned']!;
    final double goal = weeklyData['goal']!;
    final double progress = (goal > 0) ? (burned / goal).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "DÃ©pense Ã‰nergÃ©tique Hebdomadaire",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_outlined,
                  color: Colors.orange.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  "${burned.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} kcal",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),
    );
  }

  Future<double?> _showAddWaterDialog(BuildContext context) async {
    return showDialog<double>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Ajouter de l\'eau', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.local_drink, color: Colors.blue),
                      label: const Text('+ 250 ml'),
                      onPressed: () => Navigator.pop(ctx, 0.25),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.water_drop, color: Colors.blue),
                      label: const Text('+ 500 ml'),
                      onPressed: () => Navigator.pop(ctx, 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 1.0),
                  child: const Text('+ 1 Litre (Gourde)'),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildCaloriesProgressCard(
    BuildContext context,
    int current,
    int goal,
  ) {
    final percentage = (goal > 0) ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Calories JournaliÃ¨res',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage > 1.0
                          ? Colors.red.shade600
                          : Colors.green.shade600,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$current',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'sur $goal kcal',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosGraphCard(
    BuildContext context,
    double p,
    double pGoal,
    double c,
    double cGoal,
    double f,
    double fGoal,
  ) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Macronutriments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            _MacroProgressIndicator(
              label: 'ProtÃ©ines',
              currentValue: p,
              goalValue: pGoal,
              color: Colors.blue.shade600,
            ),
            const SizedBox(height: 16),
            _MacroProgressIndicator(
              label: 'Glucides',
              currentValue: c,
              goalValue: cGoal,
              color: Colors.orange.shade600,
            ),
            const SizedBox(height: 16),
            _MacroProgressIndicator(
              label: 'Lipides',
              currentValue: f,
              goalValue: fGoal,
              color: Colors.purple.shade600,
            ),
          ],
        ),
      ),
    );
  }

  // MODIFIÃ‰: Carte d'objectif de poids pour inclure la projection
  Widget _buildWeightGoalCard(BuildContext context) {
    final sortedWeights = List<WeightEntry>.from(widget.allWeightEntries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final double currentWeight =
        sortedWeights.isNotEmpty
            ? sortedWeights.last.weight
            : (widget.userProfile?.weight ?? 70.0);
    final targetWeight = widget.currentGoals.targetWeight;
    final String goalType = widget.currentGoals.weightGoalType;
    final String timeProjection = _getGoalTimeProjection();

    String goalText;
    Color goalColor;
    IconData goalIcon;

    if (goalType == 'lose') {
      goalText = 'Perte de poids';
      goalColor = Colors.red.shade600;
      goalIcon = Icons.arrow_downward;
    } else if (goalType == 'gain') {
      goalText = 'Prise de muscle';
      goalColor = Colors.blue.shade600;
      goalIcon = Icons.fitness_center;
    } else {
      goalText = 'Maintien';
      goalColor = Colors.green.shade600;
      goalIcon = Icons.balance;
    }

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(goalIcon, color: goalColor),
                const SizedBox(width: 10),
                Text(
                  'Objectif : $goalText',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ImpactStat(
                  score: currentWeight.toStringAsFixed(1),
                  label: 'Actuel (kg)',
                  color: Colors.grey.shade700,
                ),
                Icon(
                  Icons.arrow_right_alt,
                  color: Colors.grey.shade400,
                  size: 30,
                ),
                _ImpactStat(
                  score: targetWeight.toStringAsFixed(1),
                  label: 'Cible (kg)',
                  color: goalColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Chip(
                avatar: const Icon(
                  Icons.timelapse,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  timeProjection,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Colors.blue.shade400,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactCard(
    BuildContext context,
    Map<String, dynamic> envSummary,
  ) {
    if (envSummary['hasData'] == false) {
      return Card(
        elevation: 4.0,
        color: Colors.grey.shade200,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: Text(
              "Scannez des produits pour voir votre impact environnemental journalier.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final String ecoScoreGrade = envSummary['eco_score_grade'];
    final double co2 = envSummary['co2_kg'];
    String impactMessage;
    Color impactColor;

    switch (ecoScoreGrade) {
      case 'A':
        impactMessage =
            "Excellent ! Votre consommation a un trÃ¨s faible impact environnemental.";
        impactColor = Colors.green.shade600;
        break;
      case 'B':
        impactMessage =
            "Bon travail ! L'impact de votre consommation est faible.";
        impactColor = Colors.lightGreen.shade600;
        break;
      case 'C':
        impactMessage =
            "Moyen. Des amÃ©liorations sont possibles pour rÃ©duire votre empreinte.";
        impactColor = Colors.orange.shade600;
        break;
      case 'D':
        impactMessage =
            "Ã‰levÃ©. Il serait bÃ©nÃ©fique de revoir vos choix pour l'environnement.";
        impactColor = Colors.deepOrange.shade600;
        break;
      case 'E':
        impactMessage =
            "TrÃ¨s Ã©levÃ©. Un effort important est nÃ©cessaire pour rÃ©duire votre impact.";
        impactColor = Colors.red.shade600;
        break;
      default:
        impactMessage = "Impossible d'Ã©valuer l'impact pour ce jour.";
        impactColor = Colors.grey.shade600;
        break;
    }

    return Card(
      elevation: 4.0,
      color: impactColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impact Environnemental Journalier',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: impactColor),
            ),
            const SizedBox(height: 12),
            Text(
              impactMessage,
              style: TextStyle(color: impactColor.darken(0.2), height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ImpactStat(
                  score: ecoScoreGrade,
                  label: 'Eco-Score Jour',
                  color: impactColor,
                ),
                _ImpactStat(
                  score: co2.toStringAsFixed(1),
                  label: 'kg COâ‚‚eq / jour',
                  color: impactColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFastingSummaryCard(
    BuildContext context,
    FastingSession? activeFastingSession,
  ) {
    Widget activeFastingWidget = const SizedBox.shrink();
    if (activeFastingSession != null) {
      final Duration remainingTime = activeFastingSession.endTime.difference(
        DateTime.now(),
      );
      activeFastingWidget = Column(
        children: [
          _RecapItem(
            icon: Icons.timer,
            label: 'JeÃ»ne en cours',
            value: 'Fin dans ${_formatDuration(remainingTime)}',
            color: Colors.lightGreen.shade700,
            subtext:
                'DÃ©butÃ© le ${DateFormat('d MMM HH:mm', 'fr_FR').format(activeFastingSession.startTime)}',
          ),
          const Divider(height: 16),
        ],
      );
    }

    final List<FastingSession> recentSessions =
        widget.allFastingSessions
            .where(
              (session) => session.endTime.isAfter(
                DateTime.now().subtract(const Duration(days: 7)),
              ),
            )
            .toList();

    if (recentSessions.isEmpty && activeFastingSession == null) {
      return const SizedBox.shrink();
    }

    Duration longestFast = Duration.zero;
    Duration totalFastDuration = Duration.zero;
    int sessionsMetTarget = 0;

    for (var session in recentSessions) {
      if (session.duration > longestFast) {
        longestFast = session.duration;
      }
      totalFastDuration += session.duration;
      if (session.isTargetReached) {
        sessionsMetTarget++;
      }
    }
    final Duration averageFast =
        recentSessions.isNotEmpty
            ? totalFastDuration ~/ recentSessions.length
            : Duration.zero;

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RÃ©sumÃ© des JeÃ»nes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(height: 24),
            activeFastingWidget,
            if (recentSessions.isNotEmpty) ...[
              Text(
                '7 derniers jours',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ImpactStat(
                    score: '${recentSessions.length}',
                    label: 'Sessions',
                    color: Colors.blue.shade600,
                  ),
                  _ImpactStat(
                    score: _formatDuration(averageFast),
                    label: 'Moyenne',
                    color: Colors.blue.shade600,
                  ),
                  _ImpactStat(
                    score: _formatDuration(longestFast),
                    label: 'Plus long',
                    color: Colors.blue.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _RecapItem(
                icon: Icons.check_circle_outline,
                label: 'Objectifs atteints',
                value: '$sessionsMetTarget / ${recentSessions.length}',
                color:
                    sessionsMetTarget == recentSessions.length
                        ? Colors.green
                        : Colors.orange,
              ),
            ] else if (activeFastingSession == null) ...[
              const Center(
                child: Text(
                  "Aucun jeÃ»ne rÃ©cent.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "0h 0min";
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}min';
    if (minutes > 0) return '${minutes}min';
    return '${d.inSeconds}s';
  }

  Widget _buildLifestyleScoreCard({
    required BuildContext context,
    required bool hasData,
    required int aiScore,
    required String aiComment,
    required String aiReliability,
    required int manualScore,
    required bool isRealAI,
  }) {
    if (!hasData) {
      return Card(
        elevation: 4.0,
        color: Colors.grey.shade200,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: Text(
              "Ajoutez des repas, activitÃ©s et autres donnÃ©es pour obtenir votre score de vie journalier.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    Color scoreColor(int score) {
      if (score > 80) return Colors.green.shade700;
      if (score > 60) return Colors.lightGreen.shade700;
      if (score > 40) return Colors.orange.shade700;
      return Colors.red.shade700;
    }

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color:
          isRealAI
              ? scoreColor(aiScore).withOpacity(0.15)
              : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRealAI ? Icons.psychology : Icons.star_border,
                  color:
                      isRealAI ? Colors.purple.shade600 : scoreColor(aiScore),
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isRealAI
                        ? 'Bilan Global de l\'IA'
                        : 'Note Quotidienne (Manuel)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isRealAI)
                  _isAnalyzingGlobal
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : IconButton(
                        icon: const Icon(
                          Icons.auto_awesome,
                          color: Colors.amber,
                        ),
                        onPressed: _generateGlobalAIAnalysis,
                        tooltip: 'Demander un bilan Ã  l\'IA',
                      ),
              ],
            ),
            if (isRealAI)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                child: Text(
                  'Note IA: $aiScore/100',
                  style: TextStyle(
                    color: scoreColor(aiScore).darken(0.1),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            const Divider(height: 20),
            Text(
              aiComment,
              style: TextStyle(
                fontSize: 15,
                color: isRealAI ? Colors.indigo.shade900 : Colors.grey.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (!isRealAI) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isAnalyzingGlobal ? null : _generateGlobalAIAnalysis,
                  icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                  label: const Text('Obtenir un vrai bilan IA avec DeepSeek'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecapItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtext;
  final VoidCallback? onTap;

  const _RecapItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  if (subtext != null)
                    Text(
                      subtext!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivitiesTab extends StatefulWidget {
  final List<ActivityEntry> activities;
  final Function(ActivityEntry) addActivity;
  final Function(String) deleteActivity;
  final bool isPremiumUser;
  final UsageTrackerService usageTrackerService;
  final DailyGoal currentGoals;
  final UserProfile? userProfile;

  const ActivitiesTab({
    super.key,
    required this.activities,
    required this.addActivity,
    required this.deleteActivity,
    required this.isPremiumUser,
    required this.usageTrackerService,
    required this.currentGoals,
    this.userProfile,
  });

  @override
  State<ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<ActivitiesTab> {
  final TextEditingController _promptController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _generatedWorkout = [];
  bool _isWorkoutLoading = false;

  // Calcule le dÃ©but de la semaine (Lundi)
  DateTime get _startOfWeek {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  // Calcule les calories brÃ»lÃ©es depuis le dÃ©but de la semaine
  double get _caloriesBurnedThisWeek {
    final start = _startOfWeek;
    return widget.activities
        .where((a) => a.timestamp.isAfter(start))
        .fold(0.0, (sum, item) => sum + item.caloriesBurned);
  }

  // Fonction pour estimer les calories d'une activitÃ© via l'IA
  Future<void> _analyzeActivityWithIA() async {
    if (_promptController.text.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez dÃ©crire votre activitÃ©.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!widget.isPremiumUser) {
      final dailyCalls =
          await widget.usageTrackerService.getDeepSeekApiCallCount();
      if (dailyCalls >= widget.usageTrackerService.deepSeekLimit) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Limite d'appels IA atteinte pour aujourd'hui (version Free).",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Analyse IA en cours..."),
              ],
            ),
          ),
    );

    final prompt = '''
    En tant qu'expert coach sportif et nutritionniste, analyse la description de l'activitÃ© physique suivante pour un utilisateur.
    Description de l'activitÃ©: "${_promptController.text}".
    
    Voici les informations de l'utilisateur pour une estimation prÃ©cise :
    - Poids: ${widget.userProfile?.weight ?? 70} kg
    - Ã‚ge: ${widget.userProfile?.age ?? 30} ans
    - Sexe: ${widget.userProfile?.gender ?? 'male'}
    - Niveau d'activitÃ© gÃ©nÃ©ral: ${widget.userProfile?.activityLevel ?? 'moderate'}

    Fournis une rÃ©ponse au format JSON strict. Le JSON doit contenir :
    - "activity_name": Un nom court et descriptif pour l'activitÃ© (ex: "Course Ã  pied intense").
    - "estimated_calories": Le nombre de calories brÃ»lÃ©es estimÃ© (nombre entier).
    - "duration_minutes": La durÃ©e de l'activitÃ© en minutes (nombre entier).
    - "activity_type": Une catÃ©gorie parmi "Course", "Marche", "Musculation", "VÃ©lo", "Yoga", "Natation", "Autre".
    
    Exemple de JSON attendu :
    {
      "activity_name": "Course Ã  pied Ã  allure modÃ©rÃ©e",
      "estimated_calories": 450,
      "duration_minutes": 45,
      "activity_type": "Course"
    }
    ''';

    try {
      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.3,
      );

      if (mounted) Navigator.pop(context); // Ferme la boÃ®te de dialogue de chargement

      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();
        widget.addActivity(
          ActivityEntry(
            description: result['activity_name'],
            caloriesBurned: (result['estimated_calories'] as num).toDouble(),
            duration: Duration(minutes: result['duration_minutes']),
            activityType: result['activity_type'],
            timestamp: _selectedDate,
            isAiEstimated: true,
          ),
        );
        _promptController.clear();
      } else {
        throw Exception('RÃ©ponse IA vide');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur IA: RÃ©seau ou serveur indisponible.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fonction pour gÃ©nÃ©rer un plan d'entraÃ®nement avec l'IA
  Future<void> _generateWorkoutPlanWithIA({
    bool isWeekly = false,
    bool isAtGym = false,
  }) async {
    if (!widget.isPremiumUser) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Cette fonctionnalitÃ© est rÃ©servÃ©e aux membres Premium.",
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // AJOUTÃ‰: VÃ©rification pour s'assurer que le profil est bien chargÃ©
    if (widget.userProfile == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Le profil utilisateur n'a pas pu Ãªtre chargÃ©, impossible de gÃ©nÃ©rer un plan.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isWorkoutLoading = true);

    final prompt = '''
    En tant qu'entraÃ®neur personnel d'Ã©lite, crÃ©e un plan d'entraÃ®nement pour un utilisateur avec le profil suivant :
    - Objectif: ${widget.currentGoals.weightGoalType == 'gain' ? 'Prise de muscle' : (widget.currentGoals.weightGoalType == 'lose' ? 'Perte de poids' : 'Maintien')}
    - Sports aimÃ©s: ${widget.userProfile!.likedSports}
    - Sports dÃ©testÃ©s: ${widget.userProfile!.dislikedSports}

    ${isAtGym ? "ATTENTION : L'utilisateur est ACTUELLEMENT Ã€ LA SALLE DE SPORT. Utilise les machines disponibles (poulies, haltÃ¨res, machines guidÃ©es) pour un maximum d'efficacitÃ©." : "Ã‰quipement disponible: ${widget.userProfile!.gymMode ? 'Salle complÃ¨te' : widget.userProfile!.availableEquipment.join(', ')}"}

    TÃ¢che : gÃ©nÃ©rer un plan dÃ©taillÃ© adaptÃ© UNIQUEMENT au matÃ©riel disponible pour ${isWeekly ? 'la semaine complÃ¨te (7 jours)' : 'la sÃ©ance du jour'}.
    ... (Reste du JSON inchangÃ©)
    ''';

    try {
      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.7,
      );

      if (result != null) {
        final List<dynamic> plan = result['workout_plan'] ?? [];
        setState(() => _generatedWorkout = plan);
      } else {
        throw Exception('RÃ©ponse IA vide');
      }
    } on SocketException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pas de connexion internet. Enregistrez manuellement pour l\'instant !',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur IA: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isWorkoutLoading = false);
    }
  }

  // Fonction pour ajouter une activitÃ© manuellement
  Future<void> _addActivityManually() async {
    final descController = TextEditingController();
    final calController = TextEditingController();
    final durController = TextEditingController();
    final sportNameController = TextEditingController();
    String activityType = 'Course';
    String intensity = 'Moyenne';

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setStateBuilder) => AlertDialog(
                  title: const Text('Ajouter une activitÃ© manuellement'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: descController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: activityType,
                          decoration: const InputDecoration(
                            labelText: 'Type d\'activitÃ©',
                          ),
                          items:
                              [
                                    'Course',
                                    'Marche',
                                    'Musculation',
                                    'VÃ©lo',
                                    'Yoga',
                                    'Natation',
                                    'Autre',
                                  ]
                                  .map(
                                    (label) => DropdownMenuItem(
                                      value: label,
                                      child: Text(label),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) => setStateBuilder(
                                () => activityType = value ?? 'Autre',
                              ),
                        ),
                        if (activityType == 'Autre')
                          TextField(
                            controller: sportNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nom du sport (optionnel)',
                            ),
                          ),
                        TextField(
                          controller: durController,
                          decoration: const InputDecoration(
                            labelText: 'DurÃ©e (minutes)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: intensity,
                          items:
                              ['Faible', 'Moyenne', 'Ã‰levÃ©e']
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateBuilder(() => intensity = val);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'IntensitÃ©',
                          ),
                        ),
                        TextField(
                          controller: calController,
                          decoration: const InputDecoration(
                            labelText: 'Calories brÃ»lÃ©es (optionnel)',
                            hintText: 'CalculÃ©es par IA sinon',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final duration = int.tryParse(durController.text);
                        double? calories = double.tryParse(calController.text);

                        if (descController.text.isNotEmpty &&
                            duration != null) {
                          if (calories == null) {
                            double met = 5.0; // Moyenne
                            if (intensity == 'Faible') {
                              met = 3.5;
                            } else if (intensity == 'Ã‰levÃ©e')
                              met = 6.0;
                            final userWeight =
                                widget.userProfile?.weight ?? 70.0;
                            calories = met * userWeight * (duration / 60.0);
                          }

                          String finalActivityType = activityType;
                          if (activityType == 'Autre' &&
                              sportNameController.text.isNotEmpty) {
                            finalActivityType = sportNameController.text;
                          }

                          widget.addActivity(
                            ActivityEntry(
                              description: descController.text,
                              caloriesBurned: calories,
                              duration: Duration(minutes: duration),
                              activityType: finalActivityType,
                              timestamp: _selectedDate,
                            ),
                          );
                          Navigator.pop(ctx);
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Veuillez remplir les champs Description et DurÃ©e',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Ajouter'),
                    ),
                  ],
                ),
          ),
    );
  }

  // Fonction pour confirmer la suppression
  void _showDeleteActivityDialog(ActivityEntry activity) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer l\'activitÃ© ?'),
            content: Text(
              'Voulez-vous vraiment supprimer "${activity.description}" ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.deleteActivity(activity.id);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }

  // Helper pour l'icÃ´ne
  IconData _getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'course':
        return Icons.directions_run;
      case 'marche':
        return Icons.directions_walk;
      case 'musculation':
        return Icons.fitness_center;
      case 'vÃ©lo':
        return Icons.directions_bike;
      case 'yoga':
        return Icons.self_improvement;
      case 'natation':
        return Icons.pool;
      default:
        return Icons.sports;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyActivities =
        widget.activities
            .where((a) => isSameDay(a.timestamp, _selectedDate))
            .toList();
    final weeklyGoal = widget.currentGoals.weeklyEnergyExpenditureGoal ?? 2500;
    final weeklyProgress = (_caloriesBurnedThisWeek / weeklyGoal).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi des ActivitÃ©s Physiques'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Progression de votre objectif hebdomadaire",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${_caloriesBurnedThisWeek.toStringAsFixed(0)} / ${weeklyGoal.toStringAsFixed(0)} kcal",
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: weeklyProgress,
                          minHeight: 10,
                          backgroundColor:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.secondary,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2200),
                          );
                          if (picked != null && picked != _selectedDate) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          DateFormat(
                            'd MMMM yyyy',
                            'fr_FR',
                          ).format(_selectedDate),
                        ),
                        style: ElevatedButton.styleFrom(elevation: 2),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isPremiumUser)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Card(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.18),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Votre Plan d'EntraÃ®nement IA (VIP)",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.copyWith(
                                    color: Colors.blueGrey.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isWorkoutLoading)
                            const CircularProgressIndicator(),
                          if (!_isWorkoutLoading && _generatedWorkout.isEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      () => _generateWorkoutPlanWithIA(
                                        isWeekly: false,
                                      ),
                                  icon: const Icon(Icons.today),
                                  label: const Text(
                                    "GÃ©nÃ©rer un plan pour aujourd'hui",
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed:
                                      () => _generateWorkoutPlanWithIA(
                                        isWeekly: true,
                                      ),
                                  icon: const Icon(Icons.date_range),
                                  label: const Text(
                                    "GÃ©nÃ©rer un plan pour la semaine",
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed:
                                      () => _generateWorkoutPlanWithIA(
                                        isWeekly: false,
                                        isAtGym: true,
                                      ),
                                  icon: const Icon(Icons.fitness_center),
                                  label: const Text(
                                    "GÃ©nÃ©rer (Je suis Ã  la salle !)",
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade600,
                                  ),
                                ),
                              ],
                            ),
                          if (_generatedWorkout.isNotEmpty)
                            ..._generatedWorkout.map((exerciseData) {
                              final exerciseId = exerciseData['exerciseId'];
                              final title =
                                  exerciseData['title'] ?? 'Exercice inconnu';
                              final subtitle = exerciseData['subtitle'] ?? '';
                              final activityType =
                                  exerciseData['activityType'] ?? 'Musculation';
                              final calories =
                                  (exerciseData['estimated_calories'] ?? 0)
                                      .toDouble();
                              final duration =
                                  exerciseData['duration_minutes'] ?? 0;

                              ExerciseItem? exercise;
                              if (exerciseId != null) {
                                exercise = SL.exerciseLibrary.getExerciseById(
                                  exerciseId,
                                );
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading:
                                      exercise != null &&
                                              exercise.getImageUrl(0).isNotEmpty
                                          ? SizedBox(
                                            width: 50,
                                            height: 50,
                                            child: AnimatedExerciseImage(
                                              imageUrl0: exercise.getImageUrl(
                                                0,
                                              ),
                                              imageUrl1: exercise.getImageUrl(
                                                1,
                                              ),
                                            ),
                                          )
                                          : Icon(
                                            _getActivityIcon(
                                              activityType as String,
                                            ),
                                            color: Colors.blue,
                                          ),
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$subtitle\n${duration}min â€¢ ${calories.toInt()} kcal',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green,
                                      size: 30,
                                    ),
                                    tooltip: "Valider et Ajouter",
                                    onPressed: () {
                                      widget.addActivity(
                                        ActivityEntry(
                                          description: title,
                                          caloriesBurned: calories,
                                          duration: Duration(minutes: duration),
                                          activityType: activityType,
                                          timestamp: _selectedDate,
                                          isAiEstimated: true,
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'ActivitÃ© "$title" ajoutÃ©e !',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }),
                          if (_generatedWorkout.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: TextButton.icon(
                                onPressed:
                                    () =>
                                        setState(() => _generatedWorkout = []),
                                icon: const Icon(Icons.clear),
                                label: const Text("Effacer le plan"),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    leading: Icon(
                      Icons.library_books,
                      color: Colors.green.shade800,
                      size: 40,
                    ),
                    title: const Text(
                      "BibliothÃ¨que d'exercices",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      "Explorez plus de 800 exercices avec guides visuels",
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ExerciseLibraryScreen(
                                userWeight: widget.userProfile?.weight ?? 70.0,
                                onAddActivity: (desc, cal, dur, type) {
                                  widget.addActivity(
                                    ActivityEntry(
                                      description: desc,
                                      caloriesBurned: cal,
                                      duration: Duration(minutes: dur),
                                      activityType: type,
                                      timestamp: _selectedDate,
                                    ),
                                  );
                                },
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DÃ©crire votre activitÃ© pour l'IA",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _promptController,
                          decoration: InputDecoration(
                            labelText: 'Ex: "45min de course intense en cÃ´te"',
                            hintText: 'DÃ©crivez votre sÃ©ance de sport',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _promptController.clear(),
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _analyzeActivityWithIA,
                            icon: const Icon(Icons.lightbulb_outline),
                            label: Text(
                              widget.isPremiumUser
                                  ? 'Estimer calories brÃ»lÃ©es (IA)'
                                  : 'Estimer calories (IA - 5/jour)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              dailyActivities.isEmpty
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'Aucune activitÃ© enregistrÃ©e pour cette date. Ajoutez-en une !',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                    itemCount: dailyActivities.length,
                    itemBuilder: (context, index) {
                      final activity = dailyActivities[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: Icon(
                            _getActivityIcon(activity.activityType),
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(
                            activity.description,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${activity.duration.inMinutes} min â€¢ ${activity.activityType}',
                              ),
                              if (activity.isAiEstimated)
                                const Text(
                                  'EstimÃ© par IA',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Text(
                            '${activity.caloriesBurned.toStringAsFixed(0)} kcal',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onLongPress:
                              () => _showDeleteActivityDialog(activity),
                        ),
                      );
                    },
                  ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addActivityManually,
        label: const Text('Ajouter une activitÃ©'),
        icon: const Icon(Icons.add),
        heroTag: 'addActivityFab',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class EvolutionTab extends StatefulWidget {
  final List<WeightEntry> allWeightEntries;
  final Function(WeightEntry) addWeightEntry;
  final Function(String) deleteWeightEntry;
  final DailyGoal currentGoals;
  final bool isPremiumUser;
  final UsageTrackerService usageTrackerService;
  final UserProfile? userProfile;
  final List<FoodEntry> allFoodEntries;

  const EvolutionTab({
    super.key,
    required this.allWeightEntries,
    required this.addWeightEntry,
    required this.deleteWeightEntry,
    required this.currentGoals,
    required this.isPremiumUser,
    required this.usageTrackerService,
    this.userProfile,
    this.allFoodEntries = const [],
  });

  @override
  State<EvolutionTab> createState() => _EvolutionTabState();
}

class _EvolutionTabState extends State<EvolutionTab> {
  DateTime? _selectedDate;
  double _currentWeightInput = 0.0;
  List<FlSpot> _projectedSpots = [];
  Map<String, dynamic> _projectionData = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentWeightInput =
        widget.allWeightEntries.isNotEmpty
            ? widget.allWeightEntries.last.weight
            : (widget.userProfile?.weight ?? 70.0);
    // Lancer la premiÃ¨re projection au chargement de l'onglet
    _updateProjections();
  }

  @override
  void didUpdateWidget(covariant EvolutionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si les donnÃ©es changent (ex: aprÃ¨s une suppression), on met Ã  jour les projections.
    // C'est une mÃ©thode robuste pour garder l'UI synchronisÃ©e.
    if (widget.allWeightEntries.length != oldWidget.allWeightEntries.length ||
        widget.currentGoals != oldWidget.currentGoals ||
        widget.allFoodEntries.length != oldWidget.allFoodEntries.length) {
      _updateProjections();
    }
  }

  // Fonction centrale pour rafraÃ®chir les donnÃ©es de projection
  void _updateProjections() {
    if (!mounted) return;

    final newProjectionData = _getWeightProjections();
    // CORRECTION: Gestion sÃ»re de la liste de projections
    final projections =
        (newProjectionData['projections'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    final sortedEntries = List<WeightEntry>.from(widget.allWeightEntries)
      ..sort((a, b) => a.date.compareTo(b.date));

    List<FlSpot> newSpots = [];
    if (sortedEntries.isNotEmpty && projections.isNotEmpty) {
      final lastHistoricalSpot = FlSpot(
        (sortedEntries.length - 1).toDouble(),
        sortedEntries.last.weight,
      );
      newSpots.add(lastHistoricalSpot);
      DateTime lastDate = sortedEntries.last.date;
      double lastX = lastHistoricalSpot.x;

      for (var proj in projections) {
        final daysDiff = (proj['date'] as DateTime).difference(lastDate).inDays;
        final newX =
            lastX + (daysDiff / 7.0); // 1 unitÃ© sur l'axe X = env. 1 semaine
        newSpots.add(FlSpot(newX, proj['weight'] as double));
      }
    }

    // Mettre Ã  jour l'Ã©tat pour reconstruire le widget avec les nouvelles donnÃ©es
    setState(() {
      _projectedSpots = newSpots;
      _projectionData = newProjectionData;
    });
  }

  bool _isAiAnalyzing = false;
  String? _aiAnalysisText;
  final List<File> _progressPhotos = [];

  Future<void> _takeProgressPhoto() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null && mounted) {
      setState(() {
        _progressPhotos.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _analyzeEvolutionWithIA() async {
    if (!widget.isPremiumUser) {
      final dailyCalls =
          await widget.usageTrackerService.getDeepSeekApiCallCount();
      if (dailyCalls >= widget.usageTrackerService.deepSeekLimit) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Limite d'appels IA atteinte pour aujourd'hui."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isAiAnalyzing = true);

    final sortedEntries = List<WeightEntry>.from(widget.allWeightEntries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final String weights = sortedEntries
        .map(
          (e) => "${e.date.toIso8601String().substring(0, 10)}: ${e.weight}kg",
        )
        .join(", ");
    final String goal = widget.currentGoals.weightGoalType;

    final profileInfo = widget.userProfile != null ? '''
    Profil Utilisateur:
    - Sexe: ${widget.userProfile!.gender}
    - Age: ${widget.userProfile!.age}
    - Taille: ${widget.userProfile!.height} cm
    - Poids actuel: ${widget.userProfile!.weight} kg
    - Niveau d'activite: ${widget.userProfile!.activityLevel}
    - Condition physique: ${widget.userProfile!.physicalCondition}
    - Experience du jeune: ${widget.userProfile!.fastingExperience}
    - Qualite de l'alimentation: ${widget.userProfile!.dietQuality}
    - Tendance sucree: ${widget.userProfile!.tendsToEatSugary ? 'Oui' : 'Non'}
    - Tendance salee: ${widget.userProfile!.tendsToEatSalty ? 'Oui' : 'Non'}
    - Heures de sommeil: ${widget.userProfile!.sleepHours} h/nuit
    - Niveau de stress: ${widget.userProfile!.stressLevel}
    - Motivation principale: ${widget.userProfile!.mainMotivation}
    - Strict au plan: ${widget.userProfile!.planStrictness}/5
    - Aime cuisiner: ${widget.userProfile!.likesCooking ?? 'Non precise'}
    - Frequence cuisine: ${widget.userProfile!.cookingFrequency ?? 'Non precise'}
    - Sports aimes: ${widget.userProfile!.likedSports}
    - Sports detestes: ${widget.userProfile!.dislikedSports}
    - Equipement: ${widget.userProfile!.availableEquipment.join(', ')}
    ''' : 'Profil non disponible.';

    final prompt = '''
    Agis comme un coach de santé. Analyse l'évolution du poids de l'utilisateur.
    Objectif: $goal. 
    $profileInfo
    
    Historique de poids: $weights
    
    TÂCHE 1: Fournis UN SEUL paragraphe d'analyse et de recommandations ultra-personnalisées basées sur le sommeil, le stress, et l'alimentation.
    TÂCHE 2: Estime précisément le poids de l'utilisateur pour les 8 PROCHAINES SEMAINES (1 valeur par semaine).
    
    Renvoie le résultat au format JSON STRICT comme ceci:
    {
      "analysis": "Ton texte d'analyse ici",
      "projections": [70.5, 70.0, 69.5, 69.0, 68.5, 68.0, 67.5, 67.0]
    }
    IMPORTANT : "projections" DOIT être un tableau (Array) contenant EXACTEMENT 8 NOMBRES DÉCIMAUX (pas de string).
    ''';    try {
      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.5,
      );
      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();

        setState(() {
          _aiAnalysisText = result['analysis'];

          List<dynamic> projVals = result['projections'] ?? [];
          if (projVals.isNotEmpty && sortedEntries.isNotEmpty) {
            List<FlSpot> newSpots = [];
            final lastHistoricalSpot = FlSpot(
              (sortedEntries.length - 1).toDouble(),
              sortedEntries.last.weight,
            );
            newSpots.add(lastHistoricalSpot);
            double lastX = lastHistoricalSpot.x;
            DateTime lastDate = sortedEntries.last.date;

            List<Map<String, dynamic>> aiProjectionData = [];

            for (int i = 0; i < projVals.length; i++) {
              double val = (projVals[i] as num).toDouble();
              double newX = lastX + (i + 1);
              newSpots.add(FlSpot(newX, val));
              aiProjectionData.add({
                'date': lastDate.add(Duration(days: (i + 1) * 7)),
                'weight': val,
              });
            }

            _projectedSpots = newSpots;
            _projectionData = {
              'message':
                  "Les projections ci-dessus ont Ã©tÃ© gÃ©nÃ©rÃ©es par l'intelligence artificielle Mistral.",
              'projections': aiProjectionData,
              'time_message': "Projections IA activÃ©es",
            };
          }
        });
      } else {
        throw Exception('RÃ©ponse IA vide');
      }
    } catch (e) {
      debugPrint('Erreur IA: $e');
      if (mounted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur IA: RÃ©seau ou Serveur indisponible.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiAnalyzing = false);
    }
  }

  Future<void> _addWeightDialog() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null) return;
    _selectedDate = pickedDate;

    double initialWeight =
        widget.allWeightEntries
            .firstWhereOrNull((entry) => isSameDay(entry.date, _selectedDate))
            ?.weight ??
        (widget.allWeightEntries.isNotEmpty
            ? widget.allWeightEntries.last.weight
            : 70.0);
    _currentWeightInput = initialWeight;
    TextEditingController controller = TextEditingController(
      text: _currentWeightInput.toStringAsFixed(1),
    );

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Enregistrer le poids pour le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDate!)}',
            ),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Poids (kg)',
                suffixText: 'kg',
              ),
              onChanged:
                  (value) =>
                      _currentWeightInput =
                          double.tryParse(value) ?? _currentWeightInput,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_currentWeightInput > 0) {
                    Navigator.pop(ctx);
                    final existingEntry = widget.allWeightEntries
                        .firstWhereOrNull(
                          (e) => isSameDay(e.date, _selectedDate),
                        );
                    final entryToSave = WeightEntry(
                      id: existingEntry?.id,
                      date: _selectedDate!,
                      weight: _currentWeightInput,
                    );
                    widget.addWeightEntry(
                      entryToSave,
                    ); // Le didUpdateWidget se chargera de rafraÃ®chir
                  } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Veuillez entrer un poids valide."),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
    );
  }

  // CORRECTION: Le bouton de suppression rafraÃ®chit maintenant l'UI.
  void _showDeleteWeightDialog(WeightEntry entry) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer la pesÃ©e ?'),
            content: Text(
              'Voulez-vous vraiment supprimer la pesÃ©e du ${DateFormat('d MMMM', 'fr_FR').format(entry.date)} ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.deleteWeightEntry(
                    entry.id,
                  ); // Le didUpdateWidget se chargera de rafraÃ®chir
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }

  // CORRECTION: Algorithme de projection entiÃ¨rement revu pour plus de fiabilitÃ©.
  Map<String, dynamic> _getWeightProjections() {
    if (widget.userProfile == null) {
      return {
        'message': 'Profil utilisateur manquant.',
        'projections': [],
        'time_message': '',
      };
    }
    final sortedEntries = List<WeightEntry>.from(widget.allWeightEntries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final currentWeight =
        sortedEntries.isNotEmpty
            ? sortedEntries.last.weight
            : widget.userProfile!.weight;
    final goalType = widget.currentGoals.weightGoalType;
    final targetWeight = widget.currentGoals.targetWeight;

    // CAS 1: L'objectif est de maintenir le poids
    if (goalType == 'maintain') {
      List<Map<String, dynamic>> projections = [];
      for (int i = 1; i <= 8; i++) {
        projections.add({
          'date': DateTime.now().add(Duration(days: i * 7)),
          'weight': targetWeight,
        });
      }
      return {
        'message':
            'Votre objectif est de maintenir votre poids. La projection reste stable.',
        'projections': projections,
        'time_message': 'Objectif: ${targetWeight.toStringAsFixed(1)} kg',
      };
    }

    if (sortedEntries.length < 2) {
      return {
        'message': 'Ajoutez au moins deux pesÃ©es pour activer les projections.',
        'projections': [],
        'time_message': '',
      };
    }

    // CAS 2: Calcul pour perte ou gain de poids
    final profile = widget.userProfile!;
    final bmr =
        (profile.gender == 'male')
            ? (10 * profile.weight) +
                (6.25 * profile.height) -
                (5 * profile.age) +
                5
            : (10 * profile.weight) +
                (6.25 * profile.height) -
                (5 * profile.age) -
                161;

    double activityMultiplier;
    switch (profile.activityLevel) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'light':
        activityMultiplier = 1.375;
        break;
      case 'moderate':
        activityMultiplier = 1.55;
        break;
      case 'active':
        activityMultiplier = 1.725;
        break;
      case 'very_active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.55;
    }
    final tdee = bmr * activityMultiplier;

    double calorieBasedWeeklyChange = 0;
    final recentFoodEntries =
        widget.allFoodEntries
            .where(
              (e) => e.timestamp.isAfter(
                DateTime.now().subtract(const Duration(days: 14)),
              ),
            )
            .toList();
    if (recentFoodEntries.isNotEmpty) {
      final totalCaloriesConsumed = recentFoodEntries.fold(
        0.0,
        (sum, e) => sum + e.calories,
      );
      final uniqueDays =
          recentFoodEntries
              .map(
                (e) => DateTime(
                  e.timestamp.year,
                  e.timestamp.month,
                  e.timestamp.day,
                ),
              )
              .toSet()
              .length;
      if (uniqueDays > 0) {
        final averageDailyIntake = totalCaloriesConsumed / uniqueDays;
        final averageDailySurplus = averageDailyIntake - tdee;
        calorieBasedWeeklyChange = (averageDailySurplus * 7) / 7700;
      }
    }

    double weightBasedWeeklyChange = 0;
    final entryTwoWeeksAgo = sortedEntries.lastWhereOrNull(
      (e) => e.date.isBefore(
        sortedEntries.last.date.subtract(const Duration(days: 14)),
      ),
    );
    if (entryTwoWeeksAgo != null) {
      final weightDiff = currentWeight - entryTwoWeeksAgo.weight;
      final daysDiff =
          sortedEntries.last.date.difference(entryTwoWeeksAgo.date).inDays;
      if (daysDiff > 0) {
        weightBasedWeeklyChange = (weightDiff / daysDiff) * 7;
      }
    }

    double finalProjectionRate =
        weightBasedWeeklyChange.abs() > 0.1
            ? (weightBasedWeeklyChange * 0.7 + calorieBasedWeeklyChange * 0.3)
            : calorieBasedWeeklyChange;

    // MODIFICATION: On retire l'influence du sommeil et on garde celle de la diÃ¨te
    switch (profile.dietQuality) {
      case 'saine':
        finalProjectionRate *= 1.10;
        break;
      case 'peu_saine':
        finalProjectionRate *= 0.80;
        break;
      case 'moyenne':
      default:
        break;
    }
    if (profile.stressLevel == 'high') finalProjectionRate *= 0.90;
    // La qualitÃ© du sommeil n'influence plus la projection ici

    if (goalType == 'lose' && finalProjectionRate >= 0) {
      finalProjectionRate = -0.3;
    }
    if (goalType == 'gain' && finalProjectionRate <= 0) {
      finalProjectionRate = 0.15;
    }

    String timeMessage = '';
    String mainMessage =
        "BasÃ© sur vos donnÃ©es, l'algorithme estime une variation de ${finalProjectionRate.toStringAsFixed(2)} kg/semaine.";

    if (goalType == 'lose') {
      final weightToLose = currentWeight - targetWeight;
      if (weightToLose > 0 && finalProjectionRate < 0) {
        int weeksNeeded = (weightToLose / finalProjectionRate.abs()).ceil();
        timeMessage =
            "Ã€ ce rythme, vous pourriez atteindre votre objectif en environ $weeksNeeded semaines.";
      }
    } else if (goalType == 'gain') {
      final weightToGain = targetWeight - currentWeight;
      if (weightToGain > 0 && finalProjectionRate > 0) {
        int weeksNeeded = (weightToGain / finalProjectionRate.abs()).ceil();
        timeMessage =
            "Ã€ ce rythme, vous pourriez atteindre votre objectif en environ $weeksNeeded semaines.";
      }
    }

    List<Map<String, dynamic>> projections = [];
    double projectedWeight = currentWeight;
    for (int i = 1; i <= 8; i++) {
      projectedWeight += finalProjectionRate;
      projections.add({
        'date': DateTime.now().add(Duration(days: i * 7)),
        'weight': projectedWeight.clamp(40.0, 150.0),
      });
    }

    return {
      'message': mainMessage,
      'projections': projections,
      'time_message': timeMessage,
    };
  }

  Widget _buildProgressPhotoGallery() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Galerie de Progression',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_a_photo, color: Colors.teal),
                  onPressed: _takeProgressPhoto,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_progressPhotos.isEmpty)
              const Text(
                "Prenez une photo aujourd'hui pour dÃ©marrer votre journal visuel !",
                style: TextStyle(color: Colors.grey),
              )
            else
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _progressPhotos.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_progressPhotos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightChart() {
    if (widget.allWeightEntries.isEmpty) {
      return const Center(
        heightFactor: 5,
        child: Text(
          'Ajoutez au moins une pesÃ©e pour voir le graphique.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final sortedEntries = List<WeightEntry>.from(widget.allWeightEntries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final double targetWeight = widget.currentGoals.targetWeight;

    double minWeight = sortedEntries.map((e) => e.weight).reduce(min);
    double maxWeight = sortedEntries.map((e) => e.weight).reduce(max);
    if (targetWeight < minWeight) minWeight = targetWeight;
    if (targetWeight > maxWeight) maxWeight = targetWeight;
    if (_projectedSpots.isNotEmpty) {
      final projectedMin = _projectedSpots.map((e) => e.y).reduce(min);
      final projectedMax = _projectedSpots.map((e) => e.y).reduce(max);
      if (projectedMin < minWeight) minWeight = projectedMin;
      if (projectedMax > maxWeight) maxWeight = projectedMax;
    }
    minWeight = (minWeight - 2).clamp(0.0, double.infinity);
    maxWeight = maxWeight + 2;

    List<FlSpot> spots = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedEntries[i].weight));
    }

    List<LineChartBarData> lineBarsData = [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.darken(0.1),
            Theme.of(context).colorScheme.primary,
          ],
        ),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.3),
              Theme.of(context).colorScheme.primary.withOpacity(0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      if (_projectedSpots.length > 1)
        LineChartBarData(
          spots: _projectedSpots,
          isCurved: true,
          color: Colors.blueAccent,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          dashArray: [5, 5],
        ),
      if (sortedEntries.isNotEmpty)
        LineChartBarData(
          spots: [
            FlSpot(0, targetWeight),
            FlSpot(
              (_projectedSpots.isNotEmpty
                      ? _projectedSpots.last.x
                      : (sortedEntries.length - 1))
                  .toDouble(),
              targetWeight,
            ),
          ],
          isCurved: false,
          color: Colors.red.shade400,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          dashArray: [5, 5],
        ),
    ];

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < sortedEntries.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat(
                          'dd/MM',
                        ).format(sortedEntries[value.toInt()].date),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                interval: (sortedEntries.length / 5).ceil().toDouble().clamp(
                  1.0,
                  double.infinity,
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  );
                },
                interval: ((maxWeight - minWeight) / 4).clamp(
                  1.0,
                  double.infinity,
                ),
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          minX: 0,
          maxX: (_projectedSpots.isNotEmpty
                  ? _projectedSpots.last.x
                  : (sortedEntries.length - 1))
              .toDouble()
              .clamp(0.0, double.infinity),
          minY: minWeight,
          maxY: maxWeight,
          lineBarsData: lineBarsData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalType = widget.currentGoals.weightGoalType;
    String fabLabel = 'Enregistrer mon poids';
    if (goalType == 'gain') {
      fabLabel = 'Suivi prise de masse';
    } else if (goalType == 'lose')
      fabLabel = 'Suivi perte de poids';

    // Trier les entrÃ©es pour l'affichage de l'historique
    final reversedEntries = List<WeightEntry>.from(widget.allWeightEntries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ã‰volution et Projections'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Graphique d\'Ã‰volution du Poids',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ligne continue: Historique, PointillÃ©e: Projection, Rouge: Objectif',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildWeightChart(),
                        const SizedBox(height: 16),
                        Text(
                          'Dernier poids enregistrÃ© : ${widget.allWeightEntries.isNotEmpty ? widget.allWeightEntries.last.weight.toStringAsFixed(1) : "N/A"} kg.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Analyse et Projections',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: Colors.blueGrey.shade900),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.psychology,
                                    color: Colors.amber,
                                  ),
                                  onPressed:
                                      _isAiAnalyzing
                                          ? null
                                          : _analyzeEvolutionWithIA,
                                  tooltip: 'Analyse IA (Bilan)',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        if ((_projectionData['time_message'] as String?)
                                ?.isNotEmpty ??
                            false)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              _projectionData['time_message'],
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        Text(
                          _projectionData['message'] ?? 'Analyse en attente...',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (_isAiAnalyzing)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (_aiAnalysisText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _aiAnalysisText!,
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        _buildProgressPhotoGallery(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Historique des Mesures',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                reversedEntries.isEmpty
                    ? const Center(
                      child: Text(
                        'Aucune mesure de poids enregistrÃ©e.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : Column(
                      children:
                          reversedEntries.map((entry) {
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.scale,
                                  color: Colors.blueGrey,
                                ),
                                title: Text(
                                  DateFormat(
                                    'd MMMM yyyy',
                                    'fr_FR',
                                  ).format(entry.date),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${entry.weight.toStringAsFixed(1)} kg',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    // CORRECTION: Le bouton de suppression appelle la fonction corrigÃ©e
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed:
                                          () => _showDeleteWeightDialog(entry),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWeightDialog,
        label: Text(fabLabel),
        icon: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// =============================================================================
// RESTE DES ONGLETS (avec intÃ©gration Premium et UsageTracker)
// =============================================================================

class UserLimits {
  static const int freePhotoAnalysisPerDay = 1;
  static const int freeScanAnalysisPerDay = 5;
  static const int freeDeepSeekApiPerDay =
      5; // Used for text analysis, meal plans, etc.
}

class ProductDetailPage extends StatefulWidget {
  final String barcode;
  final Function(ScannedProduct) onProductScanned;
  final Function(FoodEntry) onAddFoodEntry;
  final bool isPremiumUser;
  final UsageTrackerService usageTrackerService;

  const ProductDetailPage({
    super.key,
    required this.barcode,
    required this.onProductScanned,
    required this.onAddFoodEntry,
    required this.isPremiumUser,
    required this.usageTrackerService,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool _isProcessing = false;
  bool _isAiAnalyzing = false;
  String? _errorMessage;

  String? _productName;
  String? _productCategory;
  String? _specificCategoryTag;
  String? _nutriScore;
  Map<String, dynamic>? _nutriments;
  Map<String, dynamic>? _ecoscoreData;
  String? _vegetarianStatus;
  String? _imageUrl;
  List<dynamic>? _additivesTags;

  double? _overallHealthScore;
  double? _categoryHealthScore;
  List<Map<String, dynamic>> _betterAlternatives = [];
  bool _alternativesSearchDone = false;

  List<Map<String, dynamic>>? _analyzedIngredients;
  String? _deepSeekOverallHealthVerdict;
  String? _deepSeekSummary;

  bool _isEcoScoreEstimated = false;
  String? _ecoScoreGrade;
  double? _ecoScoreValue;
  String? _lifecycleSummary;
  List<dynamic>? _bonusPoints;
  List<dynamic>? _malusPoints;
  String? _environmentalPerspective;
  List<dynamic>? _environmentalWarnings;
  String? _co2Info;
  Map<String, double>? _lifecycleBreakdown;

  String? _globalEcoScoreGrade;
  double? _globalEcoScoreValue;
  String? _globalEcoScoreJustification;

  @override
  void initState() {
    super.initState();
    _fetchAndAnalyzeProduct();
  }

  Future<void> _fetchAndAnalyzeProduct() async {
    _resetAllState();
    await fetchProductData(widget.barcode);
  }

  void _resetAllState() {
    setState(() {
      _isProcessing = true;
      _isAiAnalyzing = false;
      _productName = "Recherche en cours...";
      _errorMessage = null;
      _nutriScore = null;
      _nutriments = null;
      _ecoscoreData = null;
      _vegetarianStatus = null;
      _imageUrl = null;
      _overallHealthScore = null;
      _categoryHealthScore = null;
      _betterAlternatives = [];
      _alternativesSearchDone = false;
      _productCategory = null;
      _specificCategoryTag = null;
      _analyzedIngredients = null;
      _deepSeekOverallHealthVerdict = null;
      _deepSeekSummary = null;
      _isEcoScoreEstimated = false;
      _ecoScoreGrade = null;
      _ecoScoreValue = null;
      _lifecycleSummary = null;
      _bonusPoints = null;
      _malusPoints = null;
      _environmentalPerspective = null;
      _environmentalWarnings = null;
      _co2Info = null;
      _globalEcoScoreGrade = null;
      _globalEcoScoreValue = null;
      _globalEcoScoreJustification = null;
      _lifecycleBreakdown = null;
      _additivesTags = null;
    });
  }

  Future<void> fetchProductData(String barcode) async {
    final url = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,nutriscore_grade,nutriments,ingredients,categories_tags,categories,categories_hierarchy,ecoscore_data,ecoscore_grade,ecoscore_score,ingredients_analysis_tags,image_front_url,additives_tags',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          final productName = product['product_name'] ?? 'Nom non trouvÃ©';
          final productCategory = product['categories'] ?? 'CatÃ©gorie inconnue';

          setState(() {
            _productName = productName;
            _nutriScore = product['nutriscore_grade']?.toUpperCase() ?? 'N/A';
            _nutriments = product['nutriments'];
            _productCategory = productCategory;
            _ecoscoreData = product['ecoscore_data'];
            _ecoScoreGrade = product['ecoscore_grade']?.toUpperCase();
            _ecoScoreValue = (product['ecoscore_score'] as num?)?.toDouble();
            _imageUrl = product['image_front_url'];
            _additivesTags = product['additives_tags'];
            _isAiAnalyzing = true;
          });

          widget.onProductScanned(
            ScannedProduct(
              name: productName,
              barcode: barcode,
              imageUrl: _imageUrl,
              nutriScore: _nutriScore,
              scannedDate: DateTime.now(),
              rawData: product,
            ),
          );

          List<dynamic> analysisTags =
              product['ingredients_analysis_tags'] ?? [];
          if (analysisTags.contains('en:vegan')) {
            _vegetarianStatus = 'vegan';
          } else if (analysisTags.contains('en:vegetarian')) {
            _vegetarianStatus = 'vegetarian';
          } else if (analysisTags.contains('en:non-vegetarian')) {
            _vegetarianStatus = 'non-vegetarian';
          } else {
            _vegetarianStatus = 'unknown';
          }

          if (product['categories_hierarchy'] != null &&
              product['categories_hierarchy'].isNotEmpty) {
            _specificCategoryTag = product['categories_hierarchy'].last;
          } else if (product['categories_tags'] != null &&
              product['categories_tags'].isNotEmpty) {
            _specificCategoryTag = product['categories_tags'].first;
          }

          List<String> rawIngredientNames = [];
          if (product['ingredients'] != null &&
              (product['ingredients'] as List).isNotEmpty) {
            for (var ing in product['ingredients']) {
              String name = ing['text']?.toLowerCase() ?? '';
              if (name.isNotEmpty) rawIngredientNames.add(name);
            }
          }

          final bool canUseIA =
              widget.isPremiumUser ||
              await widget.usageTrackerService.getDeepSeekApiCallCount() <
                  widget.usageTrackerService.deepSeekLimit;

          if (canUseIA) {
            if (widget.isPremiumUser) {
              await Future.wait([
                _analyzeProductWithDeepSeek(
                  productName,
                  rawIngredientNames,
                  productCategory,
                  _vegetarianStatus!,
                ),
                _processEnvironmentalImpact(
                  productName,
                  rawIngredientNames,
                  productCategory,
                ),
                _analyzeGlobalEnvironmentalImpactWithDeepSeek(
                  productName,
                  rawIngredientNames,
                  productCategory,
                  _vegetarianStatus!,
                ),
              ]);
            } else {
              await _analyzeProductWithDeepSeek(
                productName,
                rawIngredientNames,
                productCategory,
                _vegetarianStatus!,
              );
              await _processEnvironmentalImpact(
                productName,
                rawIngredientNames,
                productCategory,
              );
              await _analyzeGlobalEnvironmentalImpactWithDeepSeek(
                productName,
                rawIngredientNames,
                productCategory,
                _vegetarianStatus!,
              );
            }
          } else {
            await _processEnvironmentalImpact(
              productName,
              rawIngredientNames,
              productCategory,
            );
            setState(
              () =>
                  _errorMessage =
                      "Limite d'appels IA atteinte pour aujourd'hui (version Free).",
            );
          }

          analyzeProduct(product);
          _calculateFinalOverallHealthScore();
          if (_specificCategoryTag != null) {
            await fetchBetterAlternatives(_specificCategoryTag!, barcode);
          }
          setState(() {
            _alternativesSearchDone = true;
          });
        } else {
          setState(
            () => _errorMessage = 'Produit non trouvÃ© pour ce code-barres.',
          );
        }
      } else {
        setState(() => _errorMessage = 'Erreur de connexion au serveur.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Une erreur est survenue : $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _isAiAnalyzing = false;
        if (_errorMessage != null) _productName = null;
      });
    }
  }

  Future<void> _processEnvironmentalImpact(
    String productName,
    List<String> rawIngredients,
    String category,
  ) async {
    setState(() {
      _bonusPoints = [];
      _malusPoints = [];
      _environmentalWarnings = [];
      _lifecycleSummary = null;
      _co2Info = null;
      _lifecycleBreakdown = null;
      _isEcoScoreEstimated = true;
    });

    if (_ecoscoreData != null && _ecoscoreData!['adjustments'] != null) {
      setState(() => _isEcoScoreEstimated = false);

      final adjustments = _ecoscoreData!['adjustments'];
      List<String> bonuses = [];
      List<String> maluses = [];
      List<String> warnings = [];

      if (adjustments['production_system'] != null) {
        final productionSystem = adjustments['production_system'];
        if (productionSystem['labels'] != null &&
            (productionSystem['labels'] as List).isNotEmpty) {
          for (var label in productionSystem['labels']) {
            bonuses.add(
              "Label: ${label.toString().replaceAll('en:', '').replaceAll('-', ' ').capitalize()}",
            );
          }
        }
      }

      if (adjustments['packaging'] != null) {
        final packaging = adjustments['packaging'];
        if (packaging['non_recyclable_and_non_biodegradable_materials'] ==
            '1') {
          maluses.add("Emballage non recyclable et non biodÃ©gradable");
        }
        if (packaging['packagings'] != null) {
          for (var pack in packaging['packagings']) {
            if (pack['recycling'] != 'en:recyclable' &&
                pack['recycling'] != 'en:unknown') {
              maluses.add(
                "MatÃ©riau d'emballage difficile Ã  recycler: ${pack['material'].toString().replaceAll('en:', '')}",
              );
            }
          }
        }
      }

      if (adjustments['threatened_species'] != null) {
        final threatened = adjustments['threatened_species'];
        if (threatened['ingredient'] != null) {
          String ingredient =
              threatened['ingredient']
                  .toString()
                  .replaceAll('en:', '')
                  .capitalize();
          warnings.add(
            "Contient une espÃ¨ce potentiellement menacÃ©e: $ingredient",
          );
        }
      }

      if (_ecoscoreData!['agribalyse'] != null) {
        final agribalyseData = _ecoscoreData!['agribalyse'];
        if (agribalyseData['co2_total'] != null) {
          final co2 = (agribalyseData['co2_total'] as num).toDouble();
          setState(() {
            _co2Info = "${co2.toStringAsFixed(2)} kg COâ‚‚eq / kg de produit";
          });
        }

        final Map<String, String> scoreMapping = {
          'score_agriculture': 'Agriculture',
          'score_consumption': 'Consommation',
          'score_distribution': 'Distribution',
          'score_packaging': 'Emballage',
          'score_processing': 'Transformation',
          'score_transportation': 'Transport',
        };

        Map<String, double> breakdown = {};
        double totalImpactPoints = 0;

        agribalyseData.forEach((key, value) {
          if (scoreMapping.containsKey(key) && value is num) {
            totalImpactPoints += value;
          }
        });

        if (totalImpactPoints > 0) {
          agribalyseData.forEach((key, value) {
            if (scoreMapping.containsKey(key) && value is num) {
              final percentage = (value / totalImpactPoints) * 100;
              if (percentage > 0.1) {
                breakdown[scoreMapping[key]!] = percentage;
              }
            }
          });
          if (breakdown.isNotEmpty) {
            setState(() {
              _lifecycleBreakdown = breakdown;
            });
          }
        }
      }

      setState(() {
        _bonusPoints = bonuses;
        _malusPoints = maluses;
        _environmentalWarnings = warnings;
        _lifecycleSummary =
            "Analyse basÃ©e sur les donnÃ©es officielles Eco-Score. L'impact est calculÃ© en fonction de l'origine des ingrÃ©dients, des mÃ©thodes de production, de l'emballage et des labels.";
      });
    } else {
      setState(() => _isEcoScoreEstimated = true);
      if (rawIngredients.isNotEmpty) {
        await _analyzeEnvironmentalImpactWithDeepSeek(
          productName,
          rawIngredients,
          category,
        );
      } else {
        await _deduceEnvironmentalImpactWithDeepSeek(productName, category);
      }
    }
  }

  Future<void> _runDeepSeekEnvironmentalAnalysis(
    String prompt, {
    bool isGlobalScore = false,
  }) async {
    // Increment API call counter
    await widget.usageTrackerService.incrementDeepSeekApiCall();
    try {
      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.4,
      );

      if (result != null) {
        if (isGlobalScore) {
          setState(() {
            _globalEcoScoreGrade = result['eco_score_grade'];
            _globalEcoScoreValue =
                (result['eco_score_value'] as num?)?.toDouble();
            _globalEcoScoreJustification = result['justification'];
          });
        } else {
          setState(() {
            _ecoScoreGrade ??= result['eco_score_grade'];
            _ecoScoreValue ??= (result['eco_score_value'] as num?)?.toDouble();
            _lifecycleSummary = result['lifecycle_summary'];
            if (_co2Info == null && result['co2_emissions'] != null) {
              _co2Info = result['co2_emissions'];
            }
            _bonusPoints = result['bonus_points'];
            _malusPoints = result['malus_points'];
            _environmentalPerspective = result['perspective'];
            _environmentalWarnings = result['warnings'];
          });
        }
      } else {
        print('DeepSeek: rÃ©ponse vide pour l\'analyse environnementale.');
      }
    } catch (e) {
      print('Erreur lors de l\'appel Ã  DeepSeek (Environnement): $e');
    }
  }

  Future<void> _analyzeEnvironmentalImpactWithDeepSeek(
    String productName,
    List<String> ingredients,
    String category,
  ) async {
    final String prompt = '''
    En tant qu'expert en analyse du cycle de vie des aliments, analyse l'impact environnemental du produit "$productName" (catÃ©gorie: "$category") basÃ© sur sa liste d'ingrÃ©dients: "${ingredients.join(', ')}".

    Fournis une rÃ©ponse au format JSON strict. Le JSON doit contenir :
    - "eco_score_grade": Une lettre de A Ã  E (A = TrÃ¨s faible impact, E = TrÃ¨s fort impact).
    - "eco_score_value": Une note chiffrÃ©e de 0 Ã  100 (0 = TrÃ¨s fort impact, 100 = TrÃ¨s faible impact).
    - "lifecycle_summary": Un rÃ©sumÃ© dÃ©taillÃ© de l'analyse du cycle de vie. Justifie ton estimation en te basant sur les ingrÃ©dients fournis (ex: "La prÃ©sence de boeuf augmente fortement l'empreinte carbone...", "Le transport de cacao a un impact significatif...").
    - "co2_emissions": Une estimation textuelle des Ã©missions de CO2. Exemple: "EstimÃ© Ã  1.5 kg COâ‚‚eq / kg de produit". Si impossible, mets null.
    - "bonus_points": Une liste de 2-3 points positifs potentiels basÃ©s sur les ingrÃ©dients ou le processus. (Ex: "Agriculture biologique", "Emballage recyclable").
    - "malus_points": Une liste de 2-3 points nÃ©gatifs probables basÃ©s sur les ingrÃ©dients ou le processus. (Ex: "IngrÃ©dients importÃ©s de loin", "Emballage non recyclable").
    - "perspective": Un court paragraphe de mise en perspective comparant l'impact de ce produit Ã  des produits similaires ou d'autres catÃ©gories. (Ex: "Bien que son score soit moyen, son impact reste bien infÃ©rieur Ã  celui de la viande rouge...", ou "En tant que produit transformÃ©, son impact est plus Ã©levÃ© que celui des lÃ©gumes bruts.").
    - "warnings": Une liste de points de vigilance importants. Identifie les ingrÃ©dients ou aspects pouvant Ãªtre liÃ©s Ã  des problÃ©matiques sensibles (dÃ©forestation, surpÃªche, espÃ¨ces menacÃ©es, utilisation excessive de pesticides). Sois prudent et factuel. (Ex: "L'huile de palme est souvent associÃ©e Ã  la dÃ©forestation.", "Le thon peut provenir de stocks menacÃ©s.").
    ''';
    await _runDeepSeekEnvironmentalAnalysis(prompt);
  }

  Future<void> _deduceEnvironmentalImpactWithDeepSeek(
    String productName,
    String category,
  ) async {
    final String prompt = '''
    En tant qu'expert en analyse du cycle de vie des aliments, DÃ‰DUIS l'impact environnemental probable du produit "$productName" (catÃ©gorie: "$category"), pour lequel la liste d'ingrÃ©dients est manquante. Base-toi sur les ingrÃ©dients et processus typiques de cette catÃ©gorie.

    Fournis une rÃ©ponse au format JSON strict. Le JSON doit contenir :
    - "eco_score_grade": Une lettre de A Ã  E (A = TrÃ¨s faible impact, E = TrÃ¨s fort impact).
    - "eco_score_value": Une note chiffrÃ©e de 0 Ã  100 (0 = TrÃ¨s fort impact, 100 = TrÃ¨s faible impact).
    - "lifecycle_summary": Un rÃ©sumÃ© dÃ©taillÃ© de l'analyse du cycle de vie dÃ©duite. Justifie ton estimation en mentionnant les ingrÃ©dients probables (ex: "Contient probablement de l'huile de palme et du sucre dont la production peut avoir un impact...", "Le transport de ces produits transformÃ©s augmente l'empreinte.").
    - "co2_emissions": Une estimation textuelle des Ã©missions de CO2. Exemple: "Environ 0.8 kg COâ‚‚eq / kg de produit". Si impossible, mets null.
    - "bonus_points": Une liste de 2-3 points positifs potentiels basÃ©s sur ta dÃ©duction.
    - "malus_points": Une liste de 2-3 points nÃ©gatifs probables basÃ©s sur ta dÃ©duction.
    - "perspective": Un court paragraphe de mise en perspective comparant l'impact probable de ce produit Ã  des produits similaires ou d'autres catÃ©gories. (Ex: "L'impact d'une pÃ¢te Ã  tartiner est gÃ©nÃ©ralement Ã©levÃ© Ã  cause du cacao et de l'huile de palme, mais reste infÃ©rieur Ã  celui de la plupart des produits carnÃ©s.").
    - "warnings": Une liste de points de vigilance probables (ex: "Forte probabilitÃ© de contenir de l'huile de palme, associÃ©e Ã  la dÃ©forestation.", "PrÃ©sence probable de substances controversÃ©es.").
    ''';
    await _runDeepSeekEnvironmentalAnalysis(prompt);
  }

  Future<void> _analyzeGlobalEnvironmentalImpactWithDeepSeek(
    String productName,
    List<String> rawIngredients,
    String category,
    String knownVegStatus,
  ) async {
    String ingredientsList =
        rawIngredients.isEmpty
            ? "liste des ingrÃ©dients non fournie"
            : rawIngredients.join(', ');

    final String prompt = '''
    En tant qu'expert en impact environnemental alimentaire global, Ã©value l'Ã©co-score GLOBAL du produit "$productName" (catÃ©gorie: "$category", ingrÃ©dients: "$ingredientsList", statut vÃ©gÃ©tarien/vÃ©gÃ©talien connu: "$knownVegStatus").

    Ta mission est de fournir une note qui reflÃ¨te l'impact rÃ©el de ce produit par rapport Ã  l'ENSEMBLE du systÃ¨me alimentaire, et pas seulement par rapport Ã  sa propre catÃ©gorie. Tu dois comparer son impact Ã  celui d'autres grandes catÃ©gories comme les lÃ©gumes frais, les lÃ©gumineuses, la volaille, la viande rouge (bÅ“uf), les produits laitiers, et les aliments ultra-transformÃ©s. Par exemple, une pÃ¢te Ã  tartiner (cacao, huile de palme) et un steak hachÃ© industriel ont tous deux des impacts nÃ©gatifs, mais tu dois dÃ©terminer lequel est globalement plus dommageable pour la planÃ¨te et justifier pourquoi.

    Fournis une rÃ©ponse au format JSON strict. Le JSON doit contenir :
    - "eco_score_grade": Une lettre de A Ã  E (A = TrÃ¨s faible impact global, E = TrÃ¨s fort impact global).
    - "eco_score_value": Une note chiffrÃ©e de 0 Ã  100 (0 = TrÃ¨s fort impact global, 100 = TrÃ¨s faible impact global).
    - "justification": Un paragraphe dÃ©taillÃ© expliquant la note globale. Commence par situer le produit sur le spectre global de l'impact alimentaire. Ensuite, justifie en comparant explicitement le produit Ã  d'autres catÃ©gories. Par exemple: "Ce produit carnÃ© a un impact intrinsÃ¨quement Ã©levÃ© comparÃ© aux alternatives vÃ©gÃ©tales, mÃªme si sa production est optimisÃ©e. L'Ã©levage bovin est un contributeur majeur au mÃ©thane, un gaz Ã  effet de serre bien plus puissant que le CO2, et requiert d'Ã©normes surfaces agricoles, contribuant Ã  la dÃ©forestation. Son impact est donc bien supÃ©rieur Ã  celui des plats prÃ©parÃ©s vÃ©gÃ©tariens, malgrÃ© leur transformation." ou "Bien que ce produit soit ultra-transformÃ© et contienne des ingrÃ©dients comme l'huile de palme potentiellement liÃ©s Ã  la dÃ©forestation, son impact global reste infÃ©rieur Ã  celui de la plupart des produits d'origine animale comme le fromage ou la viande rouge, en raison des Ã©missions de gaz Ã  effet de serre et de l'utilisation des terres beaucoup plus faibles."
    ''';
    await _runDeepSeekEnvironmentalAnalysis(prompt, isGlobalScore: true);
  }

  Future<void> _analyzeProductWithDeepSeek(
    String productName,
    List<String> rawIngredients,
    String category,
    String knownVegStatus,
  ) async {
    if (rawIngredients.isEmpty) {
      setState(() {
        _deepSeekSummary =
            "Analyse des ingrÃ©dients impossible car la liste n'est pas fournie.";
      });
      return;
    }
    await widget.usageTrackerService.incrementDeepSeekApiCall();
    final String ingredientsList = rawIngredients.join(', ');
    final String prompt = '''
    En tant qu'expert en nutrition et alimentation, analyse le produit "$productName" avec les ingrÃ©dients suivants: "$ingredientsList". Le statut connu est "$knownVegStatus".
    IMPORTANT: N'analyse PAS les additifs (codes E) dans la liste 'analyzed_ingredients', ils sont gÃ©rÃ©s sÃ©parÃ©ment. Concentre-toi sur les autres ingrÃ©dients.

    Fournis une rÃ©ponse au format JSON strict. Le JSON doit contenir:
    - "analyzed_ingredients": Une liste oÃ¹ chaque Ã©lÃ©ment est un objet pour les ingrÃ©dients NON-ADDITIFS avec:
        - "name": Le nom de l'ingrÃ©dient.
        - "description": Une brÃ¨ve description de son rÃ´le et son impact sur la santÃ©.
        - "category": Une catÃ©gorie simple ("Sucre", "CÃ©rÃ©ale", "Huile VÃ©gÃ©tale", "Sel", "Fruit", "LÃ©gume", "Autre").
        - "health_score": Une note de santÃ© de 1 Ã  5 (1=TrÃ¨s mauvais, 5=TrÃ¨s bon).
    - "overall_health_verdict": Un verdict global concis ("Excellent", "Bon", "Moyen", "MÃ©diocre", "Ã€ Ã©viter").
    - "health_summary": Un rÃ©sumÃ© de 2-3 phrases expliquant le verdict, en mettant en avant les points forts et faibles.
    - "vegetarian_status_analysis": Un objet avec "status" ('vegan', 'vegetarian', ou 'non-vegetarian') et "justification" dÃ©duisant le statut le plus probable en te basant sur les ingrÃ©dients, surtout si le statut connu est "unknown". Justifie briÃ¨vement.
    ''';
    try {
      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.3,
      );

      if (result != null) {
        setState(() {
          _analyzedIngredients = List<Map<String, dynamic>>.from(
            result['analyzed_ingredients'],
          );
          _deepSeekOverallHealthVerdict = result['overall_health_verdict'];
          _deepSeekSummary = result['health_summary'];
          if (_vegetarianStatus == 'unknown') {
            _vegetarianStatus =
                result['vegetarian_status_analysis']?['status'] ?? 'unknown';
          }
        });
      } else {
        print('DeepSeek: rÃ©ponse vide pour l\'analyse des ingrÃ©dients.');
      }
    } catch (e) {
      print('Erreur lors de l\'appel Ã  DeepSeek (IngrÃ©dients): $e');
    }
  }

  void _calculateFinalOverallHealthScore() {
    double baseScore = 0.0;
    int scoreCount = 0;

    if (_nutriScore != null) {
      baseScore += calculateOverallHealthScore(_nutriScore);
      scoreCount++;
    }
    if (_categoryHealthScore != null) {
      baseScore += _categoryHealthScore!;
      scoreCount++;
    }
    if (_deepSeekOverallHealthVerdict != null) {
      double deepSeekIngrScore = 0.0;
      switch (_deepSeekOverallHealthVerdict?.toLowerCase()) {
        case 'excellent':
          deepSeekIngrScore = 9.5;
          break;
        case 'bon':
          deepSeekIngrScore = 7.5;
          break;
        case 'moyen':
          deepSeekIngrScore = 5.0;
          break;
        case 'mÃ©diocre':
        case 'Ã  Ã©viter':
          deepSeekIngrScore = 1.0;
          break;
        default:
          deepSeekIngrScore = 5.0;
      }
      baseScore += deepSeekIngrScore;
      scoreCount++;
    }

    if (scoreCount > 0) {
      setState(() {
        _overallHealthScore = (baseScore / scoreCount).clamp(0.0, 10.0);
      });
    } else if (_nutriScore != null) {
      setState(() {
        _overallHealthScore = calculateOverallHealthScore(_nutriScore);
      });
    } else {
      setState(() {
        _overallHealthScore = null;
      });
    }
  }

  void analyzeProduct(Map<String, dynamic> product) {
    _nutriments = product['nutriments'];
    if (_nutriments == null) return;
    String category = _specificCategoryTag?.replaceAll('en:', '') ?? 'unknown';
    _categoryHealthScore = calculateCategoryScore(_nutriments!, category);
  }

  double calculateOverallHealthScore(String? nutriScore) {
    switch (nutriScore?.toLowerCase()) {
      case 'a':
        return 9.5;
      case 'b':
        return 7.5;
      case 'c':
        return 5.0;
      case 'd':
        return 2.5;
      case 'e':
        return 1.0;
      default:
        return 5.0;
    }
  }

  double calculateCategoryScore(
    Map<String, dynamic> nutriments,
    String category,
  ) {
    double sugar = (nutriments['sugars_100g'] as num?)?.toDouble() ?? 0.0;
    double saturatedFat =
        (nutriments['saturated-fat_100g'] as num?)?.toDouble() ?? 0.0;
    double salt = (nutriments['salt_100g'] as num?)?.toDouble() ?? 0.0;
    double score = 10.0;

    if (category.contains('candies') || category.contains('sweets')) {
      if (sugar > 60) {
        score -= 6;
      } else if (sugar > 40)
        score -= 3;
      if (saturatedFat > 5) score -= 2;
    } else if (category.contains('cereals')) {
      if (sugar > 25) {
        score -= 5;
      } else if (sugar > 15)
        score -= 3;
      if (saturatedFat > 5) score -= 2;
    } else {
      if (sugar > 22.5) {
        score -= 3;
      } else if (sugar > 10)
        score -= 1.5;
      if (saturatedFat > 10) {
        score -= 3;
      } else if (saturatedFat > 5)
        score -= 1.5;
      if (salt > 1.8) {
        score -= 3;
      } else if (salt > 1.2)
        score -= 1.5;
    }
    return score < 0 ? 0 : score;
  }

  Future<void> fetchBetterAlternatives(
    String categoryTag,
    String originalBarcode,
  ) async {
    final searchUrl = Uri.https('world.openfoodfacts.org', '/api/v2/search', {
      'categories_tags_en': categoryTag.replaceAll('en:', ''),
      'page_size': '25',
      'json': 'true',
      'fields':
          'code,product_name,nutriscore_grade,image_front_small_url,nutriments',
    });
    try {
      final response = await http.get(searchUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] == null) return;

        List<Map<String, dynamic>> candidates = List<Map<String, dynamic>>.from(
          data['products'],
        );
        List<Map<String, dynamic>> allAlternatives = [];

        for (var cand in candidates) {
          if (cand['code'] != originalBarcode) {
            double candidateScore = calculateCategoryScore(
              cand['nutriments'] ?? {},
              categoryTag,
            );
            cand['category_score'] = candidateScore;
            allAlternatives.add(cand);
          }
        }
        allAlternatives.sort(
          (a, b) => (b['category_score'] as double).compareTo(
            a['category_score'] as double,
          ),
        );
        setState(() {
          _betterAlternatives = allAlternatives.take(5).toList();
        });
      }
    } catch (e) {
      print("Erreur lors de la recherche d'alternatives : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DÃ©tails du Produit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(child: _buildBodyContent()),
      floatingActionButton:
          _nutriments != null && !_isProcessing
              ? FloatingActionButton.extended(
                onPressed: () {
                  if (_productName != null &&
                      _nutriments!['energy-kcal_100g'] != null) {
                    widget.onAddFoodEntry(
                      FoodEntry(
                        name: _productName!,
                        calories:
                            (_nutriments!['energy-kcal_100g'] as num).toInt(),
                        proteins:
                            (_nutriments!['proteins_100g'] as num?)
                                ?.toDouble() ??
                            0.0,
                        carbs:
                            (_nutriments!['carbohydrates_100g'] as num?)
                                ?.toDouble() ??
                            0.0,
                        fats:
                            (_nutriments!['fat_100g'] as num?)?.toDouble() ??
                            0.0,
                        timestamp: DateTime.now(),
                        mealType: MealType.unknown,
                        source: 'Scan OFF',
                      ),
                    );
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${_productName!}" ajoutÃ© Ã  votre journal !',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Impossible d\'ajouter au journal: donnÃ©es nutritionnelles manquantes.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                label: const Text('Ajouter au journal'),
                icon: const Icon(Icons.add_shopping_cart),
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBodyContent() {
    if (_isProcessing && !_isAiAnalyzing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text(
          _errorMessage!,
          style: TextStyle(
            fontSize: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_productName == null || _productName == "Recherche en cours...") {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Text(
          'Scannez un code-barres pour commencer l\'analyse',
          style: TextStyle(fontSize: 18, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return buildResults();
  }

  Widget buildResults() {
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (_imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.network(
                          _imageUrl!,
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => const Icon(
                                Icons.image_not_supported,
                                size: 100,
                                color: Colors.grey,
                              ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _productName!,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (_productCategory != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _productCategory!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_overallHealthScore != null)
                            Flexible(
                              child: ScoreCircle(
                                score: _overallHealthScore!,
                                title: 'Score SantÃ©',
                              ),
                            ),
                          if (_ecoScoreValue != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Flexible(
                                child: ScoreCircle(
                                  score: _ecoScoreValue!,
                                  title:
                                      _isEcoScoreEstimated
                                          ? 'Eco-Score (IA)'
                                          : 'Eco-Score OFF',
                                  isEnvironmental: true,
                                  letterScore: _ecoScoreGrade,
                                ),
                              ),
                            ),
                          if (_globalEcoScoreValue != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Flexible(
                                child: ScoreCircle(
                                  score: _globalEcoScoreValue!,
                                  title: 'Impact Global (IA)',
                                  isEnvironmental: true,
                                  letterScore: _globalEcoScoreGrade,
                                ),
                              ),
                            ),
                          if (_categoryHealthScore != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Flexible(
                                child: ScoreCircle(
                                  score: _categoryHealthScore!,
                                  title: 'Note CatÃ©gorie',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isAiAnalyzing)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text(
                              "Analyse par l'IA en cours...",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.health_and_safety), text: 'SantÃ©'),
                    Tab(icon: Icon(Icons.eco), text: 'Environnement'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(children: [_buildHealthTab(), _buildEnvironmentTab()]),
      ),
    );
  }

  Widget _buildHealthTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (_vegetarianStatus != null)
          ProductStatusCard(status: _vegetarianStatus!),
        if (_nutriScore != null && _nutriScore != 'N/A')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nutri-Score Officiel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Image.network(
                    'https://static.openfoodfacts.org/images/attributes/nutriscore-${_nutriScore!.toLowerCase()}.png',
                    height: 40,
                    errorBuilder:
                        (c, e, s) => Text(
                          _nutriScore!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        if (_deepSeekSummary != null)
          AnalysisCard(
            title: "Analyse des IngrÃ©dients par l'IA",
            content: _deepSeekSummary!,
            verdict: _deepSeekOverallHealthVerdict,
          ),
        if (_nutriments != null)
          NutrimentDetailsCard(
            nutriments: _nutriments!,
            specificCategoryTag: _specificCategoryTag,
          ),
        if (_additivesTags != null && _additivesTags!.isNotEmpty)
          AdditivesCard(additivesTags: _additivesTags!),
        if (_analyzedIngredients != null && _analyzedIngredients!.isNotEmpty)
          IngredientAnalysisCard(analyzedIngredients: _analyzedIngredients!),
        if (_alternativesSearchDone)
          Padding(
            padding: const EdgeInsets.only(top: 24.0, bottom: 80.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Meilleures alternatives dans la mÃªme catÃ©gorie",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (_betterAlternatives.isNotEmpty)
                  ..._betterAlternatives.map(
                    (alt) => ComparisonProductCard(alternative: alt),
                  )
                else
                  const Text(
                    "Aucune meilleure alternative trouvÃ©e dans cette catÃ©gorie.",
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEnvironmentTab() {
    bool hasData =
        _lifecycleSummary != null ||
        _environmentalPerspective != null ||
        (_bonusPoints != null && _bonusPoints!.isNotEmpty) ||
        (_malusPoints != null && _malusPoints!.isNotEmpty) ||
        (_environmentalWarnings != null &&
            _environmentalWarnings!.isNotEmpty) ||
        _globalEcoScoreGrade != null ||
        _globalEcoScoreValue != null ||
        _co2Info != null;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (_globalEcoScoreValue != null &&
            _globalEcoScoreJustification != null)
          GlobalImpactCard(
            scoreValue: _globalEcoScoreValue!,
            scoreGrade: _globalEcoScoreGrade,
            justification: _globalEcoScoreJustification!,
          ),
        if (_lifecycleBreakdown != null)
          LifecycleBreakdownCard(breakdownData: _lifecycleBreakdown!),
        if (hasData)
          EnvironmentalImpactCard(
            isEstimated: _isEcoScoreEstimated,
            lifecycleSummary: _lifecycleSummary,
            bonusPoints: _bonusPoints,
            malusPoints: _malusPoints,
            perspective: _environmentalPerspective,
            warnings: _environmentalWarnings,
            co2Info: _co2Info,
          ),
        if (!hasData && !_isAiAnalyzing)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                "Aucune donnÃ©e environnementale dÃ©taillÃ©e disponible pour ce produit.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
      ],
    );
  }
}

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

class CaloriesTab extends StatefulWidget {
  final List<FoodEntry> foodLog;
  final List<ScannedProduct> scannedProductsHistory;
  final Function(FoodEntry) addFoodEntry;
  final Function(String) deleteFoodEntry;
  final Function(String) onScanProduct;
  final bool isPremiumUser;
  final UsageTrackerService usageTrackerService;

  const CaloriesTab({
    super.key,
    required this.foodLog,
    required this.scannedProductsHistory,
    required this.addFoodEntry,
    required this.deleteFoodEntry,
    required this.onScanProduct,
    required this.isPremiumUser,
    required this.usageTrackerService,
  });

  @override
  _CaloriesTabState createState() => _CaloriesTabState();
}

class _CaloriesTabState extends State<CaloriesTab> {
  DateTime _selectedDate = DateTime.now();
  MealType _selectedMealFilter = MealType.unknown;

  List<FoodEntry> get _filteredFoodLog {
    return widget.foodLog.where((entry) {
      final bool sameDay = isSameDay(entry.timestamp, _selectedDate);
      final bool matchesMealType =
          _selectedMealFilter == MealType.unknown ||
          entry.mealType == _selectedMealFilter;
      return sameDay && matchesMealType;
    }).toList();
  }

  Future<Map<String, dynamic>?> _searchProductInOpenFoodFacts(
    String query,
  ) async {
    final searchUrl = Uri.https('world.openfoodfacts.org', '/api/v2/search', {
      'search_terms': query,
      'page_size': '1',
      'json': 'true',
      'fields': 'product_name,nutriments,code',
    });

    try {
      final response = await http.get(searchUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] != null && (data['products'] as List).isNotEmpty) {
          final product = data['products'][0];
          return product;
        }
      }
    } catch (e) {
      print("Erreur de recherche Open Food Facts: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> _estimateCaloriesFromApi(
    String input, {
    bool isImage = false,
  }) async {
    final String prompt;

    if (isImage) {
      prompt = '''
      Analyze the following food item(s) described as: "${input.split('/').last}".
      Provide a STRICT JSON output with:
      - "food_name": A concise name for the food (e.g., "Chicken and rice with broccoli").
      - "calories": Estimated total calories (integer).
      - "proteins": Estimated total proteins in grams (double).
      - "carbs": Estimated total carbohydrates in grams (double).
      - "fats": Estimated total fats in grams (double).
      Make a reasonable estimation for an average portion.
      ''';
    } else {
      prompt = '''
      Analyze the following food items: "$input".
      Provide a STRICT JSON output with:
      - "food_name": A concise name for the food (e.g., "Chicken and rice with broccoli").
      - "calories": Estimated total calories (integer).
      - "proteins": Estimated total proteins in grams (double).
      - "carbs": Estimated total carbohydrates in grams (double).
      - "fats": Estimated total fats in grams (double).
      Make a reasonable estimation for an average portion.
      ''';
    }

    try {
      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.5,
      );
      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();
        return {
          'name': result['food_name'] ?? 'Repas estimÃ©',
          'calories': result['calories'] ?? 0,
          'proteins': (result['proteins'] as num?)?.toDouble() ?? 0.0,
          'carbs': (result['carbs'] as num?)?.toDouble() ?? 0.0,
          'fats': (result['fats'] as num?)?.toDouble() ?? 0.0,
        };
      }
    } catch (e) {
      debugPrint('Error calling DeepSeek API: $e');
    }

    return {
      'name':
          isImage
              ? 'Repas par photo (IA - Ã©chec)'
              : 'Repas par texte (IA - Ã©chec)',
      'calories': 0,
      'proteins': 0.0,
      'carbs': 0.0,
      'fats': 0.0,
    };
  }

  Future<void> _addFoodManually() async {
    String name = '';
    int calories = 0;
    double proteins = 0.0;
    double carbs = 0.0;
    double fats = 0.0;
    MealType? selectedMealType = _deduceMealTypeFromTime(DateTime.now());

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ajouter un aliment manuellement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nom de l\'aliment',
                  ),
                  onChanged: (value) => name = value,
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Calories (kcal)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => calories = int.tryParse(value) ?? 0,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'ProtÃ©ines (g)'),
                  keyboardType: TextInputType.number,
                  onChanged:
                      (value) => proteins = double.tryParse(value) ?? 0.0,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Glucides (g)'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => carbs = double.tryParse(value) ?? 0.0,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Lipides (g)'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => fats = double.tryParse(value) ?? 0.0,
                ),
                DropdownButtonFormField<MealType>(
                  initialValue: selectedMealType,
                  decoration: const InputDecoration(labelText: 'Type de repas'),
                  items:
                      MealType.values
                          .where((type) => type != MealType.unknown)
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.toCapitalizedString()),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMealType = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.isNotEmpty && calories > 0) {
                  widget.addFoodEntry(
                    FoodEntry(
                      name: name,
                      calories: calories,
                      proteins: proteins,
                      carbs: carbs,
                      fats: fats,
                      timestamp: _selectedDate,
                      mealType: selectedMealType ?? MealType.unknown,
                      source: 'Manuel',
                    ),
                  );
                  Navigator.pop(ctx);
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Veuillez remplir au moins le nom et les calories.",
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addFoodWithIntelligentInput(
    String input, {
    bool isPhoto = false,
  }) async {
    // 1. Check AI limits for photo analysis
    if (isPhoto && !widget.isPremiumUser) {
      final photoAnalysisCount =
          await widget.usageTrackerService.getPhotoAnalysisCount();
      if (photoAnalysisCount >= UserLimits.freePhotoAnalysisPerDay) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Vous avez atteint la limite de 1 analyse photo IA par jour (version Free). Passez au Premium pour un usage illimitÃ© !",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await widget.usageTrackerService.incrementPhotoAnalysis();
    }

    // 2. Recherche dans l'historique des scans des 14 derniers jours
    final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));
    ScannedProduct? historicalProduct;
    if (!isPhoto) {
      historicalProduct = widget.scannedProductsHistory.firstWhereOrNull(
        (p) =>
            p.scannedDate.isAfter(fourteenDaysAgo) &&
            p.name.toLowerCase().contains(input.toLowerCase()),
      );
    }

    if (historicalProduct != null && historicalProduct.rawData != null) {
      final nutriments = historicalProduct.rawData!['nutriments'];
      if (nutriments != null && nutriments['energy-kcal_100g'] != null) {
        widget.addFoodEntry(
          FoodEntry(
            name: historicalProduct.name,
            calories: (nutriments['energy-kcal_100g'] as num).toInt(),
            proteins: (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0,
            carbs:
                (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0,
            fats: (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0,
            timestamp: _selectedDate,
            mealType: _deduceMealTypeFromTime(_selectedDate),
            source: 'Historique Scan OFF',
          ),
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${historicalProduct.name}" ajoutÃ© depuis l\'historique des scans !',
            ),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
    }

    // 3. Recherche sur Open Food Facts
    if (!isPhoto) {
      final offProduct = await _searchProductInOpenFoodFacts(input);
      if (offProduct != null &&
          offProduct['nutriments'] != null &&
          offProduct['nutriments']['energy-kcal_100g'] != null) {
        widget.addFoodEntry(
          FoodEntry(
            name: offProduct['product_name'],
            calories:
                (offProduct['nutriments']['energy-kcal_100g'] as num).toInt(),
            proteins:
                (offProduct['nutriments']['proteins_100g'] as num?)
                    ?.toDouble() ??
                0.0,
            carbs:
                (offProduct['nutriments']['carbohydrates_100g'] as num?)
                    ?.toDouble() ??
                0.0,
            fats:
                (offProduct['nutriments']['fat_100g'] as num?)?.toDouble() ??
                0.0,
            timestamp: _selectedDate,
            mealType: _deduceMealTypeFromTime(_selectedDate),
            source: 'Open Food Facts',
          ),
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${offProduct['product_name']}" ajoutÃ© depuis Open Food Facts !',
            ),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
    }

    // 4. Estimation par IA (pour les aliments non trouvÃ©s ou les ingrÃ©dients sans code-barres)
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Recherche dans Open Food Facts et analyse IA en cours...",
        ),
      ),
    );
    try {
      final result = await _estimateCaloriesFromApi(input, isImage: isPhoto);
      if (result['calories'] > 0) {
        widget.addFoodEntry(
          FoodEntry(
            name: result['name'],
            calories: result['calories'],
            proteins: result['proteins'],
            carbs: result['carbs'],
            fats: result['fats'],
            timestamp: _selectedDate,
            isAiEstimated: true,
            mealType: _deduceMealTypeFromTime(_selectedDate),
            source: isPhoto ? 'IA Image' : 'IA Texte',
          ),
        );
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Repas estimÃ© et ajoutÃ© par l'IA : ${result['name']} !",
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "L'IA n'a pas pu estimer les calories de maniÃ¨re fiable.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'estimation par IA: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _estimateCaloriesFromImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      _addFoodWithIntelligentInput(image.path, isPhoto: true);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aucune image sÃ©lectionnÃ©e."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _estimateCaloriesFromText() async {
    String foodDescription = '';
    MealType? selectedMealType = _deduceMealTypeFromTime(DateTime.now());

    if (!widget.isPremiumUser) {
      final dailyCalls =
          await widget.usageTrackerService.getDeepSeekApiCallCount();
      if (dailyCalls >= widget.usageTrackerService.deepSeekLimit) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Vous avez atteint la limite de 5 appels DeepSeek par jour (version Free). Passez au Premium pour un usage illimitÃ© !",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('DÃ©crire votre repas pour l\'IA'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Ex: "100g de poulet, 50g de riz, brocolis"',
                ),
                onChanged: (value) => foodDescription = value,
                maxLines: 3,
              ),
              DropdownButtonFormField<MealType>(
                initialValue: selectedMealType,
                decoration: const InputDecoration(labelText: 'Type de repas'),
                items:
                    MealType.values
                        .where((type) => type != MealType.unknown)
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.toCapitalizedString()),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedMealType = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (foodDescription.isNotEmpty) {
                  Navigator.pop(ctx);
                  await _addFoodWithIntelligentInput(
                    foodDescription,
                    isPhoto: false,
                  );
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Veuillez dÃ©crire votre repas."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Estimer'),
            ),
          ],
        );
      },
    );
  }

  void _scanProduct() {
    widget.onScanProduct('from_calories_tab');
  }

  MealType _deduceMealTypeFromTime(DateTime time) {
    if (time.hour >= 5 && time.hour < 10) return MealType.breakfast;
    if (time.hour >= 10 && time.hour < 14) return MealType.lunch;
    if (time.hour >= 14 && time.hour < 18) return MealType.snack;
    if (time.hour >= 18 && time.hour < 22) return MealType.dinner;
    return MealType.snack;
  }

  Future<void> _showAddFoodDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Wrap(
              runSpacing: 10,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Ajout Manuel'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addFoodManually();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.purple),
                  title: Text(
                    widget.isPremiumUser
                        ? 'Estimer avec une Photo (IA)'
                        : 'Estimer avec une Photo (IA - 1/jour)',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _estimateCaloriesFromImage();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.restaurant_menu,
                    color: Colors.teal,
                  ),
                  title: const Text('CrÃ©er une recette personnalisÃ©e'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newRecipeFood = await Navigator.push<FoodEntry>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecipeBuilderScreen(),
                      ),
                    );
                    if (newRecipeFood != null) {
                      widget.addFoodEntry(newRecipeFood);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Recette ajoutÃ©e : ${newRecipeFood.name}',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.text_fields, color: Colors.orange),
                  title: Text(
                    widget.isPremiumUser
                        ? 'Estimer depuis un Texte (IA)'
                        : 'Estimer depuis un Texte (IA - 5/jour)',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _estimateCaloriesFromText();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.green,
                  ),
                  title: const Text('Scanner un Produit'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _scanProduct();
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi des Calories'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2200),
                      );
                      if (picked != null && picked != _selectedDate) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDate),
                    ),
                    style: ElevatedButton.styleFrom(elevation: 2),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<MealType>(
                  value: _selectedMealFilter,
                  icon: const Icon(Icons.filter_list),
                  underline: const SizedBox(),
                  onChanged: (MealType? newValue) {
                    setState(() {
                      _selectedMealFilter = newValue!;
                    });
                  },
                  items: <DropdownMenuItem<MealType>>[
                    const DropdownMenuItem(
                      value: MealType.unknown,
                      child: Text('Tous les repas'),
                    ),
                    ...MealType.values
                        .where((type) => type != MealType.unknown)
                        .map((MealType type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.toCapitalizedString()),
                          );
                        })
                        ,
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _filteredFoodLog.isEmpty
                    ? const Center(
                      child: Text(
                        'Aucun aliment enregistrÃ© pour ce jour/filtre. Ajoutez-en un !',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                      itemCount: _filteredFoodLog.length,
                      itemBuilder: (context, index) {
                        final entry = _filteredFoodLog[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: Icon(
                              _getMealIcon(entry.mealType),
                              color: Theme.of(context).primaryColor,
                            ),
                            title: Text(
                              entry.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.proteins.toStringAsFixed(0)}P / ${entry.carbs.toStringAsFixed(0)}G / ${entry.fats.toStringAsFixed(0)}L',
                                ),
                                if (entry.isAiEstimated)
                                  Text(
                                    'EstimÃ© par IA (${entry.source})',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              '${entry.calories} kcal',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onLongPress: () {
                              _showDeleteFoodEntryDialog(entry);
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFoodDialog,
        label: const Text('Ajouter un aliment'),
        icon: const Icon(Icons.add),
        heroTag: 'addFoodFab',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  IconData _getMealIcon(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_sunny;
      case MealType.lunch:
        return Icons.restaurant;
      case MealType.dinner:
        return Icons.nights_stay;
      case MealType.snack:
        return Icons.cookie;
      case MealType.unknown:
        return Icons.fastfood;
    }
  }

  void _showDeleteFoodEntryDialog(FoodEntry entry) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer cet aliment ?'),
            content: Text(
              'Voulez-vous vraiment supprimer "${entry.name}" de votre journal ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.deleteFoodEntry(entry.id);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }
}

extension ListExtensions<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }

  // MÃ‰THODE AJOUTÃ‰E POUR CORRIGER L'ERREUR
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) {
        return this[i];
      }
    }
    return null;
  }
}

// =============================================================================
// NOUVELLE PAGE DE JEÃ›NE (REFACTORISÃ‰E)
// =============================================================================

// --- ModÃ¨les de donnÃ©es pour le jeÃ»ne ---

class FastingPlan {
  final String id;
  final String name;
  final String description;
  final String level; // DÃ©butant, IntermÃ©diaire, AvancÃ©
  final Duration fastingDuration;
  final Duration eatingDuration;
  final List<String> goals; // 'Perte de poids', 'DÃ©tox', etc.
  final String exampleSchedule;
  final bool isPremium;

  FastingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    required this.fastingDuration,
    required this.eatingDuration,
    required this.goals,
    required this.exampleSchedule,
    this.isPremium = false,
  });
}

class FastingStage {
  final String title;
  final String description;
  final Duration startHour;
  final IconData icon;

  FastingStage({
    required this.title,
    required this.description,
    required this.startHour,
    required this.icon,
  });
}

// --- DonnÃ©es pour les plans et Ã©tapes ---
final List<FastingPlan> predefinedFastingPlans = [
  FastingPlan(
    id: '12-12',
    name: '12:12 Le Circadien',
    description:
        'Le point de dÃ©part idÃ©al pour dÃ©couvrir le jeÃ»ne intermittent et aligner son horloge biologique.',
    level: 'ðŸŸ¢ DÃ©butant',
    fastingDuration: const Duration(hours: 12),
    eatingDuration: const Duration(hours: 12),
    goals: ['Bien-Ãªtre', 'maintain'],
    exampleSchedule: 'Manger de 7h Ã  19h.',
  ),
  FastingPlan(
    id: '14-10',
    name: '14:10 Douce Progression',
    description:
        'Une Ã©tape douce pour augmenter progressivement la durÃ©e du jeÃ»ne et ses bÃ©nÃ©fices.',
    level: 'ðŸŸ¢ DÃ©butant',
    fastingDuration: const Duration(hours: 14),
    eatingDuration: const Duration(hours: 10),
    goals: ['lose', 'maintain'],
    exampleSchedule: 'Manger de 8h Ã  18h.',
  ),
  FastingPlan(
    id: '16-8',
    name: '16:8 Le Classique',
    description:
        'Le plan le plus populaire, Ã©quilibrÃ© pour la perte de poids et le bien-Ãªtre mÃ©tabolique.',
    level: 'ðŸŸ¡ IntermÃ©diaire',
    fastingDuration: const Duration(hours: 16),
    eatingDuration: const Duration(hours: 8),
    goals: ['lose', 'gain'],
    exampleSchedule: 'Manger de 12h Ã  20h.',
  ),
  FastingPlan(
    id: '18-6',
    name: '18:6 Le ConcentrÃ©',
    description:
        'Approfondit les bÃ©nÃ©fices du 16:8 avec une fenÃªtre d\'alimentation plus courte.',
    level: 'ðŸŸ¡ IntermÃ©diaire',
    fastingDuration: const Duration(hours: 18),
    eatingDuration: const Duration(hours: 6),
    goals: ['lose', 'gain'],
    exampleSchedule: 'Manger de 14h Ã  20h.',
  ),
  FastingPlan(
    id: '20-4',
    name: '20:4 Le Guerrier',
    description:
        'Un jeÃ»ne plus intense pour ceux qui cherchent Ã  maximiser l\'autophagie et la perte de graisse.',
    level: 'ðŸ”´ AvancÃ©',
    fastingDuration: const Duration(hours: 20),
    eatingDuration: const Duration(hours: 4),
    goals: ['lose'],
    exampleSchedule: 'Manger sur une fenÃªtre de 4h.',
    isPremium: true,
  ),
  FastingPlan(
    id: 'omad',
    name: 'OMAD (23:1)',
    description:
        'Un seul repas par jour. Maximise les effets du jeÃ»ne. RecommandÃ© aux jeÃ»neurs expÃ©rimentÃ©s.',
    level: 'ðŸ”´ AvancÃ©',
    fastingDuration: const Duration(hours: 23),
    eatingDuration: const Duration(hours: 1),
    goals: ['lose'],
    exampleSchedule: 'Manger sur une fenÃªtre de 1h.',
    isPremium: true,
  ),
  FastingPlan(
    id: '36h',
    name: 'JeÃ»ne de 36h',
    description:
        'Un jeÃ»ne prolongÃ© (1 jour sur 2) pour un "reset" mÃ©tabolique profond. A n\'effectuer qu\'occasionnellement.',
    level: 'â­ Expert',
    fastingDuration: const Duration(hours: 36),
    eatingDuration: const Duration(hours: 12),
    goals: ['lose', 'detox'],
    exampleSchedule: 'JeÃ»ner un jour complet.',
    isPremium: true,
  ),
];

final List<FastingStage> fastingStages = [
  FastingStage(
    title: "Anabolisme (0-4h)",
    description:
        "Le corps digÃ¨re et utilise l'Ã©nergie du dernier repas. Le taux d'insuline est Ã©levÃ©.",
    startHour: const Duration(hours: 0),
    icon: Icons.restaurant,
  ),
  FastingStage(
    title: "Catabolisme (4-12h)",
    description:
        "Le corps a fini de digÃ©rer. Les rÃ©serves de glycogÃ¨ne sont utilisÃ©es pour l'Ã©nergie. L'insuline baisse.",
    startHour: const Duration(hours: 4),
    icon: Icons.battery_charging_full,
  ),
  FastingStage(
    title: "CÃ©tose (12-16h)",
    description:
        "Les rÃ©serves de glycogÃ¨ne s'Ã©puisent. Le corps commence Ã  brÃ»ler les graisses stockÃ©es (cÃ©tones).",
    startHour: const Duration(hours: 12),
    icon: Icons.local_fire_department,
  ),
  FastingStage(
    title: "Autophagie (16h+)",
    description:
        "Le processus de nettoyage cellulaire dÃ©marre, recyclant les vieilles cellules pour rÃ©gÃ©nÃ©rer le corps.",
    startHour: const Duration(hours: 16),
    icon: Icons.recycling,
  ),
  FastingStage(
    title: "Hormone de Croissance (24h+)",
    description:
        "Pic de production de l'hormone de croissance, favorisant la rÃ©paration musculaire et la combustion des graisses.",
    startHour: const Duration(hours: 24),
    icon: Icons.trending_up,
  ),
  FastingStage(
    title: "RÃ©gÃ©nÃ©ration (36h+)",
    description:
        "L'autophagie est Ã  son maximum, favorisant une rÃ©gÃ©nÃ©ration cellulaire profonde.",
    startHour: const Duration(hours: 36),
    icon: Icons.health_and_safety,
  ),
];

// =============================================================================
// NOUVEAUX MODÃˆLES DE DONNÃ‰ES POUR LE PROGRAMME DE JEÃ›NE
// =============================================================================

/// ReprÃ©sente le statut d'un jeÃ»ne planifiÃ© dans le programme.
enum FastingStatus {
  scheduled, // PrÃ©vu mais pas encore fait
  completedSuccess, // TerminÃ© avec succÃ¨s (objectif atteint ou dÃ©passÃ©)
  completedPartial, // TerminÃ© mais sans atteindre l'objectif de durÃ©e
  skipped, // Jour passÃ© sans que le jeÃ»ne ait Ã©tÃ© fait
  adhoc, // Un jeÃ»ne non prÃ©vu qui a Ã©tÃ© ajoutÃ©
}

/// ReprÃ©sente une seule entrÃ©e de jeÃ»ne dans le programme mensuel.
class FastingProgramEntry {
  final DateTime date;
  final Duration targetDuration;
  final String planId; // e.g., '16-8', '20-4'
  FastingStatus status;
  String?
  actualSessionId; // Lien vers l'ID de la FastingSession dans l'historique

  FastingProgramEntry({
    required this.date,
    required this.targetDuration,
    required this.planId,
    this.status = FastingStatus.scheduled,
    this.actualSessionId,
  });

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'targetDurationSeconds': targetDuration.inSeconds,
    'planId': planId,
    'status': status.name,
    'actualSessionId': actualSessionId,
  };

  factory FastingProgramEntry.fromFirestore(Map<String, dynamic> json) =>
      FastingProgramEntry(
        date: (json['date'] as Timestamp).toDate(),
        targetDuration: Duration(seconds: json['targetDurationSeconds']),
        planId: json['planId'],
        status: FastingStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => FastingStatus.scheduled,
        ),
        actualSessionId: json['actualSessionId'],
      );
}

/// ReprÃ©sente le programme de jeÃ»ne complet pour un mois.
class MonthlyFastingProgram {
  final String id; // Format 'YYYY-MM'
  final List<FastingProgramEntry> entries;
  final bool generatedByAI;

  MonthlyFastingProgram({
    required this.id,
    required this.entries,
    this.generatedByAI = false,
  });

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'entries': entries.map((e) => e.toFirestore()).toList(),
    'generatedByAI': generatedByAI,
  };

  factory MonthlyFastingProgram.fromFirestore(
    Map<String, dynamic> json,
    String docId,
  ) => MonthlyFastingProgram(
    id: json['id'] ?? docId,
    entries:
        (json['entries'] as List<dynamic>)
            .map((e) => FastingProgramEntry.fromFirestore(e))
            .toList(),
    generatedByAI: json['generatedByAI'] ?? false,
  );
}

// =============================================================================
// NOUVEAU SERVICE POUR LA GÃ‰NÃ‰RATION DU PROGRAMME DE JEÃ›NE
// =============================================================================

// NOUVEAU SERVICE POUR LA GÃ‰NÃ‰RATION DU PROGRAMME DE JEÃ›NE
class FastingProgramService {
  final UserProfile userProfile;
  final DailyGoal goals;
  final bool isVip;

  FastingProgramService({
    required this.userProfile,
    required this.goals,
    required this.isVip,
  });

  /// Point d'entrÃ©e principal pour gÃ©nÃ©rer le programme du mois.
  /// L'adherenceRate (0.0 Ã  1.0) permet d'ajuster la difficultÃ©.
  MonthlyFastingProgram generateProgramForCurrentMonth({
    double adherenceRate = 1.0,
  }) {
    final now = DateTime.now();
    return generateProgramForMonth(
      targetMonth: now,
      adherenceRate: adherenceRate,
    );
  }

  /// GÃ©nÃ¨re un programme pour un mois spÃ©cifique.
  MonthlyFastingProgram generateProgramForMonth({
    required DateTime targetMonth,
    double adherenceRate = 1.0,
  }) {
    final monthId = DateFormat('yyyy-MM').format(targetMonth);
    final daysInMonth =
        DateTime(targetMonth.year, targetMonth.month + 1, 0).day;

    // Pour les VIP, on simule une gÃ©nÃ©ration par IA plus complexe
    return _generateSmartProgram(
      monthId,
      targetMonth,
      daysInMonth,
      adherenceRate,
    );
  }

  /// GÃ©nÃ©ration intelligente pour tous les utilisateurs, avec plus de fonctionnalitÃ©s pour les VIP.
  MonthlyFastingProgram _generateSmartProgram(
    String monthId,
    DateTime now,
    int daysInMonth,
    double adherenceRate,
  ) {
    final List<FastingProgramEntry> entries = [];
    final random = Random();

    // 1. DÃ©finir la difficultÃ© de base selon l'expÃ©rience de l'utilisateur
    List<String> allowedPlans;
    switch (userProfile.fastingExperience) {
      case 'expert':
        allowedPlans = ['16-8', '18-6', '20-4', 'omad'];
        break;
      case 'intermediate':
        allowedPlans = ['14-10', '16-8', '18-6'];
        break;
      case 'beginner':
      default:
        allowedPlans = ['12-12', '14-10', '16-8'];
        break;
    }

    // 2. DÃ©finir la frÃ©quence de base selon l'objectif principal
    int baseFastsPerWeek;
    switch (goals.weightGoalType) {
      case 'lose':
        baseFastsPerWeek = 4;
        break;
      case 'gain':
        baseFastsPerWeek = 2;
        allowedPlans.removeWhere(
          (p) => p == '20-4' || p == 'omad',
        ); // Ã‰viter les jeÃ»nes longs pour la prise de masse
        break;
      case 'maintain':
      default:
        baseFastsPerWeek = 3;
        break;
    }

    // 3. Ajuster la frÃ©quence en fonction du taux de suivi (adherenceRate)
    int adjustedFastsPerWeek = baseFastsPerWeek;
    if (adherenceRate < 0.5) {
      // Si l'utilisateur a du mal Ã  suivre
      adjustedFastsPerWeek = (baseFastsPerWeek - 1).clamp(1, 7);
      // On retire le plan le plus difficile pour ce cycle
      if (allowedPlans.length > 1) allowedPlans.removeLast();
    } else if (adherenceRate > 0.85 && random.nextBool()) {
      // Si l'utilisateur suit trÃ¨s bien
      adjustedFastsPerWeek = (baseFastsPerWeek + 1).clamp(1, 7);
    }

    // 4. GÃ©nÃ©rer les entrÃ©es pour le mois
    for (int day = 1; day <= daysInMonth; day++) {
      if (random.nextInt(7) < adjustedFastsPerWeek) {
        final date = DateTime(now.year, now.month, day);
        final planId = allowedPlans[random.nextInt(allowedPlans.length)];
        final plan = predefinedFastingPlans.firstWhere((p) => p.id == planId);
        entries.add(
          FastingProgramEntry(
            date: date,
            targetDuration: plan.fastingDuration,
            planId: plan.id,
          ),
        );
      }
    }

    // Pour inciter au passage VIP, on ajoute un jeÃ»ne "premium" par mois si non-VIP
    if (!isVip && entries.length < daysInMonth) {
      final premiumPlan = predefinedFastingPlans.firstWhereOrNull(
        (p) => p.isPremium,
      );
      if (premiumPlan != null) {
        int randomDay;
        do {
          randomDay = 1 + random.nextInt(daysInMonth);
        } while (entries.any((e) => e.date.day == randomDay));

        entries.add(
          FastingProgramEntry(
            date: DateTime(now.year, now.month, randomDay),
            targetDuration: premiumPlan.fastingDuration,
            planId: premiumPlan.id,
          ),
        );
      }
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    return MonthlyFastingProgram(
      id: monthId,
      entries: entries,
      generatedByAI: isVip,
    );
  }
}

/// Enum pour les jours de la semaine (pour la lisibilitÃ©)
class DayOfWeek {
  static const int monday = 1;
  static const int tuesday = 2;
  static const int wednesday = 3;
  static const int thursday = 4;
  static const int friday = 5;
  static const int saturday = 6;
  static const int sunday = 7;
}

// =============================================================================
// CLASSE FastingTab ENTIÃˆREMENT RÃ‰Ã‰CRITE
// =============================================================================

class FastingTab extends StatefulWidget {
  final List<FastingSession> fastingHistory;
  final Function(FastingSession) addFastingSession;
  final Function(String) deleteFastingSession;
  final bool isPremiumUser;
  final DailyGoal currentGoals;
  final FirestoreService firestoreService;
  final UserProfile userProfile;

  const FastingTab({
    super.key,
    required this.fastingHistory,
    required this.addFastingSession,
    required this.deleteFastingSession,
    required this.isPremiumUser,
    required this.currentGoals,
    required this.firestoreService,
    required this.userProfile,
  });

  @override
  _FastingTabState createState() => _FastingTabState();
}

class _FastingTabState extends State<FastingTab> {
  // --- State pour le timer de jeÃ»ne actif ---
  Timer? _timer;
  bool _isFastingActive = false;
  DateTime? _fastStartTime;
  Duration _targetDurationForActiveFast = Duration.zero;
  Duration _elapsedTime = Duration.zero;
  String? _activePlanId;

  // --- State pour le programme mensuel ---
  MonthlyFastingProgram? _currentMonthProgram;
  bool _isLoadingProgram = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeFastingState();
  }

  @override
  void didUpdateWidget(covariant FastingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si l'objectif change, on rÃ©gÃ©nÃ¨re tous les programmes futurs
    if (oldWidget.currentGoals.weightGoalType !=
            widget.currentGoals.weightGoalType ||
        oldWidget.currentGoals.targetWeight !=
            widget.currentGoals.targetWeight) {
      _regenerateAllPrograms();
    }
  }

  Future<void> _regenerateAllPrograms() async {
    if (!mounted) return;
    setState(() => _isLoadingProgram = true);
    // Supprimer les programmes existants et rÃ©gÃ©nÃ©rer sur 3 mois
    await _generateProgramsForUpcomingMonths(
      numMonths: 3,
      forceRegenerate: true,
    );
    await _loadOrGenerateProgramForCurrentMonth();
    if (mounted) setState(() => _isLoadingProgram = false);
  }

  /// GÃ©nÃ¨re les programmes pour les N prochains mois (sans Ã©craser si dÃ©jÃ  existants).
  Future<void> _generateProgramsForUpcomingMonths({
    int numMonths = 3,
    bool forceRegenerate = false,
  }) async {
    if (widget.firestoreService.userId == null) return;
    final now = DateTime.now();
    final adherence = _calculateAdherenceRate();
    final programService = FastingProgramService(
      userProfile: widget.userProfile,
      goals: widget.currentGoals,
      isVip: widget.isPremiumUser,
    );

    for (int i = 0; i < numMonths; i++) {
      final targetMonth = DateTime(now.year, now.month + i, 1);
      final monthId = DateFormat('yyyy-MM').format(targetMonth);

      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.firestoreService.userId)
                .collection('fastingPrograms')
                .doc(monthId)
                .get();

        if (!doc.exists || forceRegenerate) {
          final newProgram = programService.generateProgramForMonth(
            targetMonth: targetMonth,
            adherenceRate: i == 0 ? adherence : (adherence * 0.9 + 0.1),
          );
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.firestoreService.userId)
              .collection('fastingPrograms')
              .doc(monthId)
              .set(newProgram.toFirestore());
        }
      } catch (e) {
        print("Erreur gÃ©nÃ©ration mois $monthId: $e");
      }
    }
  }

  Future<void> _initializeFastingState() async {
    await _loadActiveFastingStateFromPrefs();
    await _generateProgramsForUpcomingMonths(numMonths: 3);
    await _loadOrGenerateProgramForCurrentMonth();
    if (mounted) {
      setState(() => _isLoadingProgram = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // =======================================================================
  // GESTION DU PROGRAMME MENSUEL (MODIFIÃ‰)
  // =======================================================================

  /// NOUVEAU: Calcule le taux de suivi des jours passÃ©s ce mois-ci.
  double _calculateAdherenceRate() {
    if (_currentMonthProgram == null) {
      return 1.0; // Taux par dÃ©faut pour un nouveau programme
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final pastEntries =
        _currentMonthProgram!.entries
            .where((e) => e.date.isBefore(today))
            .toList();

    if (pastEntries.isEmpty) {
      return 1.0; // Pas encore de jour passÃ©, on ne pÃ©nalise pas
    }

    final successfulEntries =
        pastEntries
            .where((e) => e.status == FastingStatus.completedSuccess)
            .length;

    return successfulEntries / pastEntries.length;
  }

  Future<void> _loadOrGenerateProgramForCurrentMonth() async {
    final monthId = DateFormat('yyyy-MM').format(_focusedDay);

    try {
      final doc =
          widget.firestoreService.userId != null
              ? await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.firestoreService.userId)
                  .collection('fastingPrograms')
                  .doc(monthId)
                  .get()
              : null;

      if (doc != null && doc.exists) {
        final program = MonthlyFastingProgram.fromFirestore(
          doc.data()!,
          doc.id,
        );
        if (mounted) setState(() => _currentMonthProgram = program);
      } else {
        final adherence = _calculateAdherenceRate();
        final programService = FastingProgramService(
          userProfile: widget.userProfile,
          goals: widget.currentGoals,
          isVip: widget.isPremiumUser,
        );
        final newProgram = programService.generateProgramForMonth(
          targetMonth: _focusedDay,
          adherenceRate: adherence,
        );

        if (widget.firestoreService.userId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.firestoreService.userId)
              .collection('fastingPrograms')
              .doc(monthId)
              .set(newProgram.toFirestore());
        }
        if (mounted) setState(() => _currentMonthProgram = newProgram);
      }
      _updatePastProgramEntries();
    } catch (e) {
      print("Erreur lors du chargement/gÃ©nÃ©ration du programme de jeÃ»ne: $e");
    }
  }

  Future<void> _updatePastProgramEntries() async {
    if (_currentMonthProgram == null || !mounted) return;

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    bool needsUpdate = false;

    for (var entry in _currentMonthProgram!.entries) {
      if (entry.date.isBefore(today) &&
          entry.status == FastingStatus.scheduled) {
        entry.status = FastingStatus.skipped;
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      setState(() {
        /* Met Ã  jour l'UI avec le statut 'skipped' */
      });
      if (widget.firestoreService.userId != null) {
        final monthId = DateFormat('yyyy-MM').format(_focusedDay);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.firestoreService.userId)
            .collection('fastingPrograms')
            .doc(monthId)
            .set(_currentMonthProgram!.toFirestore());
      }
    }
  }

  // =======================================================================
  // GESTION DU JEÃ›NE ACTIF (TIMER)
  // =======================================================================

  Future<void> _loadActiveFastingStateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isFastingActive = prefs.getBool('isFastingActive') ?? false;
      if (_isFastingActive) {
        final startTimeMillis = prefs.getInt('fastStartTime');
        final targetSeconds = prefs.getInt('targetDurationForActiveFast');
        _activePlanId = prefs.getString('activePlanId');

        if (startTimeMillis != null && targetSeconds != null) {
          _fastStartTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
          _targetDurationForActiveFast = Duration(seconds: targetSeconds);
          _startTimer();
        } else {
          _stopFast(saveSession: false, wasCancelled: true);
        }
      }
    });
  }

  Future<void> _saveActiveFastingStateToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFastingActive', _isFastingActive);
    if (_isFastingActive && _fastStartTime != null) {
      await prefs.setInt(
        'fastStartTime',
        _fastStartTime!.millisecondsSinceEpoch,
      );
      await prefs.setInt(
        'targetDurationForActiveFast',
        _targetDurationForActiveFast.inSeconds,
      );
      if (_activePlanId != null) {
        await prefs.setString('activePlanId', _activePlanId!);
      } else {
        await prefs.remove('activePlanId');
      }
    } else {
      await prefs.remove('fastStartTime');
      await prefs.remove('targetDurationForActiveFast');
      await prefs.remove('activePlanId');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _fastStartTime == null) {
        timer.cancel();
        return;
      }
      setState(() => _elapsedTime = DateTime.now().difference(_fastStartTime!));
    });
  }

  void _startFast({
    required Duration targetDuration,
    required DateTime startTime,
    String? planId,
  }) {
    setState(() {
      _isFastingActive = true;
      _fastStartTime = startTime;
      _targetDurationForActiveFast = targetDuration;
      _activePlanId = planId;
      _elapsedTime = DateTime.now().difference(startTime);
      _startTimer();
    });
    _saveActiveFastingStateToPrefs();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'JeÃ»ne de ${_formatSessionDuration(targetDuration)} dÃ©marrÃ© !',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _stopFast({bool saveSession = true, bool wasCancelled = false}) {
    _timer?.cancel();

    if (saveSession && _isFastingActive && _fastStartTime != null) {
      final session = FastingSession(
        startTime: _fastStartTime!,
        endTime: DateTime.now(),
        duration: DateTime.now().difference(_fastStartTime!),
        targetDuration: _targetDurationForActiveFast,
        notes:
            wasCancelled
                ? 'Session annulÃ©e'
                : 'Plan: ${_activePlanId ?? "Ad-hoc"}',
      );
      widget.addFastingSession(session);
      _updateProgramOnFastCompletion(session);
    }

    if (mounted) {
      setState(() {
        _isFastingActive = false;
        _fastStartTime = null;
        _elapsedTime = Duration.zero;
        _targetDurationForActiveFast = Duration.zero;
        _activePlanId = null;
      });
    }
    _saveActiveFastingStateToPrefs();
  }

  Future<void> _updateProgramOnFastCompletion(FastingSession session) async {
    if (_currentMonthProgram == null) return;

    final entryIndex = _currentMonthProgram!.entries.indexWhere(
      (e) => isSameDay(e.date, session.startTime),
    );

    if (entryIndex != -1) {
      final entry = _currentMonthProgram!.entries[entryIndex];
      entry.actualSessionId = session.id;
      entry.status =
          session.duration >= entry.targetDuration
              ? FastingStatus.completedSuccess
              : FastingStatus.completedPartial;
    } else {
      _currentMonthProgram!.entries.add(
        FastingProgramEntry(
          date: session.startTime,
          targetDuration: session.targetDuration ?? session.duration,
          planId: "Ad-hoc",
          status: FastingStatus.adhoc,
          actualSessionId: session.id,
        ),
      );
    }

    if (widget.firestoreService.userId != null) {
      final monthId = DateFormat('yyyy-MM').format(_focusedDay);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.firestoreService.userId)
          .collection('fastingPrograms')
          .doc(monthId)
          .set(_currentMonthProgram!.toFirestore());
    }
    if (mounted) setState(() {});
  }

  /// Ajoute un jeÃ»ne ad-hoc Ã  la date donnÃ©e dans le programme.
  Future<void> _addFastingToProgram(FastingPlan plan, DateTime date) async {
    if (_currentMonthProgram == null) return;

    final newEntry = FastingProgramEntry(
      date: DateTime(date.year, date.month, date.day),
      targetDuration: plan.fastingDuration,
      planId: plan.id,
      status: FastingStatus.scheduled,
    );

    setState(() {
      _currentMonthProgram!.entries.add(newEntry);
      _currentMonthProgram!.entries.sort((a, b) => a.date.compareTo(b.date));
    });

    if (widget.firestoreService.userId != null) {
      final monthId = DateFormat('yyyy-MM').format(date);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.firestoreService.userId)
          .collection('fastingPrograms')
          .doc(monthId)
          .set(_currentMonthProgram!.toFirestore());
    }

    if (mounted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'JeÃ»ne ${plan.name} ajoutÃ© le ${DateFormat('d MMM', 'fr_FR').format(date)} !',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  // =======================================================================
  // CONSTRUCTION DE L'UI (WIDGETS)
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Programme de JeÃ»ne'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isFastingActive)
            TextButton.icon(
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
              label: const Text(
                'TERMINER',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => _showStopFastDialog(),
            ),
        ],
      ),
      body:
          _isLoadingProgram
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  if (_isFastingActive) _buildActiveTracker(),
                  _buildCalendarView(),
                  const SizedBox(height: 24),
                  _buildDailyActionCard(),
                  const SizedBox(height: 24),
                  _buildHistoryView(),
                ],
              ),
    );
  }

  Widget _buildCalendarView() {
    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          locale: 'fr_FR',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected:
              (selectedDay, focusedDay) => setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              }),
          onPageChanged: (focusedDay) {
            final prevMonth = _focusedDay.month;
            setState(() => _focusedDay = focusedDay);
            if (focusedDay.month != prevMonth) {
              _loadOrGenerateProgramForCurrentMonth();
            }
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              final entry = _currentMonthProgram?.entries.firstWhereOrNull(
                (e) => isSameDay(e.date, date),
              );
              if (entry == null) return null;

              IconData icon;
              Color color;
              switch (entry.status) {
                case FastingStatus.scheduled:
                  icon = Icons.timer_outlined;
                  color = Colors.blueGrey;
                  break;
                case FastingStatus.completedSuccess:
                  icon = Icons.check_circle;
                  color = Colors.green;
                  break;
                case FastingStatus.completedPartial:
                  icon = Icons.check_circle_outline;
                  color = Colors.orange;
                  break;
                case FastingStatus.skipped:
                  icon = Icons.cancel_outlined;
                  color = Colors.red;
                  break;
                case FastingStatus.adhoc:
                  icon = Icons.add_circle;
                  color = Colors.purple;
                  break;
              }
              return Positioned(
                right: 1,
                bottom: 1,
                child: Icon(icon, size: 18, color: color),
              );
            },
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
        ),
      ),
    );
  }

  Widget _buildDailyActionCard() {
    final entryForSelectedDay = _currentMonthProgram?.entries.firstWhereOrNull(
      (e) => isSameDay(e.date, _selectedDay),
    );
    final plan =
        entryForSelectedDay != null
            ? predefinedFastingPlans.firstWhereOrNull(
              (p) => p.id == entryForSelectedDay.planId,
            )
            : null;
    final bool isPastDay = _selectedDay.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );
    final bool isFutureDay = _selectedDay.isAfter(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDay),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (entryForSelectedDay != null && plan != null) ...[
              Text(
                'Plan du jour : ${plan.name} (${_formatSessionDuration(plan.fastingDuration)})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _getLevelColor(plan.level),
                ),
                textAlign: TextAlign.center,
              ),
              if (plan.isPremium && !widget.isPremiumUser)
                Chip(
                  label: const Text('FonctionnalitÃ© Premium'),
                  avatar: const Icon(Icons.workspace_premium, size: 18),
                  backgroundColor: Colors.amber.shade100,
                ),
              const SizedBox(height: 8),
              Text(
                plan.description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ] else
              Text(
                "Aucun jeÃ»ne n'est prÃ©vu pour ce jour.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 20),
            if (!_isFastingActive && !isPastDay && !isFutureDay)
              ElevatedButton.icon(
                // ================== DÃ‰BUT DE LA MODIFICATION ==================
                onPressed: () async {
                  // Rendre la fonction async
                  // Si un jeÃ»ne est dÃ©jÃ  planifiÃ©, on le dÃ©marre directement.
                  if (entryForSelectedDay != null && plan != null) {
                    if (plan.isPremium && !widget.isPremiumUser) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Ce plan de jeÃ»ne est rÃ©servÃ© aux membres Premium.",
                          ),
                          backgroundColor: Colors.amber,
                        ),
                      );
                      return;
                    }
                    _showStartFastDialog(
                      targetDuration: entryForSelectedDay.targetDuration,
                      planId: entryForSelectedDay.planId,
                    );
                  }
                  // SINON (cas qui nous intÃ©resse), on ouvre l'Ã©cran de sÃ©lection.
                  else {
                    final selectedPlan = await Navigator.push<FastingPlan>(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => FastingPlanSelectionScreen(
                              isPremiumUser: widget.isPremiumUser,
                              recommendedGoal:
                                  widget.currentGoals.weightGoalType,
                            ),
                      ),
                    );

                    // Si l'utilisateur a choisi un plan et est revenu, on dÃ©marre le jeÃ»ne.
                    if (selectedPlan != null && mounted) {
                      _showStartFastDialog(
                        targetDuration: selectedPlan.fastingDuration,
                        planId: selectedPlan.id,
                      );
                    }
                  }
                },
                // =================== FIN DE LA MODIFICATION ===================
                icon: Icon(
                  entryForSelectedDay != null
                      ? Icons.play_arrow
                      : Icons.add_alarm,
                ),
                label: Text(
                  entryForSelectedDay != null
                      ? 'DÃ©marrer le JeÃ»ne PlanifiÃ©'
                      : 'DÃ©marrer un JeÃ»ne',
                ),
              )
            else if (_isFastingActive)
              const Text(
                "Un jeÃ»ne est dÃ©jÃ  en cours...",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              )
            else if (isFutureDay)
              Column(
                children: [
                  if (entryForSelectedDay != null) ...[
                    const Icon(
                      Icons.lock_clock,
                      color: Colors.blueGrey,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ce jeÃ»ne est prÃ©vu dans le futur.\nVous pourrez le dÃ©marrer le jour J.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.calendar_month,
                      color: Colors.teal,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Aucun jeÃ»ne planifiÃ© pour ce jour.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: const Text('âš ï¸ Ajouter un jeÃ»ne'),
                                content: Text(
                                  'Vous Ãªtes sur le point d\'ajouter un jeÃ»ne Ã  votre programme le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDay)}.\n\nAssurez-vous d\'Ãªtre en bonne santÃ© et de vous hydrater suffisamment.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Annuler'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Continuer'),
                                  ),
                                ],
                              ),
                        );
                        if (confirmed == true && mounted) {
                          final selectedPlan =
                              await Navigator.push<FastingPlan>(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => FastingPlanSelectionScreen(
                                        isPremiumUser: widget.isPremiumUser,
                                        recommendedGoal:
                                            widget.currentGoals.weightGoalType,
                                      ),
                                ),
                              );
                          if (selectedPlan != null && mounted) {
                            _addFastingToProgram(selectedPlan, _selectedDay);
                          }
                        }
                      },
                      icon: const Icon(Icons.add_alarm),
                      label: const Text('Ajouter un jeÃ»ne Ã  ce jour'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              )
            else if (isPastDay)
              const Text(
                "Cette date est passÃ©e.",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTracker() {
    final Duration totalDuration = _targetDurationForActiveFast;
    final DateTime fastEndTime = _fastStartTime!.add(totalDuration);
    final double progress =
        totalDuration.inSeconds > 0
            ? (_elapsedTime.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
            : 0.0;
    final currentStage = fastingStages.lastWhere(
      (s) => _elapsedTime >= s.startHour,
      orElse: () => fastingStages.first,
    );

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 16,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Temps Ã©coulÃ©',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(_elapsedTime),
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Objectif: ${_formatSessionDuration(totalDuration)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_elapsedTime.inHours >= 24)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Jeûne prolongé (>24h). Écoutez votre corps.",
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: () {
                        _stopFast(saveSession: true, wasCancelled: true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Jeûne rompu. Réalimentez-vous doucement (bouillon d'os, légumes cuits)."),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 6),
                          ),
                        );
                      },
                      icon: const Icon(Icons.favorite),
                      label: const Text("Je ne me sens pas bien (Arrêter)"),
                    ),
                  ],
                ),
              ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DÃ©but: ${DateFormat('HH:mm').format(_fastStartTime!)}'),
                Text('Fin: ${DateFormat('HH:mm').format(fastEndTime)}'),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "Ce qui se passe dans votre corps",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...fastingStages.map((stage) {
              bool isActive = stage == currentStage;
              bool isPassed = _elapsedTime > stage.startHour;
              return Opacity(
                opacity: isActive || isPassed ? 1.0 : 0.5,
                child: ListTile(
                  leading: Icon(
                    stage.icon,
                    color:
                        isActive ? Theme.of(context).primaryColor : Colors.grey,
                    size: 30,
                  ),
                  title: Text(
                    stage.title,
                    style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    isActive ? stage.description : 'Ã‰tape Ã  venir...',
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    List<FastingSession> sortedHistory = List.from(widget.fastingHistory)
      ..sort((a, b) => b.endTime.compareTo(a.endTime));
    if (sortedHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique des JeÃ»nes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount:
              sortedHistory.length > 5
                  ? 5
                  : sortedHistory.length, // Limite aux 5 derniers
          itemBuilder: (context, index) {
            final session = sortedHistory[index];
            final bool targetReached = session.isTargetReached;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(
                  targetReached ? Icons.check_circle : Icons.timer_off_outlined,
                  color: targetReached ? Colors.green : Colors.orange,
                ),
                title: Text(
                  'JeÃ»ne de ${_formatSessionDuration(session.duration)}',
                ),
                subtitle: Text(
                  'TerminÃ© le ${DateFormat('d MMM yyyy Ã  HH:mm', 'fr_FR').format(session.endTime)}',
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => widget.deleteFastingSession(session.id),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // =======================================================================
  // DIALOGUES ET HELPERS
  // =======================================================================

  Future<void> _showStartFastDialog({
    required Duration targetDuration,
    String? planId,
  }) async {
    DateTime selectedStartTime = DateTime.now();
    DateTime calculatedEndTime = selectedStartTime.add(targetDuration);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configurer et DÃ©marrer le JeÃ»ne'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Objectif: ${_formatSessionDuration(targetDuration)}"),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text("Heure de dÃ©but"),
                    subtitle: Text(
                      DateFormat('HH:mm').format(selectedStartTime),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedStartTime),
                      );
                      if (time != null) {
                        setDialogState(() {
                          final now = DateTime.now();
                          selectedStartTime = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            time.hour,
                            time.minute,
                          );
                          calculatedEndTime = selectedStartTime.add(
                            targetDuration,
                          );
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text("Heure de fin (estimÃ©e)"),
                    subtitle: Text(
                      DateFormat('HH:mm').format(calculatedEndTime),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startFast(
                      targetDuration: targetDuration,
                      startTime: selectedStartTime,
                      planId: planId,
                    );
                  },
                  child: const Text('DÃ©marrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStopFastDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Terminer le jeÃ»ne ?'),
            content: const Text(
              'Voulez-vous terminer et enregistrer votre session de jeÃ»ne actuelle ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  _stopFast();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Terminer'),
              ),
            ],
          ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "00:00:00";
    d += const Duration(microseconds: 999999);
    return '${d.inHours.toString().padLeft(2, '0')}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  String _formatSessionDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
    return '${d.inMinutes}min';
  }

  Color _getLevelColor(String level) {
    if (level.contains('DÃ©butant')) return Colors.green.shade600;
    if (level.contains('IntermÃ©diaire')) return Colors.amber.shade700;
    if (level.contains('AvancÃ©')) return Colors.red.shade600;
    if (level.contains('Expert')) return Colors.purple.shade600;
    return Colors.grey;
  }
}

// NEW: FastingPlanSelectionScreen (pas nÃ©cessaire de l'ajouter si vous ne l'appelez pas, mais c'est une bonne pratique)
class FastingPlanSelectionScreen extends StatefulWidget {
  final bool isPremiumUser;
  final String recommendedGoal;

  const FastingPlanSelectionScreen({
    super.key,
    required this.isPremiumUser,
    required this.recommendedGoal,
  });

  @override
  State<FastingPlanSelectionScreen> createState() =>
      _FastingPlanSelectionScreenState();
}

class _FastingPlanSelectionScreenState
    extends State<FastingPlanSelectionScreen> {
  FastingPlan? _selectedPlan;

  Color _getLevelColor(String level) {
    if (level.contains('DÃ©butant')) return Colors.green.shade600;
    if (level.contains('IntermÃ©diaire')) return Colors.amber.shade700;
    if (level.contains('AvancÃ©')) return Colors.red.shade600;
    if (level.contains('Expert')) return Colors.purple.shade600;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    // SÃ©pare les plans recommandÃ©s des autres pour une meilleure UX
    final recommendedPlans =
        predefinedFastingPlans
            .where((p) => p.goals.contains(widget.recommendedGoal))
            .toList();
    final otherPlans =
        predefinedFastingPlans
            .where((p) => !p.goals.contains(widget.recommendedGoal))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Choisir un Plan de JeÃ»ne')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (recommendedPlans.isNotEmpty) ...[
            Text(
              'RecommandÃ© pour vous',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            ...recommendedPlans.map((plan) => _buildProgramCard(plan)),
            const Divider(height: 32),
          ],
          Text(
            'Autres plans disponibles',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          ...otherPlans.map((plan) => _buildProgramCard(plan)),
          const SizedBox(height: 80), // Espace pour le bouton flottant
        ],
      ),
      floatingActionButton:
          _selectedPlan != null
              ? FloatingActionButton.extended(
                onPressed: () => Navigator.pop(context, _selectedPlan),
                label: Text('DÃ©marrer : ${_selectedPlan!.name}'),
                icon: const Icon(Icons.play_arrow),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildProgramCard(FastingPlan plan) {
    final bool isSelected = _selectedPlan?.id == plan.id;
    final bool isLocked = plan.isPremium && !widget.isPremiumUser;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: isSelected ? 4 : 2,
      color:
          isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isSelected
                ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Icon(Icons.timer_outlined, color: _getLevelColor(plan.level)),
        title: Text(
          plan.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isLocked ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.level,
              style: TextStyle(
                color: _getLevelColor(plan.level),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              plan.description,
              style: TextStyle(
                color: isLocked ? Colors.grey.shade600 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              plan.exampleSchedule,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing:
            isLocked
                ? const Icon(Icons.lock, color: Colors.amber)
                : (isSelected
                    ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 28,
                    )
                    : null),
        onTap:
            isLocked
                ? () {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Ce programme est rÃ©servÃ© aux utilisateurs Premium.",
                      ),
                      backgroundColor: Colors.amber,
                    ),
                  );
                }
                : () {
                  setState(() => _selectedPlan = plan);
                },
      ),
    );
  }
}

class ScanHistoryTab extends StatefulWidget {
  final List<ScannedProduct> scannedProducts;
  final Function(String) deleteScannedProduct;
  final Function(String barcode) onRescanProduct;

  const ScanHistoryTab({
    super.key,
    required this.scannedProducts,
    required this.deleteScannedProduct,
    required this.onRescanProduct,
  });

  @override
  State<ScanHistoryTab> createState() => _ScanHistoryTabState();
}

class _ScanHistoryTabState extends State<ScanHistoryTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Scans'),
        automaticallyImplyLeading: false,
      ),
      body:
          widget.scannedProducts.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "Aucun produit scannÃ© pour le moment. Scannez un produit pour voir son historique ici !",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: widget.scannedProducts.length,
                itemBuilder: (context, index) {
                  final product = widget.scannedProducts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading:
                          product.imageUrl != null
                              ? Image.network(
                                product.imageUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (c, e, s) =>
                                        const Icon(Icons.fastfood, size: 40),
                              )
                              : const Icon(
                                Icons.qr_code_scanner,
                                size: 40,
                                color: Colors.grey,
                              ),
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'ScannÃ© le ${DateFormat('d/M/y HH:mm', 'fr_FR').format(product.scannedDate)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (product.nutriScore != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Image.network(
                                'https://static.openfoodfacts.org/images/attributes/nutriscore-${product.nutriScore!.toLowerCase()}.png',
                                height: 30,
                                errorBuilder:
                                    (c, e, s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        product.nutriScore!.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.blue),
                            tooltip: 'Rescanner le produit',
                            onPressed:
                                () => widget.onRescanProduct(product.barcode),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Supprimer de l\'historique',
                            onPressed: () => _confirmDeleteProduct(product),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProductDetailPage(
                                  barcode: product.barcode,
                                  onProductScanned: (p) => {},
                                  onAddFoodEntry: (e) => {},
                                  isPremiumUser:
                                      true, // Assurez-vous d'avoir le vrai statut premium ici
                                  usageTrackerService: UsageTrackerService(
                                    userId:
                                        FirebaseAuth.instance.currentUser!.uid,
                                  ),
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }

  void _confirmDeleteProduct(ScannedProduct product) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer ce scan ?'),
            content: Text(
              'Voulez-vous vraiment supprimer "${product.name}" de l\'historique des scans ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.deleteScannedProduct(product.id);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }
}
// main.dart (Remplacez l'ancienne classe UserProfileScreen par celle-ci)

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final FirestoreService firestoreService;
  final VoidCallback onProfileUpdated;
  final UserProfile initialProfile;
  final DailyGoal initialGoals;
  final List<WeightEntry> allWeightEntries;
  final bool isPremiumUser;
  final UsageTrackerService usageTrackerService;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.firestoreService,
    required this.onProfileUpdated,
    required this.initialProfile,
    required this.initialGoals,
    required this.allWeightEntries,
    required this.isPremiumUser,
    required this.usageTrackerService,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late UserProfile _editableProfile;
  late DailyGoal _editableGoals;
  bool _isLoading = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _bodyFatController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _targetCaloriesController =
      TextEditingController();
  final TextEditingController _targetProteinsController =
      TextEditingController();
  final TextEditingController _targetCarbsController = TextEditingController();
  final TextEditingController _targetFatsController = TextEditingController();
  final TextEditingController _targetWaterController = TextEditingController();
  final TextEditingController _targetMuscleGainController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _editableProfile = widget.initialProfile.copyWith();
    _editableGoals = widget.initialGoals.copyWith();

    _firstNameController.text = _editableProfile.firstName ?? '';
    _lastNameController.text = _editableProfile.lastName ?? '';
    _ageController.text = _editableProfile.age.toString();
    _weightController.text = _editableProfile.weight.toStringAsFixed(1);
    _bodyFatController.text = _editableProfile.bodyFatPercentage?.toStringAsFixed(1) ?? '';
    _heightController.text = _editableProfile.height.toStringAsFixed(1);
    _targetWeightController.text = _editableGoals.targetWeight.toStringAsFixed(
      1,
    );

    // Si l'utilisateur est en sous-poids, on force l'objectif Ã  'maintenir' ou 'prendre du poids' pour Ã©viter les erreurs
    if (_editableProfile.isUnderweight &&
        _editableGoals.weightGoalType == 'lose') {
      _editableGoals.weightGoalType = 'maintain';
    }

    _updateGoalsFromProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    _heightController.dispose();
    _targetMuscleGainController.dispose();
    _targetWeightController.dispose();
    _targetCaloriesController.dispose();
    _targetProteinsController.dispose();
    _targetCarbsController.dispose();
    _targetFatsController.dispose();
    _targetWaterController.dispose();
    super.dispose();
  }

  void _updateGoalsFromProfile() {
    if (!mounted) return;

    final weight =
        double.tryParse(_weightController.text) ?? _editableProfile.weight;
    final bodyFatPercentage =
        double.tryParse(_bodyFatController.text) ?? _editableProfile.bodyFatPercentage;
    final height =
        double.tryParse(_heightController.text) ?? _editableProfile.height;
    final age = int.tryParse(_ageController.text) ?? _editableProfile.age;

    _editableProfile = _editableProfile.copyWith(
      weight: weight,
      height: height,
      age: age,
    );

    double bmr =
        (_editableProfile.gender == 'male')
            ? (10 * weight) + (6.25 * height) - (5 * age) + 5
            : (10 * weight) + (6.25 * height) - (5 * age) - 161;

    double activityMultiplier;
    switch (_editableProfile.activityLevel) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'light':
        activityMultiplier = 1.375;
        break;
      case 'moderate':
        activityMultiplier = 1.55;
        break;
      case 'active':
        activityMultiplier = 1.725;
        break;
      case 'very_active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.55;
    }
    final tdee = bmr * activityMultiplier;

    double targetCalories;
    switch (_editableGoals.weightGoalType) {
      case 'gain':
        targetCalories = tdee + 300;
        break;
      case 'lose':
        targetCalories = tdee - 500;
        break;
      default:
        targetCalories = tdee;
    }

    final double targetProteins =
        weight * (_editableGoals.weightGoalType == 'gain' ? 2.0 : 1.8);
    final double targetFats = weight * 0.9;
    final double proteinCalories = targetProteins * 4;
    final double fatCalories = targetFats * 9;
    final double targetCarbs =
        (targetCalories - proteinCalories - fatCalories) / 4;

    setState(() {
      _editableGoals = _editableGoals.copyWith(
        targetCalories: targetCalories.round(),
        targetProteins: targetProteins.clamp(0, double.infinity),
        targetFats: targetFats.clamp(0, double.infinity),
        targetCarbs: targetCarbs.clamp(0, double.infinity),
        weeklyEnergyExpenditureGoal: tdee,
      );

      _targetCaloriesController.text = _editableGoals.targetCalories.toString();
      _targetProteinsController.text = _editableGoals.targetProteins
          .toStringAsFixed(0);
      _targetCarbsController.text = _editableGoals.targetCarbs.toStringAsFixed(
        0,
      );
      _targetFatsController.text = _editableGoals.targetFats.toStringAsFixed(0);
      _targetWaterController.text = _editableGoals.targetWater.toStringAsFixed(
        1,
      );
    });
  }

  Future<void> _saveProfileAndGoals() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final updatedHistory = List<GoalHistoryEntry>.from(
        _editableProfile.goalHistory,
      );
      final currentInProgressGoal = updatedHistory.firstWhereOrNull(
        (g) => g.status == GoalStatus.inProgress,
      );

      final newGoalType = _editableGoals.weightGoalType;
      final newTargetWeight =
          double.tryParse(_targetWeightController.text) ??
          _editableGoals.targetWeight;

      bool goalHasChanged =
          currentInProgressGoal == null ||
          currentInProgressGoal.goalType != newGoalType ||
          currentInProgressGoal.targetWeight != newTargetWeight;

      if (goalHasChanged) {
        if (currentInProgressGoal != null) {
          final index = updatedHistory.indexWhere(
            (g) => g.id == currentInProgressGoal.id,
          );
          updatedHistory[index] = GoalHistoryEntry(
            id: currentInProgressGoal.id,
            goalType: currentInProgressGoal.goalType,
            startWeight: currentInProgressGoal.startWeight,
            targetWeight: currentInProgressGoal.targetWeight,
            startDate: currentInProgressGoal.startDate,
            endDate: DateTime.now(),
            status:
                GoalStatus
                    .failed, // L'ancien objectif est marquÃ© comme Ã©chouÃ© car modifiÃ©
          );
        }

        final newGoal = GoalHistoryEntry(
          goalType: newGoalType,
          startWeight: _editableProfile.weight,
          targetWeight: newTargetWeight,
          startDate: DateTime.now(),
          status: GoalStatus.inProgress,
        );
        updatedHistory.add(newGoal);
      }

      _editableProfile = _editableProfile.copyWith(goalHistory: updatedHistory);

      await widget.firestoreService.updateUserProfile(_editableProfile);
      _editableGoals = _editableGoals.copyWith(targetWeight: newTargetWeight);
      await widget.firestoreService.updateDailyGoals(_editableGoals);

      widget.onProfileUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sauvegarde: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logique de validation pour les objectifs de poids
    final double minNormalWeight = _editableProfile.minNormalWeight;
    final double maxNormalWeight = _editableProfile.maxNormalWeight;

    // NOUVEAU: On construit dynamiquement la liste des objectifs possibles
    List<DropdownMenuItem<String>> goalTypeItems = [
      const DropdownMenuItem(
        value: 'gain',
        child: Text('Prendre du poids/muscle'),
      ),
      const DropdownMenuItem(
        value: 'maintain',
        child: Text('Maintenir mon poids'),
      ),
    ];
    // On ajoute l'option "perdre du poids" uniquement si l'utilisateur n'est pas en sous-poids
    if (!_editableProfile.isUnderweight) {
      goalTypeItems.add(
        const DropdownMenuItem(value: 'lose', child: Text('Perdre du poids')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mon Profil et Objectifs')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildProfileInputCard(
                      title: 'Informations Personnelles',
                      children: [
                        _GoalTextField(
                          label: 'PrÃ©nom',
                          controller: _firstNameController,
                          onSaved:
                              (v) =>
                                  _editableProfile = _editableProfile.copyWith(
                                    firstName: v,
                                  ),
                        ),
                        _GoalTextField(
                          label: 'Nom',
                          controller: _lastNameController,
                          onSaved:
                              (v) =>
                                  _editableProfile = _editableProfile.copyWith(
                                    lastName: v,
                                  ),
                        ),
                        _GoalTextField(
                          label: 'Ã‚ge',
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateGoalsFromProfile(),
                        ),
                                _GoalTextField(
                          label: 'Poids (kg)',
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateGoalsFromProfile(),
                        ),
                        _GoalTextField(
                          label: 'Pourcentage de masse grasse (% - optionnel)',
                          controller: _bodyFatController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateGoalsFromProfile(),
                        ),
                        if (_editableProfile.leanBodyMass != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Masse maigre estimée : ${_editableProfile.leanBodyMass!.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        _GoalTextField(
                          label: 'Taille (cm)',
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateGoalsFromProfile(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // NOUVELLE CARTE POUR LES HABITUDES DE VIE
                    _buildProfileInputCard(
                      title: 'Habitudes Alimentaires',
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _editableProfile.mealsPerDay,
                          decoration: const InputDecoration(
                            labelText: 'Combien de repas par jour ?',
                          ),
                          items:
                              [1, 2, 3, 4, 5, 6]
                                  .map(
                                    (n) => DropdownMenuItem(
                                      value: n,
                                      child: Text('$n repas'),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            setState(
                              () =>
                                  _editableProfile = _editableProfile.copyWith(
                                    mealsPerDay: v,
                                  ),
                            );
                            _updateGoalsFromProfile();
                          },
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _editableProfile.dietQuality,
                          decoration: const InputDecoration(
                            labelText: 'QualitÃ© globale de votre alimentation',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'saine',
                              child: Text('PlutÃ´t saine et Ã©quilibrÃ©e'),
                            ),
                            DropdownMenuItem(
                              value: 'moyenne',
                              child: Text('Variable, avec des excÃ¨s'),
                            ),
                            DropdownMenuItem(
                              value: 'peu_saine',
                              child: Text(
                                'Souvent peu Ã©quilibrÃ©e (transformÃ©s, etc.)',
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(
                              () =>
                                  _editableProfile = _editableProfile.copyWith(
                                    dietQuality: v,
                                  ),
                            );
                            _updateGoalsFromProfile();
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Je m\'entraÃ®ne en salle de sport'),
                          value: _editableProfile.gymMode,
                          onChanged:
                              (v) => setState(
                                () =>
                                    _editableProfile = _editableProfile
                                        .copyWith(gymMode: v),
                              ),
                        ),
                        if (!_editableProfile.gymMode)
                          _buildMultiSelectChip(
                            label: 'Mon matÃ©riel Ã  la maison',
                            options: [
                              'HaltÃ¨res',
                              'Bande de rÃ©sistance',
                              'Barre de traction',
                              'Kettlebell',
                              'Tapis de sol',
                              'Banc',
                            ],
                            selected: _editableProfile.availableEquipment,
                            onSelectionChanged:
                                (selected) => setState(
                                  () =>
                                      _editableProfile = _editableProfile
                                          .copyWith(
                                            availableEquipment: selected,
                                          ),
                                ),
                          ),
                        SwitchListTile(
                          title: const Text('Tendance Ã  manger trop sucrÃ© ?'),
                          value: _editableProfile.tendsToEatSugary,
                          onChanged:
                              (v) => setState(
                                () =>
                                    _editableProfile = _editableProfile
                                        .copyWith(tendsToEatSugary: v),
                              ),
                        ),
                        SwitchListTile(
                          title: const Text('Tendance Ã  manger trop salÃ© ?'),
                          value: _editableProfile.tendsToEatSalty,
                          onChanged:
                              (v) => setState(
                                () =>
                                    _editableProfile = _editableProfile
                                        .copyWith(tendsToEatSalty: v),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Vos objectifs de santÃ©',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildGoalCard(
                      context: context,
                      title: 'Objectif Principal',
                      icon: Icons.flag,
                      content: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _editableGoals.weightGoalType,
                            decoration: InputDecoration(
                              labelText: 'Type d\'objectif',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                            ),
                            // CORRECTION: Utilisation de la liste dynamique
                            items: goalTypeItems,
                            onChanged: (value) {
                              // Si la valeur est nulle (ce qui peut arriver si l'option est retirÃ©e), on ne fait rien
                              if (value == null) return;
                              setState(
                                () => _editableGoals.weightGoalType = value,
                              );
                              _updateGoalsFromProfile();
                            },
                          ),
                          const SizedBox(height: 12),
                          _GoalTextField(
                            label: 'Poids Cible (kg)',
                            controller: _targetWeightController,
                            keyboardType: TextInputType.number,
                            // CORRECTION: Ajout d'un validateur intelligent
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Champ requis.';
                              }
                              final targetWeight = double.tryParse(value);
                              if (targetWeight == null) {
                                return 'Valeur invalide.';
                              }

                              // Suggestion si la cible est trop ambitieuse ou potentiellement dangereuse
                              if (_editableGoals.weightGoalType == 'lose' &&
                                  targetWeight < minNormalWeight) {
                                return 'Attention, cet objectif vous mettrait en sous-poids. Visez plutÃ´t ${minNormalWeight.toStringAsFixed(1)} kg.';
                              }
                              if (_editableGoals.weightGoalType == 'gain' &&
                                  targetWeight > maxNormalWeight * 1.2) {
                                // 20% au dessus du poids max normal
                                return 'Cet objectif est trÃ¨s ambitieux. Progressez par paliers.';
                              }
                              return null;
                            },
                            onSaved: (v) {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // NOUVEAU: AFFICHAGE DE L'HISTORIQUE
                    Text(
                      'Historique des Objectifs',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _editableProfile.goalHistory.isEmpty
                        ? const Card(
                          child: ListTile(
                            title: Text(
                              "Aucun objectif dÃ©fini pour le moment.",
                            ),
                          ),
                        )
                        : Column(
                          children:
                              _editableProfile.goalHistory.reversed.map((goal) {
                                IconData statusIcon;
                                Color statusColor;
                                String statusText;
                                switch (goal.status) {
                                  case GoalStatus.achieved:
                                    statusIcon = Icons.check_circle;
                                    statusColor = Colors.green;
                                    statusText = 'Atteint';
                                    break;
                                  case GoalStatus.failed:
                                    statusIcon = Icons.cancel;
                                    statusColor = Colors.red;
                                    statusText = 'Non atteint';
                                    break;
                                  case GoalStatus.inProgress:
                                    statusIcon = Icons.run_circle;
                                    statusColor = Colors.blue;
                                    statusText = 'En cours';
                                    break;
                                }
                                final duration =
                                    goal.endDate
                                        ?.difference(goal.startDate)
                                        .inDays;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      statusIcon,
                                      color: statusColor,
                                    ),
                                    title: Text(
                                      '${goal.goalType.capitalize()} de ${goal.startWeight}kg Ã  ${goal.targetWeight}kg',
                                    ),
                                    subtitle: Text(
                                      'Du ${DateFormat('dd/MM/yy').format(goal.startDate)} au ${goal.endDate != null ? DateFormat('dd/MM/yy').format(goal.endDate!) : '...'}',
                                    ),
                                    trailing: Text(
                                      '$statusText ${duration != null ? "en $duration j" : ""}',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _saveProfileAndGoals,
                        icon: const Icon(Icons.save),
                        label: const Text('Sauvegarder les modifications'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  // Fonctions d'aide Ã  la construction de l'UI (pas de changement ici)
  Widget _buildProfileInputCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            Column(
              children:
                  children
                      .map(
                        (child) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: child,
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectChip({
    required String label,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Wrap(
          spacing: 8.0,
          children:
              options.map((option) {
                final isSelected = selected.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (bool value) {
                    List<String> newSelected = List.from(selected);
                    if (value) {
                      newSelected.add(option);
                    } else {
                      newSelected.remove(option);
                    }
                    onSelectionChanged(newSelected);
                  },
                  backgroundColor:
                      isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.2)
                          : Colors.grey.shade200,
                  selectedColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.8),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                  checkmarkColor: Colors.white,
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildGoalCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 24),
            content,
          ],
        ),
      ),
    );
  }
}

class GoalsTab extends StatefulWidget {
  final DailyGoal currentGoals;
  final Function(DailyGoal) updateGoals;
  final List<WeightEntry> allWeightEntries;
  final bool isPremiumUser;
  final UsageTrackerService usageTrackerService;

  const GoalsTab({
    super.key,
    required this.currentGoals,
    required this.updateGoals,
    required this.allWeightEntries,
    required this.isPremiumUser,
    required this.usageTrackerService,
  });

  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  final _formKey = GlobalKey<FormState>();
  late DailyGoal _editableGoals;
  double _currentWeight = 0.0;

  final TextEditingController _currentWeightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editableGoals = widget.currentGoals.copyWith();
    _currentWeight =
        widget.allWeightEntries.isNotEmpty
            ? widget.allWeightEntries.last.weight
            : _editableGoals.targetWeight;
    _currentWeightController.text = _currentWeight.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _currentWeightController.dispose();
    super.dispose();
  }

  Future<void> _deduceWeightGoalWithIA() async {
    if (!widget.isPremiumUser) {
      final dailyCalls =
          await widget.usageTrackerService.getDeepSeekApiCallCount();
      if (dailyCalls >= widget.usageTrackerService.deepSeekLimit) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Vous avez atteint la limite de 5 appels DeepSeek par jour (version Free). Passez au Premium pour un usage illimitÃ© !",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => const AlertDialog(
            title: Text('Analyse IA en cours...'),
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    "L'IA analyse vos donnÃ©es pour dÃ©duire le meilleur objectif.",
                  ),
                ),
              ],
            ),
          ),
    );

    final String prompt = '''
    Tu es un expert en nutrition et sport. Un utilisateur veut fixer un objectif.
    Voici ses donnÃ©es :
    - Poids actuel : $_currentWeight kg
    - IMC (estimÃ©, selon le poids et taille standard moyenne) ou informations fournies: veut une recommandation d'objectif.
    
    DÃ©termine le meilleur objectif nutritionnel.
    Aussi, calcule des macros cibles (protÃ©ines, glucides, lipides) adaptÃ©es.
    
    Renvoie le rÃ©sultat en JSON STRICT avec:
    - "goal": "lose", "gain" ou "maintain"
    - "target_weight": (double) un poids cible rÃ©aliste et sain
    - "target_calories": (int)
    - "target_proteins": (double)
    - "target_carbs": (double)
    - "target_fats": (double)
    - "message": (string) un court message explicatif
    ''';

    try {
      final result = await SL.aiService.fetchJSONResponse(
        prompt: prompt,
        temperature: 0.5,
      );

      if (mounted) Navigator.pop(context);

      if (result != null) {
        await widget.usageTrackerService.incrementDeepSeekApiCall();

        setState(() {
          _editableGoals.weightGoalType = result['goal'] ?? 'maintain';
          _editableGoals.targetWeight =
              (result['target_weight'] as num?)?.toDouble() ?? _currentWeight;
          _editableGoals.targetCalories = result['target_calories'] ?? 2000;
          _editableGoals.targetProteins =
              (result['target_proteins'] as num?)?.toDouble() ?? 100.0;
          _editableGoals.targetCarbs =
              (result['target_carbs'] as num?)?.toDouble() ?? 200.0;
          _editableGoals.targetFats =
              (result['target_fats'] as num?)?.toDouble() ?? 70.0;
          _currentWeightController.text = _editableGoals.targetWeight
              .toStringAsFixed(1);
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("IA: ${result['message']}"),
            backgroundColor: Colors.blue.shade700,
            duration: const Duration(seconds: 7),
          ),
        );
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur de l'API IA."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Objectifs'),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'DÃ©finissez vos objectifs',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildGoalCard(
              context: context,
              title: 'Objectif de Poids / Muscle',
              icon: Icons.monitor_weight,
              content: Column(
                children: [
                  _GoalTextField(
                    label: 'Poids Actuel (kg)',
                    initialValue: _currentWeight.toStringAsFixed(1),
                    readOnly: true,
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 12),
                  _GoalTextField(
                    label: 'Poids Cible (kg)',
                    initialValue: _editableGoals.targetWeight.toStringAsFixed(
                      1,
                    ),
                    onChanged:
                        (value) =>
                            _editableGoals.targetWeight =
                                double.tryParse(value) ??
                                _editableGoals.targetWeight,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _editableGoals.weightGoalType,
                    decoration: InputDecoration(
                      labelText: 'Type d\'objectif',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'lose',
                        child: Text('Perdre du poids'),
                      ),
                      DropdownMenuItem(
                        value: 'gain',
                        child: Text('Prendre du muscle'),
                      ),
                      DropdownMenuItem(
                        value: 'maintain',
                        child: Text('Maintenir mon poids'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _editableGoals.weightGoalType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _deduceWeightGoalWithIA,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: Text(
                      widget.isPremiumUser
                          ? 'DÃ©duire l\'objectif avec l\'IA'
                          : 'DÃ©duire l\'objectif avec l\'IA (5/jour)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildGoalCard(
              context: context,
              title: 'Objectifs Nutritionnels Journaliers',
              icon: Icons.track_changes,
              content: Column(
                children: [
                  _GoalTextField(
                    label: 'Calories (kcal)',
                    initialValue: _editableGoals.targetCalories.toString(),
                    onChanged:
                        (value) =>
                            _editableGoals.targetCalories =
                                int.tryParse(value) ??
                                _editableGoals.targetCalories,
                  ),
                  const SizedBox(height: 12),
                  _GoalTextField(
                    label: 'ProtÃ©ines (g)',
                    initialValue: _editableGoals.targetProteins.toStringAsFixed(
                      0,
                    ),
                    onChanged:
                        (value) =>
                            _editableGoals.targetProteins =
                                double.tryParse(value) ??
                                _editableGoals.targetProteins,
                  ),
                  const SizedBox(height: 12),
                  _GoalTextField(
                    label: 'Glucides (g)',
                    initialValue: _editableGoals.targetCarbs.toStringAsFixed(0),
                    onChanged:
                        (value) =>
                            _editableGoals.targetCarbs =
                                double.tryParse(value) ??
                                _editableGoals.targetCarbs,
                  ),
                  const SizedBox(height: 12),
                  _GoalTextField(
                    label: 'Lipides (g)',
                    initialValue: _editableGoals.targetFats.toStringAsFixed(0),
                    onChanged:
                        (value) =>
                            _editableGoals.targetFats =
                                double.tryParse(value) ??
                                _editableGoals.targetFats,
                  ),
                  const SizedBox(height: 12),
                  _GoalTextField(
                    label: 'Eau (Litres)',
                    initialValue: _editableGoals.targetWater.toStringAsFixed(1),
                    onChanged:
                        (value) =>
                            _editableGoals.targetWater =
                                double.tryParse(value) ??
                                _editableGoals.targetWater,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.updateGoals(_editableGoals);
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Sauvegarder les objectifs'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 24),
            content,
          ],
        ),
      ),
    );
  }
}

class SubscriptionPage extends StatefulWidget {
  final bool isPremiumUser;
  final SubscriptionService subscriptionService;
  final UsageTrackerService usageTrackerService;

  const SubscriptionPage({
    super.key,
    required this.isPremiumUser,
    required this.subscriptionService,
    required this.usageTrackerService,
  });

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  int _apiCallsUsed = 0;
  int _photoCallsUsed = 0;
  int _scanCallsUsed = 0;

  @override
  void initState() {
    super.initState();
    _loadUsages();
  }

  Future<void> _loadUsages() async {
    final api = await widget.usageTrackerService.getDeepSeekApiCallCount();
    final photo = await widget.usageTrackerService.getPhotoAnalysisCount();
    final scan = await widget.usageTrackerService.getScanAnalysisCount();
    if (mounted) {
      setState(() {
        _apiCallsUsed = api;
        _photoCallsUsed = photo;
        _scanCallsUsed = scan;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitIA = widget.usageTrackerService.deepSeekLimit;
    final streak = widget.usageTrackerService.currentStreak;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Abonnement'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              color:
                  widget.isPremiumUser
                      ? Colors.amber.shade50
                      : Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.isPremiumUser
                              ? Icons.workspace_premium
                              : Icons.person_outline,
                          color:
                              widget.isPremiumUser
                                  ? Colors.amber.shade800
                                  : Colors.blueGrey.shade700,
                          size: 36,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          widget.isPremiumUser
                              ? 'Premium Actif'
                              : 'Version Gratuite',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                widget.isPremiumUser
                                    ? Colors.amber.shade800
                                    : Colors.blueGrey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      widget.isPremiumUser
                          ? 'FÃ©licitations ! Vous bÃ©nÃ©ficiez de toutes les fonctionnalitÃ©s illimitÃ©es.'
                          : 'Vous utilisez la version gratuite.\nBonus de sÃ©rie en cours : $streak jours (+${limitIA - 5} appels IA) !',
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            widget.isPremiumUser
                                ? Colors.amber.shade700
                                : Colors.blueGrey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!widget.isPremiumUser)
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPremiumUpgradeDialog(context),
                          icon: const Icon(Icons.star),
                          label: const Text('Passer au Premium !'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    if (widget.isPremiumUser)
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _showPremiumDowngradeDialog(context),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Annuler l\'abonnement'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Vos CrÃ©dits & Limites (Aujourd\'hui)',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              context,
              'Appels IA (Recettes, Bilan, Menus)',
              widget.isPremiumUser
                  ? 'IllimitÃ©'
                  : 'UtilisÃ©s : $_apiCallsUsed / $limitIA',
              widget.isPremiumUser,
            ),
            _buildFeatureCard(
              context,
              'Analyse IA Photo',
              widget.isPremiumUser
                  ? 'IllimitÃ©'
                  : 'UtilisÃ©s : $_photoCallsUsed / ${UserLimits.freePhotoAnalysisPerDay}',
              widget.isPremiumUser,
            ),
            _buildFeatureCard(
              context,
              'Scan IA des produits',
              widget.isPremiumUser
                  ? 'IllimitÃ©'
                  : 'UtilisÃ©s : $_scanCallsUsed / ${UserLimits.freeScanAnalysisPerDay}',
              widget.isPremiumUser,
            ),
            const SizedBox(height: 32),
            Text(
              'FonctionnalitÃ©s de l\'abonnement',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              context,
              'Analyses photo IA illimitÃ©es',
              'Free: 1 analyse / jour\nPremium: IllimitÃ©',
              widget.isPremiumUser,
            ),
            _buildFeatureCard(
              context,
              'Scans IA de produits illimitÃ©s et plus rapides',
              'Free: 5 scans IA / jour\nPremium: IllimitÃ© & ParallÃ¨le',
              widget.isPremiumUser,
            ),
            _buildFeatureCard(
              context,
              'Appels API ModÃ¨le IA illimitÃ©s',
              'Free: 5 appels / jour + bonus sÃ©rie\nPremium: IllimitÃ©',
              widget.isPremiumUser,
            ),
            _buildFeatureCard(
              context,
              'Historique Ã©tendu des donnÃ©es',
              'Free: DonnÃ©es des 30 derniers jours\nPremium: Historique complet',
              widget.isPremiumUser,
            ),
            _buildFeatureCard(
              context,
              'Conseils IA personnalisÃ©s et proactifs',
              'Free: Suggestions basiques\nPremium: Conseils approfondis (recettes, ajustements de plan)',
              widget.isPremiumUser,
            ),
            _buildFeatureCard(
              context,
              'Planification de repas avancÃ©e et gÃ©nÃ©ration de menus hebdomadaires',
              'Free: Menus du jour basiques\nPremium: Menus rÃ©currents, listes de courses gÃ©nÃ©rÃ©es par l\'IA',
              widget.isPremiumUser,
            ),
            _buildFeatureCard(
              context,
              'Programmes d\'entrainements et jeÃ»ne avancÃ©s',
              'Free: Outils manuels simples\nPremium: Programmes IA (expert), jeÃ»nes longs (>20h)',
              widget.isPremiumUser,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    bool isPremium,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isPremium ? Icons.all_inclusive : Icons.av_timer,
              color: isPremium ? Colors.green.shade600 : Colors.blue.shade600,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Passer au Premium ?'),
            content: const Text(
              'Voulez-vous simuler l\'activation de l\'abonnement Premium ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await widget.subscriptionService.setPremiumStatus(true);
                  Navigator.pop(ctx);
                },
                child: const Text('Activer'),
              ),
            ],
          ),
    );
  }

  void _showPremiumDowngradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Annuler l\'abonnement ?'),
            content: const Text('Voulez-vous simuler l\'annulation ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Non'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await widget.subscriptionService.setPremiumStatus(false);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Oui, Annuler'),
              ),
            ],
          ),
    );
  }
}

class _MacroProgressIndicator extends StatelessWidget {
  final String label;
  final double currentValue;
  final double goalValue;
  final Color color;

  const _MacroProgressIndicator({
    required this.label,
    required this.currentValue,
    required this.goalValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage =
        (goalValue > 0) ? (currentValue / goalValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '${currentValue.toStringAsFixed(0)} / ${goalValue.toStringAsFixed(0)} g',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage,
          minHeight: 8,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(
            percentage > 1.0 ? Colors.red.shade600 : color,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final String score;
  final String label;
  final Color color;

  const _ImpactStat({
    required this.score,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          score,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.8))),
      ],
    );
  }
}

class _GoalTextField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldSetter<String>? onSaved;
  final bool readOnly;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  const _GoalTextField({
    required this.label,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.onSaved,
    this.readOnly = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        initialValue: controller == null ? initialValue : null,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          // Correction Mode Sombre : gris foncÃ© en dark mode, gris trÃ¨s clair en light mode
          fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        ),
        keyboardType: keyboardType,
        onChanged: onChanged,
        onSaved: onSaved,
        readOnly: readOnly,
        maxLines: 1,
        validator:
            validator ??
            (value) {
              if (!readOnly && (value == null || value.isEmpty)) {
                return 'Ce champ ne peut pas Ãªtre vide.';
              }
              if (keyboardType == TextInputType.number &&
                  (value != null && value.isNotEmpty) &&
                  double.tryParse(value) == null) {
                return 'Veuillez entrer un nombre valide.';
              }
              return null;
            },
      ),
    );
  }
}

class GlobalImpactCard extends StatelessWidget {
  final double scoreValue;
  final String? scoreGrade;
  final String justification;

  const GlobalImpactCard({
    super.key,
    required this.scoreValue,
    this.scoreGrade,
    required this.justification,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Impact Environnemental Global (IA)",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Tooltip(
              message:
                  "Cette note Ã©value l'impact global du produit par rapport Ã  une alimentation durable.",
              child: Icon(
                Icons.info_outline,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Eco-score Global: ${scoreGrade ?? 'N/A'}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      ScoreCircle(
                        score: scoreValue,
                        title: '',
                        isEnvironmental: true,
                      ).getScoreColor(),
                ),
              ),
              Text(
                "${scoreValue.toStringAsFixed(0)}/100",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      ScoreCircle(
                        score: scoreValue,
                        title: '',
                        isEnvironmental: true,
                      ).getScoreColor(),
                ),
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Comment ce score est-il calculÃ© ?",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  justification,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LifecycleBreakdownCard extends StatelessWidget {
  final Map<String, double> breakdownData;
  const LifecycleBreakdownCard({super.key, required this.breakdownData});

  @override
  Widget build(BuildContext context) {
    final sortedEntries =
        breakdownData.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Analyse du Cycle de Vie (Officiel)",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Tooltip(
              message:
                  "RÃ©partition de l'impact environnemental selon les donnÃ©es Agribalyse.",
              child: Icon(Icons.info_outline, size: 20, color: Colors.blue),
            ),
          ],
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text("Cliquez pour voir le dÃ©tail de l'impact"),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              children:
                  sortedEntries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${entry.value.toStringAsFixed(1)} %',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: entry.value / 100,
                            backgroundColor: Colors.grey.shade300,
                            color: Colors.teal,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductStatusCard extends StatelessWidget {
  final String status;
  const ProductStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String text;

    switch (status.toLowerCase()) {
      case 'vegan':
        icon = Icons.eco;
        color = Colors.green.shade700;
        text = "Produit VÃ©gÃ©talien (Vegan)";
        break;
      case 'vegetarian':
        icon = Icons.grass;
        color = Colors.lightGreen.shade800;
        text = "Produit VÃ©gÃ©tarien";
        break;
      case 'non-vegetarian':
        icon = Icons.kebab_dining;
        color = Colors.red.shade700;
        text = "Contient des produits d'origine animale";
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey.shade700;
        text = "Statut vÃ©gÃ©tarien inconnu";
    }

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalysisCard extends StatelessWidget {
  final String title;
  final String content;
  final String? verdict;

  const AnalysisCard({
    super.key,
    required this.title,
    required this.content,
    this.verdict,
  });

  Color _getVerdictColor(String? verdict, BuildContext context) {
    switch (verdict?.toLowerCase()) {
      case 'excellent':
      case 'bon':
        return Colors.green.shade700;
      case 'moyen':
        return Colors.orange.shade700;
      case 'mÃ©diocre':
      case 'Ã  Ã©viter':
        return Colors.red.shade700;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              content,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (verdict != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "Verdict IA: $verdict",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getVerdictColor(verdict, context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EnvironmentalImpactCard extends StatelessWidget {
  final bool isEstimated;
  final String? lifecycleSummary;
  final List<dynamic>? bonusPoints;
  final List<dynamic>? malusPoints;
  final String? perspective;
  final List<dynamic>? warnings;
  final String? co2Info;

  const EnvironmentalImpactCard({
    super.key,
    required this.isEstimated,
    this.lifecycleSummary,
    this.bonusPoints,
    this.malusPoints,
    this.perspective,
    this.warnings,
    this.co2Info,
  });

  @override
  Widget build(BuildContext context) {
    if (lifecycleSummary == null &&
        perspective == null &&
        co2Info == null &&
        (bonusPoints == null || bonusPoints!.isEmpty) &&
        (malusPoints == null || malusPoints!.isEmpty) &&
        (warnings == null || warnings!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEstimated
                        ? "Eco-score Produit (EstimÃ© par IA)"
                        : "Eco-score Produit (Officiel)",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isEstimated)
                  const Tooltip(
                    message:
                        "Cette analyse est une estimation par IA car les donnÃ©es officielles ne sont pas disponibles.",
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (co2Info != null) ...[
              Text(
                "Empreinte Carbone",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_queue, color: Colors.blueGrey),
                title: Text(
                  co2Info!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  isEstimated
                      ? "Estimation par l'IA"
                      : "DonnÃ©e officielle (Agribalyse)",
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (lifecycleSummary != null) ...[
              Text(
                "Analyse du Cycle de Vie",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                lifecycleSummary!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
            ],
            if (perspective != null) ...[
              Text(
                "Mise en perspective",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                perspective!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (bonusPoints != null && bonusPoints!.isNotEmpty) ...[
              Text(
                "Bonus environnementaux",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.green.shade700),
              ),
              ...bonusPoints!.map(
                (point) => _buildPointItem(
                  point.toString(),
                  Icons.check_circle_outline,
                  Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (malusPoints != null && malusPoints!.isNotEmpty) ...[
              Text(
                "Malus environnementaux",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.red.shade700),
              ),
              ...malusPoints!.map(
                (point) => _buildPointItem(
                  point.toString(),
                  Icons.remove_circle_outline,
                  Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (warnings != null && warnings!.isNotEmpty) ...[
              Text(
                "Points de vigilance",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.amber.shade800),
              ),
              ...warnings!.map(
                (point) => _buildPointItem(
                  point.toString(),
                  Icons.warning_amber_rounded,
                  Colors.amber.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPointItem(String text, IconData icon, Color color) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        text.replaceAll("_", " ").replaceAll("-", " ").capitalize(),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }
}

class NutrimentDetailsCard extends StatelessWidget {
  final Map<String, dynamic> nutriments;
  final String? specificCategoryTag;

  const NutrimentDetailsCard({
    super.key,
    required this.nutriments,
    this.specificCategoryTag,
  });

  Widget getNutrimentLevelPill(String key, double value) {
    String text;
    Color color;
    final thresholds = {
      'sugars_100g': [5.0, 22.5],
      'saturated-fat_100g': [1.5, 5.0],
      'salt_100g': [0.3, 1.5],
    };

    if (!thresholds.containsKey(key)) return const SizedBox.shrink();

    if (value <= thresholds[key]![0]) {
      text = 'Faible';
      color = Colors.green;
    } else if (value <= thresholds[key]![1]) {
      text = 'ModÃ©rÃ©';
      color = Colors.orange;
    } else {
      text = 'Ã‰levÃ©';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final relevantNutriments = nutriments.entries.where(
      (entry) =>
          [
            'energy-kcal_100g',
            'saturated-fat_100g',
            'sugars_100g',
            'salt_100g',
            'proteins_100g',
            'carbohydrates_100g',
            'fat_100g',
          ].contains(entry.key) &&
          entry.value != null &&
          (entry.value is num),
    );

    if (relevantNutriments.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "RepÃ¨res Nutritionnels (pour 100g)",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...relevantNutriments.map((entry) {
              final value = (entry.value as num).toDouble();
              String unit;
              if (entry.key.contains('energy')) {
                unit = 'kcal';
              } else if (entry.key.contains('proteins') ||
                  entry.key.contains('carbohydrates') ||
                  entry.key.contains('fat')) {
                unit = 'g';
              } else {
                unit = 'g'; // Default for other macros
              }
              final name = entry.key
                  .capitalize()
                  .replaceAll('_100g', '')
                  .replaceAll('-', ' ');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${value.toStringAsFixed(1)} $unit',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    if (unit == 'g') getNutrimentLevelPill(entry.key, value),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class AdditivesCard extends StatelessWidget {
  final List<dynamic> additivesTags;
  const AdditivesCard({super.key, required this.additivesTags});

  @override
  Widget build(BuildContext context) {
    if (additivesTags.isEmpty) {
      return const SizedBox.shrink();
    }

    final cleanedAdditives =
        additivesTags.map((tag) {
          String tagStr = tag.toString();
          if (tagStr.startsWith('en:')) {
            return tagStr.substring(3).toUpperCase();
          }
          return tagStr.toUpperCase();
        }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Additifs (DonnÃ©es Officielles)",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Icon(
                  Icons.science_outlined,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Ce produit contient ${cleanedAdditives.length} additif${cleanedAdditives.length > 1 ? 's' : ''} selon Open Food Facts.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children:
                  cleanedAdditives.map((additiveName) {
                    return Chip(
                      label: Text(additiveName),
                      backgroundColor: Colors.grey.shade200,
                      avatar: Icon(
                        Icons.label_important_outline,
                        color: Colors.grey.shade700,
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class IngredientAnalysisCard extends StatelessWidget {
  final List<Map<String, dynamic>> analyzedIngredients;
  const IngredientAnalysisCard({super.key, required this.analyzedIngredients});

  Widget buildIngredientChip(int? healthScore) {
    Color color;
    String text;
    if (healthScore == null) {
      color = Colors.grey;
      text = 'N/A';
    } else if (healthScore >= 4) {
      color = Colors.green;
      text = 'Bon';
    } else if (healthScore >= 3) {
      color = Colors.orange;
      text = 'ModÃ©rÃ©';
    } else {
      color = Colors.red;
      text = 'Mauvais';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherIngredients =
        analyzedIngredients
            .where((ing) => ing['category'] != 'Additif')
            .toList();

    if (otherIngredients.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "DÃ©tail des Autres IngrÃ©dients (par l'IA)",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(height: 24),
            for (var ing in otherIngredients) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ing['name'] as String? ?? 'IngrÃ©dient',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        buildIngredientChip(ing['health_score'] as int?),
                      ],
                    ),
                    if (ing['category'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "CatÃ©gorie: ${ing['category']}",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      ing['description'] as String? ??
                          'Description non disponible.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              if (ing != otherIngredients.last) const Divider(),
            ],
          ],
        ),
      ),
    );
  }
}

class ComparisonProductCard extends StatelessWidget {
  final Map<String, dynamic> alternative;
  const ComparisonProductCard({super.key, required this.alternative});

  @override
  Widget build(BuildContext context) {
    final nutriscoreGrade = alternative['nutriscore_grade'] ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading:
            alternative['image_front_small_url'] != null
                ? Image.network(
                  alternative['image_front_small_url'],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (c, e, s) => const Icon(
                        Icons.fastfood,
                        size: 50,
                        color: Colors.grey,
                      ),
                )
                : const Icon(Icons.fastfood, size: 50, color: Colors.grey),
        title: Text(alternative['product_name'] ?? 'Nom inconnu'),
        subtitle: Text(
          'Note CatÃ©gorie: ${alternative['category_score'].toStringAsFixed(1)}/10',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing:
            nutriscoreGrade.isNotEmpty
                ? Image.network(
                  'https://static.openfoodfacts.org/images/attributes/nutriscore-$nutriscoreGrade.png',
                  height: 30,
                  errorBuilder:
                      (c, e, s) => Text(nutriscoreGrade.toUpperCase()),
                )
                : null,
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  final List<String> _scannedCodes = [];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner le code-barres'),
        actions: [
          if (_scannedCodes.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, _scannedCodes),
              child: const Text(
                'Terminer',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;
                final String? barcodeValue = barcodes.first.rawValue;
                if (barcodeValue == null) return;

                if (!_scannedCodes.contains(barcodeValue)) {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _scannedCodes.add(barcodeValue);
                  });
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Code ajouté: $barcodeValue'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ),
          if (_scannedCodes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Codes scannÃ©s',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _scannedCodes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _scannedCodes[index],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_scannedCodes.length} article(s) scannÃ©(s). Appuyez sur Terminer lorsque vous avez terminÃ©.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class RecipeBuilderScreen extends StatefulWidget {
  const RecipeBuilderScreen({super.key});

  @override
  State<RecipeBuilderScreen> createState() => _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends State<RecipeBuilderScreen> {
  final TextEditingController _recipeNameController = TextEditingController();
  int _portions = 1;
  final List<FoodEntry> _ingredients = [];

  int get totalKcal => _ingredients.fold(0, (sum, item) => sum + item.calories);
  double get totalPro =>
      _ingredients.fold(0.0, (sum, item) => sum + item.proteins);
  double get totalCarbs =>
      _ingredients.fold(0.0, (sum, item) => sum + item.carbs);
  double get totalFats =>
      _ingredients.fold(0.0, (sum, item) => sum + item.fats);

  void _saveRecipe() {
    if (_recipeNameController.text.isEmpty || _ingredients.isEmpty) return;

    final recipePerPortion = FoodEntry(
      name: 'ðŸ½ï¸ ${_recipeNameController.text} (1 portion)',
      calories: (totalKcal / _portions).round(),
      proteins: totalPro / _portions,
      carbs: totalCarbs / _portions,
      fats: totalFats / _portions,
      timestamp: DateTime.now(),
      source: 'Recette Perso',
    );

    Navigator.pop(context, recipePerPortion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CrÃ©er une Recette'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveRecipe),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _recipeNameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la recette (ex: Lasagnes)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Nombre de portions : ',
                style: TextStyle(fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed:
                    () => setState(
                      () => _portions = _portions > 1 ? _portions - 1 : 1,
                    ),
              ),
              Text(
                '$_portions',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _portions++),
              ),
            ],
          ),
          Card(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MacroStat(
                    label: 'Kcal/port.',
                    value: (totalKcal / _portions).toStringAsFixed(0),
                  ),
                  _MacroStat(
                    label: 'Pro/port.',
                    value: '${(totalPro / _portions).toStringAsFixed(1)}g',
                  ),
                  _MacroStat(
                    label: 'Glu/port.',
                    value: '${(totalCarbs / _portions).toStringAsFixed(1)}g',
                  ),
                  _MacroStat(
                    label: 'Lip/port.',
                    value: '${(totalFats / _portions).toStringAsFixed(1)}g',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _ingredients.length,
              itemBuilder: (context, index) {
                final ing = _ingredients[index];
                return ListTile(
                  title: Text(ing.name),
                  subtitle: Text('${ing.calories} kcal'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed:
                        () => setState(() => _ingredients.removeAt(index)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                // On simule une boÃ®te de dialogue rapide pour ajouter un ingrÃ©dient
                String nom = '';
                int cal = 0;
                await showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text("Ajouter un ingrÃ©dient"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              onChanged: (v) => nom = v,
                              decoration: const InputDecoration(
                                labelText: "Nom",
                              ),
                            ),
                            TextField(
                              onChanged: (v) => cal = int.tryParse(v) ?? 0,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Calories",
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Annuler"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (nom.isNotEmpty && cal > 0) {
                                setState(() {
                                  _ingredients.add(
                                    FoodEntry(
                                      name: nom,
                                      calories: cal,
                                      proteins: 0,
                                      carbs: 0,
                                      fats: 0,
                                      timestamp: DateTime.now(),
                                    ),
                                  );
                                });
                                Navigator.pop(ctx);
                              }
                            },
                            child: const Text("Ajouter"),
                          ),
                        ],
                      ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un ingrÃ©dient'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final String value;
  const _MacroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      Text(label, style: const TextStyle(color: Colors.grey)),
    ],
  );
}

class ScoreCircle extends StatelessWidget {
  final double score;
  final String title;
  final bool isEnvironmental;
  final String? letterScore;

  const ScoreCircle({
    required this.score,
    required this.title,
    this.isEnvironmental = false,
    this.letterScore,
    super.key,
  });

  Color getScoreColor() {
    if (isEnvironmental) {
      if (score >= 80) return Colors.green.shade700;
      if (score >= 60) return Colors.lightGreen;
      if (score >= 40) return Colors.yellow.shade700;
      if (score >= 20) return Colors.orange.shade700;
      return Colors.red.shade700;
    } else {
      if (score >= 7.5) return Colors.green;
      if (score >= 5) return Colors.orange;
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: isEnvironmental ? score / 100.0 : score / 10.0,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(getScoreColor()),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isEnvironmental && letterScore != null)
                      Text(
                        letterScore!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: getScoreColor(),
                        ),
                      ),
                    Text(
                      isEnvironmental && letterScore != null
                          ? score.toStringAsFixed(0)
                          : score.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize:
                            isEnvironmental && letterScore != null ? 18 : 28,
                        fontWeight: FontWeight.bold,
                        color: getScoreColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
