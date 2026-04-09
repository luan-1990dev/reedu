import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Função auxiliar para pegar o UID atualizado no momento da chamada
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // Atualizar URL da foto do perfil
  Future<void> updateProfilePicture(String url) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'photoUrl': url,
    }, SetOptions(merge: true));
  }

  // Limpar estatísticas de consumo
  Future<void> clearMenuStats() async {
    final uid = _currentUid;
    if (uid == null) return;
    
    final logs = await _db.collection('users').doc(uid).collection('menu_consumption_logs').get();
    for (var doc in logs.docs) { await doc.reference.delete(); }

    final stats = await _db.collection('users').doc(uid).collection('menu_stats').get();
    for (var doc in stats.docs) { await doc.reference.delete(); }
  }

  // Salvar perfil com metas
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
      'height': height ?? 1.82,
      'targetWeight': targetWeight ?? 86.0,
      'waterTarget': 4.0,
      'calorieTarget': 1800,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Salvar cardápio
  Future<void> saveMenu(Map<String, String> menu) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'menu': menu,
      'menuUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Salvar suplementação
  Future<void> saveSupplements(Map<String, String> supplements) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'supplements': supplements,
      'supplementsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Registrar consumo inteligente (30 dias)
  Future<void> logMenuOptionConsumption(String mealType, String option) async {
    final uid = _currentUid;
    if (uid == null) return;
    
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final oldLogs = await _db.collection('users').doc(uid)
        .collection('menu_consumption_logs')
        .where('timestamp', isLessThan: thirtyDaysAgo)
        .get();
    
    for (var doc in oldLogs.docs) { await doc.reference.delete(); }

    await _db.collection('users').doc(uid).collection('menu_consumption_logs').add({
      'mealType': mealType,
      'option': option,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final activeLogs = await _db.collection('users').doc(uid).collection('menu_consumption_logs').get();
    final currentStats = await _db.collection('users').doc(uid).collection('menu_stats').get();
    for (var doc in currentStats.docs) { await doc.reference.delete(); }

    Map<String, int> counts = {};
    Map<String, String> types = {};
    for (var log in activeLogs.docs) {
      String opt = log['option'];
      counts[opt] = (counts[opt] ?? 0) + 1;
      types[opt] = log['mealType'];
    }

    for (var entry in counts.entries) {
      await _db.collection('users').doc(uid).collection('menu_stats').doc(entry.key).set({
        'count': entry.value,
        'mealType': types[entry.key],
      });
    }
  }

  Future<void> saveMealSchedule(List<Map<String, dynamic>> schedules) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({'meal_schedules': schedules}, SetOptions(merge: true));
  }

  Future<void> toggleMealCompletion(String mealKey, dynamic status) async {
    final uid = _currentUid;
    if (uid == null) return;
    String today = DateTime.now().toIso8601String().split('T')[0];
    DocumentReference statsDoc = _db.collection('users').doc(uid).collection('daily_stats').doc(today);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(statsDoc);
      Map<String, dynamic> mealStatus = {};
      if (snapshot.exists) {
        mealStatus = Map<String, dynamic>.from((snapshot.data() as Map<String, dynamic>)['meal_checks'] ?? {});
      }
      mealStatus[mealKey] = status;
      if (!snapshot.exists) {
        transaction.set(statsDoc, {'meal_checks': mealStatus, 'water': 0.0, 'calories': 0});
      } else {
        transaction.update(statsDoc, {'meal_checks': mealStatus});
      }
    });
  }

  Future<void> addWater([double amount = 0.25]) async {
    final uid = _currentUid;
    if (uid == null) return;
    String today = DateTime.now().toIso8601String().split('T')[0];
    DocumentReference waterDoc = _db.collection('users').doc(uid).collection('daily_stats').doc(today);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(waterDoc);
      if (!snapshot.exists) {
        transaction.set(waterDoc, {'water': amount, 'calories': 0});
      } else {
        double currentWater = (snapshot.data() as Map<String, dynamic>)['water'] ?? 0.0;
        transaction.update(waterDoc, {'water': currentWater + amount});
      }
    });
  }

  Future<void> setWaterTotal(double total) async {
    final uid = _currentUid;
    if (uid == null) return;
    String today = DateTime.now().toIso8601String().split('T')[0];
    await _db.collection('users').doc(uid).collection('daily_stats').doc(today).set({'water': total}, SetOptions(merge: true));
  }

  Future<void> saveAssessment(Map<String, dynamic> data) async {
    final uid = _currentUid;
    if (uid == null) return;
    Map<String, dynamic> processedData = {};
    data.forEach((key, value) { processedData[key] = double.tryParse(value.toString().replaceAll(',', '.')) ?? value; });
    await _db.collection('users').doc(uid).collection('assessments').add({...processedData, 'timestamp': FieldValue.serverTimestamp()});
    if (processedData.containsKey('Peso')) {
      await _db.collection('users').doc(uid).set({'currentWeight': processedData['Peso']}, SetOptions(merge: true));
    }
  }

  Stream<QuerySnapshot> get topMenuOptions => _db.collection('users').doc(_currentUid).collection('menu_stats').orderBy('count', descending: true).limit(5).snapshots();
  Stream<QuerySnapshot> get weightHistory => _db.collection('users').doc(_currentUid).collection('assessments').orderBy('timestamp', descending: false).snapshots();
  Stream<DocumentSnapshot> get todayStats {
    String today = DateTime.now().toIso8601String().split('T')[0];
    return _db.collection('users').doc(_currentUid).collection('daily_stats').doc(today).snapshots();
  }
  Stream<DocumentSnapshot> get userProfileStream => _db.collection('users').doc(_currentUid).snapshots();
}
