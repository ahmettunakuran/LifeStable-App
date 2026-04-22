import { setGlobalOptions } from "firebase-functions/v2";
import { auth, https } from "firebase-functions/v1";
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

export const upsertTask = https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new https.HttpsError("unauthenticated", "Authentication required.");
    }

    const uid = context.auth.uid;
    const taskId = data?.taskId as string | undefined;
    const title = data?.title as string | undefined;

    if (!taskId || !title) {
        throw new https.HttpsError("invalid-argument", "taskId and title are required.");
    }

    await admin.firestore()
        .collection("users")
        .doc(uid)
        .collection("tasks")
        .doc(taskId)
        .set({
            domainId: data?.domainId ?? "",
            title,
            description: data?.description ?? "",
            status: data?.status ?? "todo",
            priority: data?.priority ?? "medium",
            dueDate: data?.dueDate ?? null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

    return {success: true};
});

export const deleteTask = https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new https.HttpsError("unauthenticated", "Authentication required.");
    }
    const uid = context.auth.uid;
    const taskId = data?.taskId as string | undefined;
    if (!taskId) {
        throw new https.HttpsError("invalid-argument", "taskId is required.");
    }

    await admin.firestore()
        .collection("users")
        .doc(uid)
        .collection("tasks")
        .doc(taskId)
        .delete();

    return {success: true};
});
export * from "./calendar-sync";