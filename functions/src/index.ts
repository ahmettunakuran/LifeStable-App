import { setGlobalOptions } from "firebase-functions/v2";
import { auth, https, firestore } from "firebase-functions/v1";
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
    } catch (error) {
        logger.error("Firestore Error:", error);
    }
});

export const upsertTask = https.onCall(async (data, context) => {
    if (!context.auth) throw new https.HttpsError("unauthenticated", "Auth required.");
    const uid = context.auth.uid;
    await admin.firestore()
        .collection("users")
        .doc(uid)
        .collection("tasks")
        .doc(data.taskId)
        .set({ ...data, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    return { success: true };
});

export const onTeamTaskWrite = firestore
    .document("teams/{teamId}/tasks/{taskId}")
    .onWrite(async (change, context) => {
        const { teamId, taskId } = context.params;
        logger.info(`Function triggered for team: ${teamId}, task: ${taskId}`);

        const taskData = change.after.exists ? change.after.data() : change.before.data();
        const taskTitle = taskData?.title || "Task";
        const isDeleted = !change.after.exists;
        let action = "updated";
        if (!change.before.exists) action = "created";
        if (isDeleted) action = "deleted";

        // 1. Get all team members
        const membersSnapshot = await admin.firestore()
            .collection("team_members")
            .where("team_id", "==", teamId)
            .get();

        const userIds = membersSnapshot.docs.map(doc => doc.data().user_id);
        logger.info(`Found ${userIds.length} members for team ${teamId}`);

        if (userIds.length === 0) return null;

        // 2. Get FCM tokens and send push notifications
        const userDocs = await Promise.all(
            userIds.map(uid => admin.firestore().collection("users").doc(uid).get())
        );

        const tokens: string[] = [];
        userDocs.forEach(doc => {
            const data = doc.data();
            if (data?.fcmToken) tokens.push(data.fcmToken);
        });

        if (tokens.length > 0) {
            const message: admin.messaging.MulticastMessage = {
                notification: {
                    title: "Team Board Update",
                    body: `Task "${taskTitle}" was ${action} in your team board.`,
                },
                data: { teamId },
                tokens,
            };
            try {
                const resp = await admin.messaging().sendEachForMulticast(message);
                logger.info(`Sent ${resp.successCount} push notifications.`);
            } catch (error) {
                logger.error("Error sending notifications:", error);
            }
        }

        // 3. Auto-sync team task deadline to each member's personal calendar.
        const dueDate: string | undefined = change.after.exists
            ? change.after.data()?.dueDate
            : undefined;

        const calEventId = `team_task_${teamId}_${taskId}`;

        const calendarOps = userIds.map(async uid => {
            const calRef = admin.firestore()
                .collection("users").doc(uid)
                .collection("calendar_events").doc(calEventId);

            if (isDeleted) {
                await calRef.delete().catch(() => null);
                return;
            }

            if (!dueDate) {
                await calRef.delete().catch(() => null);
                return;
            }

            const startAt = new Date(dueDate);
            const endAt = new Date(startAt.getTime() + 60 * 60 * 1000);

            await calRef.set({
                userId: uid,
                title: `[Team] ${taskTitle}`,
                description: `Due date synced from team board (${teamId}).`,
                startAt: startAt.toISOString(),
                endAt: endAt.toISOString(),
                eventType: "team",
                teamId,
                teamName: null,
                assignedMemberIds: [],
                isRecurring: false,
            }, { merge: true });
        });

        await Promise.all(calendarOps);
        logger.info(`Calendar sync complete for task ${taskId}.`);
        return null;
    });

export const deleteTask = https.onCall(async (data, context) => {
    if (!context.auth) throw new https.HttpsError("unauthenticated", "Auth required.");
    await admin.firestore().collection("users").doc(context.auth.uid).collection("tasks").doc(data.taskId).delete();
    return { success: true };
});
export * from "./calendar-sync";