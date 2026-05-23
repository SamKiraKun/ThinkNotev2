import admin from "firebase-admin";

let initialized = false;

export function firebaseAuth(): admin.auth.Auth {
  if (!initialized) {
    admin.initializeApp({
      credential: buildCredential(),
      projectId: process.env.FIREBASE_PROJECT_ID,
      databaseURL: process.env.FIREBASE_DATABASE_URL,
      storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
    });
    initialized = true;
  }

  return admin.auth();
}

function buildCredential(): admin.credential.Credential {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson) {
    return admin.credential.cert(JSON.parse(serviceAccountJson));
  }

  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");
  const projectId = process.env.FIREBASE_PROJECT_ID;

  if (clientEmail && privateKey && projectId) {
    return admin.credential.cert({
      projectId,
      clientEmail,
      privateKey,
    });
  }

  return admin.credential.applicationDefault();
}
