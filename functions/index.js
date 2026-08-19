const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const getDb = () => admin.firestore();

/**
 * Cloud Function Callable unifiée pour le TEXTE et les IMAGES via SiliconFlow (Qwen).
 * Remplace DeepSeek et Gemini.
 */
exports.callAI = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'L\'utilisateur doit être authentifié.');
  }

  const uid = context.auth.uid;
  const prompt = data.prompt;
  const imageBase64 = data.imageBase64;
  const apiType = data.apiType || (imageBase64 ? 'photo_analysis_ia' : 'deepseek_api_calls');

  // 🧠 ROUTAGE INTELLIGENT
  const defaultModel = imageBase64 ? 'Qwen/Qwen2.5-VL-7B-Instruct' : 'Qwen/Qwen2.5-7B-Instruct';
  const requestedModel = data.model || defaultModel;

  const allowedModels = [
    'Qwen/Qwen2.5-7B-Instruct',
    'Qwen/Qwen2.5-VL-7B-Instruct',
    'Qwen/Qwen2.5-72B-Instruct',
    'Qwen/Qwen3.5-9B',
    'deepseek-ai/DeepSeek-V3'
  ];

  if (!allowedModels.includes(requestedModel)) {
    throw new functions.https.HttpsError('invalid-argument', 'Modèle IA non autorisé.');
  }

  if (!prompt || typeof prompt !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Le paramètre prompt est obligatoire.');
  }

  // --- QUOTA & TRACKING (Correction Quotas Dynamiques & Firestore Premium Status) ---
  const db = getDb();
  const today = new Date().toISOString().split('T')[0];
  const usageRef = db.collection('users').doc(uid).collection('usageTracking').doc(today);
  const subscriptionRef = db.collection('users').doc(uid).collection('subscription').doc('status');

  // ✅ FIX #2 : Limite dynamique selon le type d'appel (1/jour photo, 5/jour texte ou scan)
  let dailyLimit = 5;
  if (apiType === 'photo_analysis_ia') {
    dailyLimit = 1;
  }

  await db.runTransaction(async (transaction) => {
    const usageDoc = await transaction.get(usageRef);
    const subDoc = await transaction.get(subscriptionRef);

    // ✅ FIX #1 : Vérification Premium basée sur Firestore subscription/status
    const isPremium = subDoc.exists && subDoc.data().isPremium === true;

    const usageData = usageDoc.exists ? usageDoc.data() : {};
    const currentCalls = usageData[apiType] || 0;

    if (!isPremium && currentCalls >= dailyLimit) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Limite quotidienne atteinte pour ${apiType} (${dailyLimit}/jour). Passez Premium !`
      );
    }

    // Incrémentation du compteur SPÉCIFIQUE
    transaction.set(
      usageRef,
      {
        [apiType]: admin.firestore.FieldValue.increment(1),
        lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000))
      },
      { merge: true }
    );
  });

  const rawKey = process.env.SILICONFLOW_API_KEY || (functions.config().siliconflow && functions.config().siliconflow.api_key);
  const apiKey = rawKey ? rawKey.trim() : null;

  if (!apiKey || apiKey === 'sk-okxcdcchrijefvzyqutnczztxywhdcdyvbtjuxazbmaxxuze') {
    throw new functions.https.HttpsError(
      'internal',
      'Clé API SiliconFlow non configurée ou invalide. Veuillez configurer SILICONFLOW_API_KEY avec une clé valide.'
    );
  }

  let userContent = [];
  if (imageBase64) {
    // ✅ FIX #5 : Détection dynamique du type MIME
    const mimeType = getMimeTypeFromBase64(imageBase64);
    userContent.push({
      type: "image_url",
      image_url: { url: `data:${mimeType};base64,${imageBase64}` }
    });
  }
  userContent.push({ type: "text", text: prompt });

  // ✅ FIX #4 : System prompt strict sans `response_format`
  const systemPrompt = "Tu es un assistant IA expert. Tu dois impérativement répondre UNIQUEMENT avec un objet JSON valide, sans aucun texte avant ou après, sans balises markdown comme ```json.";

  const messages = [
    { role: "system", content: systemPrompt },
    { role: "user", content: userContent }
  ];

  try {
    const response = await fetch('https://api.siliconflow.cn/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: requestedModel,
        messages: messages,
        temperature: data.temperature || 0.5,
        max_tokens: 4000
        // ❌ FIX #4 : response_format retiré pour éviter l'erreur 400 sur Qwen-VL
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error('SiliconFlow Error:', response.status, errText);
      if (response.status === 401) {
        throw new functions.https.HttpsError(
          'internal',
          'Erreur API IA (401) : Clé API SiliconFlow invalide ou expirée. Veuillez générer une clé valide sur cloud.siliconflow.cn.'
        );
      }
      throw new functions.https.HttpsError('internal', `Erreur API IA (${response.status})`);
    }

    const jsonResult = await response.json();
    return { success: true, data: jsonResult };

  } catch (error) {
    console.error('CallAI Exception:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message || 'Erreur lors de l\'appel IA.');
  }
});

/**
 * Cloud Function Callable pour attribuer un Custom Claim (Statut Premium) à un utilisateur.
 * 🔒 SÉCURISÉ : Réservé aux Administrateurs.
 */
exports.setPremiumStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Utilisateur non authentifié.');
  }

  if (context.auth.token.isAdmin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Action réservée aux administrateurs.');
  }

  const targetUid = data.targetUid || data.uid;
  const isPremium = data.isPremium === true;

  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'L\'UID de l\'utilisateur cible (targetUid) est requis.');
  }

  try {
    // ✅ FIX #1 : Écriture au bon endroit dans Firestore (subscription/status)
    const subscriptionRef = admin.firestore()
      .collection('users').doc(targetUid)
      .collection('subscription').doc('status');

    await subscriptionRef.set({
      isPremium: isPremium,
      updateDate: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // ✅ FIX #3 : Fusion des Custom Claims (ne pas écraser les anciens rôles)
    const userRecord = await admin.auth().getUser(targetUid);
    const currentClaims = userRecord.customClaims || {};

    if (isPremium) {
      currentClaims.isPremium = true;
    } else {
      delete currentClaims.isPremium;
    }

    await admin.auth().setCustomUserClaims(targetUid, currentClaims);

    // Journal d'audit (Audit Log)
    await admin.firestore().collection('admin_logs').add({
      action: 'setPremiumStatus',
      targetUid: targetUid,
      isPremium: isPremium,
      adminUid: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, message: `Statut Premium mis à jour pour ${targetUid}` };
  } catch (error) {
    console.error('Erreur setPremiumStatus:', error);
    throw new functions.https.HttpsError('internal', 'Erreur lors de la mise à jour du statut Premium.');
  }
});

/**
 * ✅ Simule un achat Premium (À remplacer par Stripe/RevenueCat en production)
 */
exports.simulatePurchase = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Non authentifié.');
  }

  const uid = context.auth.uid;
  const isPremium = data.isPremium === true;

  try {
    // 1. Mise à jour Firestore
    const subscriptionRef = admin.firestore().collection('users').doc(uid).collection('subscription').doc('status');
    await subscriptionRef.set({
      isPremium: isPremium,
      updateDate: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // 2. Mise à jour des Custom Claims (pour que les règles de sécurité Firestore fonctionnent)
    const userRecord = await admin.auth().getUser(uid);
    const currentClaims = userRecord.customClaims || {};
    if (isPremium) currentClaims.isPremium = true;
    else delete currentClaims.isPremium;

    await admin.auth().setCustomUserClaims(uid, currentClaims);

    return { success: true, message: 'Statut mis à jour' };
  } catch (error) {
    console.error('Erreur simulatePurchase:', error);
    throw new functions.https.HttpsError('internal', 'Erreur lors de la simulation d\'achat.');
  }
});

/**
 * ✅ FIX #5 : Helper pour détection du MIME Type via Base64 magic numbers
 */
function getMimeTypeFromBase64(base64String) {
  if (!base64String) return 'image/jpeg';
  if (base64String.startsWith('/9j/')) return 'image/jpeg';
  if (base64String.startsWith('iVBORw0KGgo')) return 'image/png';
  if (base64String.startsWith('R0lGOD')) return 'image/gif';
  if (base64String.startsWith('UklGR')) return 'image/webp';
  return 'image/jpeg';
}

/**
 * ✅ SÉCURISÉ : Met à jour la série de connexion côté serveur.
 * Empêche le client de s'attribuer des jours de série manuellement.
 */
exports.updateUserStreak = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise.');
  }
  const db = getDb();
  const uid = context.auth.uid;
  const userRef = db.collection('users').doc(uid);

  return db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    const userData = userDoc.exists ? userDoc.data() : {};

    // Date locale au format YYYY-MM-DD
    const now = new Date();
    const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    const lastLoginStr = userData.lastLoginDate;
    let streak = userData.loginStreak || 0;

    if (lastLoginStr === todayStr) {
      return { streak: streak, message: 'Déjà comptabilisé aujourd\'hui' };
    }

    if (lastLoginStr) {
      const lastDateParts = lastLoginStr.split('-');
      const lastDate = new Date(lastDateParts[0], lastDateParts[1] - 1, lastDateParts[2]);
      const todayDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());

      const diffTime = Math.abs(todayDate - lastDate);
      const daysDiff = Math.round(diffTime / (1000 * 60 * 60 * 24));

      if (daysDiff === 1) {
        streak += 1;
      } else if (daysDiff > 1) {
        streak = 1; // Série brisée
      }
    } else {
      streak = 1; // Première connexion
    }

    streak = Math.min(streak, 365); // Plafond de sécurité

    transaction.set(userRef, {
      lastLoginDate: todayStr,
      loginStreak: streak,
      lastActive: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return { streak: streak, message: 'Série mise à jour avec succès' };
  });
});

/**
 * ✅ SÉCURISÉ : Évalue et débloque les badges côté serveur.
 * Le client ne peut PAS écrire directement dans la collection 'badges'.
 */
exports.evaluateAndAwardBadges = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise.');
  }
  const db = getDb();
  const uid = context.auth.uid;

  // Récupération des données en parallèle pour la performance
  const [userDoc, foodsSnap, fastsSnap, activitiesSnap, scansSnap] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('users').doc(uid).collection('foodEntries').get(),
    db.collection('users').doc(uid).collection('fastingSessions').get(),
    db.collection('users').doc(uid).collection('activities').get(),
    db.collection('users').doc(uid).collection('scannedProducts').get()
  ]);

  if (!userDoc.exists) throw new functions.https.HttpsError('not-found', 'Utilisateur non trouvé.');
  const userData = userDoc.data();
  const streak = userData.loginStreak || 0;

  const foods = foodsSnap.docs.map(d => d.data());
  const fasts = fastsSnap.docs.map(d => d.data());
  const activities = activitiesSnap.docs.map(d => d.data());
  const scans = scansSnap.docs.map(d => d.data());

  const badgesToAward = [];
  const batch = db.batch();

  // --- LOGIQUE D'ÉVALUATION SÉCURISÉE ---
  if (foods.length > 0) badgesToAward.push({ id: 'first_meal', currentProgress: 1, isUnlocked: true });
  if (streak >= 3) badgesToAward.push({ id: 'streak_3', currentProgress: streak, isUnlocked: true });
  if (streak >= 7) badgesToAward.push({ id: 'streak_7', currentProgress: streak, isUnlocked: true });
  if (streak >= 30) badgesToAward.push({ id: 'streak_30', currentProgress: streak, isUnlocked: true });

  if (scans.length > 0) badgesToAward.push({ id: 'first_scan', currentProgress: 1, isUnlocked: true });

  const ecoScans = scans.filter(s => s.nutriScore === 'A' || s.nutriScore === 'B').length;
  if (ecoScans >= 5) badgesToAward.push({ id: 'eco_hero_5', currentProgress: 5, isUnlocked: true });

  const hasBurned500 = activities.some(a => (a.caloriesBurned || 0) >= 500);
  if (hasBurned500) badgesToAward.push({ id: 'calorie_burner_500', currentProgress: 1, isUnlocked: true });

  const hasFast12h = fasts.some(f => (f.durationSeconds || 0) >= 43200);
  if (hasFast12h) badgesToAward.push({ id: 'first_fast', currentProgress: 1, isUnlocked: true });

  // Appliquer les mises à jour uniquement si le badge n'est pas déjà débloqué
  for (const badge of badgesToAward) {
    const badgeRef = db.collection('users').doc(uid).collection('badges').doc(badge.id);
    const badgeDoc = await badgeRef.get();

    if (!badgeDoc.exists || !badgeDoc.data().isUnlocked) {
      batch.set(badgeRef, {
        currentProgress: badge.currentProgress,
        isUnlocked: true,
        unlockedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }
  }

  await batch.commit();
  return { success: true, awarded: badgesToAward.map(b => b.id) };
});