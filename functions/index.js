const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const getDb = () => admin.firestore();

function getMimeTypeFromBase64(base64String) {
  if (!base64String) return 'image/jpeg';
  if (base64String.startsWith('/9j/')) return 'image/jpeg';
  if (base64String.startsWith('iVBORw0KGgo')) return 'image/png';
  if (base64String.startsWith('R0lGOD')) return 'image/gif';
  if (base64String.startsWith('UklGR')) return 'image/webp';
  return 'image/jpeg';
}

/**
 * Cloud Function Callable unifiée pour le TEXTE et les IMAGES via SiliconFlow (Qwen).
 */
exports.callAI = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'L\'utilisateur doit être authentifié.');
  }

  const uid = context.auth.uid;
  const prompt = data.prompt;
  const imageBase64 = data.imageBase64;

  if (imageBase64 && imageBase64.length > 3 * 1024 * 1024) {
    throw new functions.https.HttpsError('invalid-argument', 'Image trop volumineuse (max 3Mo).');
  }
  if (!prompt || typeof prompt !== 'string' || prompt.length > 4000) {
    throw new functions.https.HttpsError('invalid-argument', 'Le paramètre prompt est obligatoire et limité à 4000 caractères.');
  }

  const apiType = data.apiType || (imageBase64 ? 'photo_analysis_ia' : 'deepseek_api_calls');

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

  const db = getDb();
  const today = new Date().toISOString().split('T')[0];
  const userRef = db.collection('users').doc(uid);
  const usageRef = userRef.collection('usageTracking').doc(today);
  const subscriptionRef = userRef.collection('subscription').doc('status');

  const [userDoc, subDoc, usageDoc] = await Promise.all([
    userRef.get(),
    subscriptionRef.get(),
    usageRef.get()
  ]);

  const isPremium = subDoc.exists && subDoc.data().isPremium === true;
  const streak = (userDoc.exists && userDoc.data().loginStreak) ? userDoc.data().loginStreak : 0;

  const dailyLimit = (apiType === 'photo_analysis_ia')
    ? 1
    : 5 + Math.floor(streak / 5) * 3;

  const currentUsage = (usageDoc.exists && usageDoc.data()[apiType]) ? usageDoc.data()[apiType] : 0;

  if (!isPremium && currentUsage >= dailyLimit) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `Limite quotidienne atteinte pour ${apiType} (${dailyLimit}/jour). Passez Premium !`
    );
  }

  const rawKey = process.env.SILICONFLOW_API_KEY || (functions.config().siliconflow && functions.config().siliconflow.api_key);
  const apiKey = rawKey ? rawKey.trim() : null;

  if (!apiKey) {
    throw new functions.https.HttpsError(
      'internal',
      'Clé API SiliconFlow non configurée.'
    );
  }

  let userContent;
  if (imageBase64) {
    const mimeType = getMimeTypeFromBase64(imageBase64);
    userContent = [
      {
        type: "image_url",
        image_url: {
          url: `data:${mimeType};base64,${imageBase64}`,
          detail: "low"
        }
      },
      { type: "text", text: prompt }
    ];
  } else {
    userContent = prompt;
  }

  const systemPrompt = "Tu es un assistant IA expert en santé et nutrition. Tu t'exprimes en français parfait, clair, naturel et sans aucune faute d'orthographe ni répétition. Tu réponds UNIQUEMENT en JSON valide.";

  const messages = [
    { role: "system", content: systemPrompt },
    { role: "user", content: userContent }
  ];

  try {
    const safeTemp = Math.min(Math.max(data.temperature !== undefined ? data.temperature : 0.4, 0.1), 0.5);

    const requestBody = {
      model: requestedModel,
      messages: messages,
      temperature: safeTemp,
      top_p: 0.85,
      frequency_penalty: 0.3,
      presence_penalty: 0.1,
      max_tokens: 3000
    };

    if (requestedModel.includes('Qwen3')) {
      requestBody.enable_thinking = false;
    }

    if (!imageBase64 && !requestedModel.includes('VL') && !requestedModel.includes('DeepSeek-V3')) {
      requestBody.response_format = { type: "json_object" };
    }

    const response = await fetch('https://api.siliconflow.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error('SiliconFlow Error:', response.status, errText);
      throw new functions.https.HttpsError('internal', `Erreur API IA (${response.status})`);
    }

    const jsonResult = await response.json();

    await usageRef.set({
      [apiType]: admin.firestore.FieldValue.increment(1),
      lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000))
    }, { merge: true });

    return { success: true, data: jsonResult };

  } catch (error) {
    console.error('CallAI Exception:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message || 'Erreur lors de l\'appel IA.');
  }
});

exports.simulatePurchase = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Non authentifié.');
  }

  const uid = context.auth.uid;
  const isPremium = data.isPremium === true;

  try {
    const subscriptionRef = admin.firestore().collection('users').doc(uid).collection('subscription').doc('status');
    await subscriptionRef.set({
      isPremium: isPremium,
      updateDate: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

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

    const todayStr = data.clientDate || new Date().toISOString().split('T')[0];
    const lastLoginStr = userData.lastLoginDate;
    let streak = userData.loginStreak || 0;

    if (lastLoginStr === todayStr) {
      return { streak: streak, message: 'Déjà comptabilisé aujourd\'hui' };
    }

    if (lastLoginStr) {
      const lastDateParts = lastLoginStr.split('-');
      const lastDate = new Date(Date.UTC(lastDateParts[0], lastDateParts[1] - 1, lastDateParts[2]));
      const todayDate = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), new Date().getUTCDate()));

      const diffTime = Math.abs(todayDate - lastDate);
      const daysDiff = Math.round(diffTime / (1000 * 60 * 60 * 24));

      if (daysDiff === 1) {
        streak += 1;
      } else if (daysDiff > 1) {
        streak = 1;
      }
    } else {
      streak = 1;
    }

    streak = Math.min(streak, 365);

    transaction.set(userRef, {
      lastLoginDate: todayStr,
      loginStreak: streak,
      lastActive: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return { streak: streak, message: 'Série mise à jour avec succès' };
  });
});

exports.evaluateAndAwardBadges = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise.');
  }
  const db = getDb();
  const uid = context.auth.uid;

  const [userDoc, foodsCount, fastsSnap, activitiesCount, burn500Snap, scansCount, ecoScansSnap] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('users').doc(uid).collection('foodEntries').count().get(),
    db.collection('users').doc(uid).collection('fastingSessions').get(),
    db.collection('users').doc(uid).collection('activities').count().get(),
    db.collection('users').doc(uid).collection('activities').where('caloriesBurned', '>=', 500).limit(1).get(),
    db.collection('users').doc(uid).collection('scannedProducts').count().get(),
    db.collection('users').doc(uid).collection('scannedProducts').where('nutriScore', 'in', ['A', 'B']).limit(5).get()
  ]);

  if (!userDoc.exists) throw new functions.https.HttpsError('not-found', 'Utilisateur non trouvé.');
  const userData = userDoc.data();
  const streak = userData.loginStreak || 0;

  const hasFoods = foodsCount.data().count > 0;
  const hasScans = scansCount.data().count > 0;
  const ecoScansCount = ecoScansSnap.size;
  const hasBurned500 = burn500Snap.size > 0;
  const fasts = fastsSnap.docs.map(d => d.data());

  const badgesToAward = [];
  const batch = db.batch();

  if (hasFoods) badgesToAward.push({ id: 'first_meal', currentProgress: 1, isUnlocked: true });
  if (streak >= 3) badgesToAward.push({ id: 'streak_3', currentProgress: streak, isUnlocked: true });
  if (streak >= 7) badgesToAward.push({ id: 'streak_7', currentProgress: streak, isUnlocked: true });
  if (streak >= 30) badgesToAward.push({ id: 'streak_30', currentProgress: streak, isUnlocked: true });

  if (hasScans) badgesToAward.push({ id: 'first_scan', currentProgress: 1, isUnlocked: true });
  if (ecoScansCount >= 5) badgesToAward.push({ id: 'eco_hero_5', currentProgress: 5, isUnlocked: true });
  if (hasBurned500) badgesToAward.push({ id: 'calorie_burner_500', currentProgress: 1, isUnlocked: true });

  const hasFast12h = fasts.some(f => {
    const duration = f.durationSeconds || 0;
    const target = f.targetDurationSeconds || 43200;
    return duration >= 43200 || (target > 0 && duration >= target);
  });
  if (hasFast12h) badgesToAward.push({ id: 'first_fast', currentProgress: 1, isUnlocked: true });

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

exports.onChallengeCreated = functions.firestore
  .document('challenges/{challengeId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;
    const opponentUid = data.opponentUid;
    const creatorName = data.creatorName || 'Un ami';
    const typeLabel = data.type || 'Défi';

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(opponentUid).get();
    const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

    if (!fcmToken) return null;

    const message = {
      token: fcmToken,
      notification: {
        title: '⚔️ Nouveau Duel Reçu !',
        body: `${creatorName} vous défie sur une épreuve de ${typeLabel} ! Acceptez-vous ?`,
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        challengeId: context.params.challengeId,
        type: 'challenge_received',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'nutrizen_social_channel'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default'
          }
        }
      }
    };

    try {
      await admin.messaging().send(message);
    } catch (err) {
      console.error('Erreur envoi notification FCM:', err);
      if (err.code === 'messaging/invalid-registration-token' ||
        err.code === 'messaging/registration-token-not-registered') {
        await db.collection('users').doc(opponentUid).update({
          fcmToken: admin.firestore.FieldValue.delete()
        });
      }
    }
    return null;
  });

exports.onChallengeStatusUpdated = functions.firestore
  .document('challenges/{challengeId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) return null;

    if (before.status === 'pending' && after.status === 'active') {
      const creatorUid = after.creatorUid;
      const opponentName = after.opponentName || 'Votre ami';

      const db = admin.firestore();
      const userDoc = await db.collection('users').doc(creatorUid).get();
      const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

      if (!fcmToken) return null;

      const message = {
        token: fcmToken,
        notification: {
          title: '🔥 Duel Accepté !',
          body: `${opponentName} a accepté votre défi. Que le meilleur gagne !`,
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'nutrizen_social_channel'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default'
            }
          }
        }
      };

      try {
        await admin.messaging().send(message);
      } catch (err) {
        console.error('Erreur envoi FCM acceptation:', err);
        if (err.code === 'messaging/invalid-registration-token' ||
          err.code === 'messaging/registration-token-not-registered') {
          await db.collection('users').doc(creatorUid).update({
            fcmToken: admin.firestore.FieldValue.delete()
          });
        }
      }
    }
    return null;
  });