import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Atalho para pegar o UID do usuário logado de forma segura
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // --- MÉTODOS DE PERFIL E CADASTRO ---

  Future<void> saveUserProfile(String name, String email, {
    int? age,
    double? height,
    double? targetWeight,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'age': age ?? 35,
      'height': height ?? 1.80,
      'targetWeight': targetWeight ?? 80.0,
      'waterTarget': 4.0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- MÉTODOS DE AVALIAÇÃO (ASSESSMENT) ---

  Future<DocumentSnapshot?> getLatestAssessment() async {
    final uid = _currentUid;
    if (uid == null) return null;
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('assessments')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) return querySnapshot.docs.first;
    } catch (e) {
      print("Erro ao buscar última avaliação: $e");
    }
    return null;
  }

  /// MÉTODO DE SALVAMENTO: Garante o formato numérico e timestamp
  Future<void> saveAssessment(Map<String, dynamic> data) async {
    final uid = _currentUid;
    if (uid == null) return;

    Map<String, dynamic> processedData = {};

    data.forEach((key, value) {
      if (value is String) {
        String cleanValue = value.replaceAll(',', '.').trim();
        processedData[key] = double.tryParse(cleanValue) ?? value;
      } else {
        processedData[key] = value;
      }
    });

    await _db.collection('users').doc(uid).collection('assessments').add({
      ...processedData,
      'timestamp': FieldValue.serverTimestamp(),
    });

    Map<String, dynamic> profileUpdate = {};
    if (processedData.containsKey('Peso')) profileUpdate['currentWeight'] = processedData['Peso'];
    if (processedData.containsKey('IDADE')) profileUpdate['age'] = processedData['IDADE'];
    if (processedData.containsKey('ALTURA')) profileUpdate['height'] = processedData['ALTURA'];
    if (processedData.containsKey('PESO META')) profileUpdate['targetWeight'] = processedData['PESO META'];

    if (profileUpdate.isNotEmpty) {
      await _db.collection('users').doc(uid).set(profileUpdate, SetOptions(merge: true));
    }
  }

  // --- MÉTODOS DO CARDÁPIO E ESTATÍSTICAS ---

  Future<void> saveMenu(Map<String, String> menu) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'menu': menu,
      'menuUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logMenuOptionConsumption(String mealKey, String option) async {
    final uid = _currentUid;
    if (uid == null) return;

    DocumentReference statRef = _db.collection('users').doc(uid).collection('menu_stats').doc('$option:$mealKey');

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(statRef);
      if (!snapshot.exists) {
        transaction.set(statRef, {'count': 1, 'mealType': mealKey, 'option': option});
      } else {
        int currentCount = (snapshot.data() as Map<String, dynamic>)['count'] ?? 0;
        transaction.update(statRef, {'count': currentCount + 1});
      }
    });
  }

  Stream<QuerySnapshot> get topMenuOptions {
    return _db
        .collection('users')
        .doc(_currentUid)
        .collection('menu_stats')
        .orderBy('count', descending: true)
        .limit(10)
        .snapshots();
  }

  Future<void> clearMenuStats() async {
    final uid = _currentUid;
    if (uid == null) return;
    final stats = await _db.collection('users').doc(uid).collection('menu_stats').get();
    for (var doc in stats.docs) {
      await doc.reference.delete();
    }
  }

  // --- MÉTODOS DE AGENDA E SUPLEMENTOS ---

  Future<void> saveMealSchedule(List<Map<String, dynamic>> schedules) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({'meal_schedules': schedules}, SetOptions(merge: true));
  }

  Future<void> saveSupplements(Map<String, String> supplements) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'supplements': supplements,
      'supplementsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- CONTROLE DIÁRIO (CHECKS E ÁGUA) ---

  Future<void> toggleMealCompletion(String mealKey, dynamic status) async {
    final uid = _currentUid;
    if (uid == null) return;
    String today = DateTime.now().toIso8601String().split('T')[0];
    DocumentReference statsDoc = _db.collection('users').doc(uid).collection('daily_stats').doc(today);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(statsDoc);
      Map<String, dynamic> mealStatus = snapshot.exists ? Map<String, dynamic>.from((snapshot.data() as Map)['meal_checks'] ?? {}) : {};
      mealStatus[mealKey] = status;
      transaction.set(statsDoc, {'meal_checks': mealStatus}, SetOptions(merge: true));
    });

    if (status is String) {
      await logMenuOptionConsumption(mealKey, status);
    }
  }

  // --- NOVOS MÉTODOS DE ÁGUA POR TURNO ---

  Future<void> updateWaterSlotAmount(String slotKey, String amount) async {
    final uid = _currentUid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).set({
      'water_goals': {
        slotKey: amount,
      }
    }, SetOptions(merge: true));
  }

  Future<void> toggleWaterSlot(String slotKey, bool status) async {
    final uid = _currentUid;
    if (uid == null) return;

    String today = DateTime.now().toIso8601String().split('T')[0];
    DocumentReference statsDoc = _db.collection('users').doc(uid).collection('daily_stats').doc(today);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(statsDoc);
      Map<String, dynamic> waterChecks = {};
      if (snapshot.exists) {
        waterChecks = Map<String, dynamic>.from((snapshot.data() as Map)['water_checks'] ?? {});
      }
      waterChecks[slotKey] = status;
      transaction.set(statsDoc, {'water_checks': waterChecks}, SetOptions(merge: true));
    });
  }

  // --- MÉTODOS GERAIS DE ÁGUA ---

  Future<void> addWater([double amount = 0.25]) async {
    final uid = _currentUid;
    if (uid == null) return;
    String today = DateTime.now().toIso8601String().split('T')[0];
    DocumentReference waterDoc = _db.collection('users').doc(uid).collection('daily_stats').doc(today);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(waterDoc);
      double current = snapshot.exists ? (snapshot.data() as Map<String, dynamic>)['water'] ?? 0.0 : 0.0;
      transaction.set(waterDoc, {'water': current + amount}, SetOptions(merge: true));
    });
  }

  Future<void> setWaterTotal(double total) async {
    String today = DateTime.now().toIso8601String().split('T')[0];
    await _db.collection('users').doc(_currentUid).collection('daily_stats').doc(today).set({'water': total}, SetOptions(merge: true));
  }

  Future<void> updateProfilePicture(String url) async {
    await _db.collection('users').doc(_currentUid).set({'photoUrl': url}, SetOptions(merge: true));
  }

  // --- STREAMS ---

  Stream<QuerySnapshot> get weightHistory {
    return _db
        .collection('users')
        .doc(_currentUid)
        .collection('assessments')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Stream<DocumentSnapshot> get todayStats => _db.collection('users').doc(_currentUid).collection('daily_stats').doc(DateTime.now().toIso8601String().split('T')[0]).snapshots();
  Stream<DocumentSnapshot> get userProfileStream => _db.collection('users').doc(_currentUid).snapshots();
}