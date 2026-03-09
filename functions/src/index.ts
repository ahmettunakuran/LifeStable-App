import { setGlobalOptions } from "firebase-functions/v2";
import { auth } from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

setGlobalOptions({
    maxInstances: 10,
    region: "us-central1"
});

export const onCreateUser = auth.user().onCreate(async (user) => {
    const userId = user.uid;
    const userEmail = user.email || "No email provided";

    logger.info(`New user registration: ${userId}`);

    try {
        await admin.firestore().collection("users").doc(userId).set({
            email: userEmail,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            points: 0,
            level: 1,
            habitStreak: 0,
            isProfileCompleted: false,
            role: "user"
        });
        logger.info(`User profile successfully created for: ${userId}`);
    } catch (error) {
        logger.error("Firestore Error:", error);
    }
});
