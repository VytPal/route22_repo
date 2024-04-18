/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.createUser = functions.https.onCall((data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('failed-precondition', 'The function must be called ' +
        'while authenticated.');
  }
  return admin.auth().createUser({
    email: data.email,
    password: data.password
  })
  .then(userRecord => {
    console.log('Successfully created new user:', userRecord.uid);
    return { uid: userRecord.uid };
  })
  .catch(error => {
    console.log('Error creating new user:', error);
    throw new functions.https.HttpsError('internal', error.message);
  });
});


exports.deleteUser = functions.https.onCall((data, context) => {
  // Verify if request is made by an authenticated admin
  if (!context.auth) {
    throw new functions.https.HttpsError('permission-denied', 'Must be an administrative user to initiate delete.');
  }

  const uid = data.uid;
  return admin.auth().deleteUser(uid)
    .then(() => {
      return { message: `Successfully deleted user ${uid}` };
    })
    .catch((error) => {
      throw new functions.https.HttpsError('internal', error.message);
    });
});
// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
