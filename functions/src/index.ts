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

export const onTeamMemberCreate = firestore
    .document("team_members/{docId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const teamId = data.team_id;
        const newUserId = data.user_id;

        if (!teamId) return null;

        // 1. Get team name
        const teamDoc = await admin.firestore().collection("teams").doc(teamId).get();
        const teamName = teamDoc.data()?.name || "a team";

        // 2. Get new user name
        const newUserDoc = await admin.firestore().collection("users").doc(newUserId).get();
        const newUserName = newUserDoc.data()?.name || "A new member";

        // 3. Get all other team members to notify them
        const membersSnapshot = await admin.firestore()
            .collection("team_members")
            .where("team_id", "==", teamId)
            .get();

        const tokens: string[] = [];
        for (const doc of membersSnapshot.docs) {
            const mData = doc.data();
            if (mData.user_id === newUserId) continue; // Don't notify the person who just joined

            const userDoc = await admin.firestore().collection("users").doc(mData.user_id).get();
            const fcmToken = userDoc.data()?.fcmToken;
            if (fcmToken) tokens.push(fcmToken);
        }

        if (tokens.length > 0) {
            const message: admin.messaging.MulticastMessage = {
                notification: {
                    title: "New Team Member!",
                    body: `${newUserName} has joined "${teamName}".`,
                },
                data: { teamId, type: "member_joined" },
                tokens,
            };
            await admin.messaging().sendEachForMulticast(message);
        }
        return null;
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

        // Get all team members
        const membersSnapshot = await admin.firestore()
            .collection("team_members")
            .where("team_id", "==", teamId)
            .get();

        const userIds = membersSnapshot.docs.map(doc => doc.data().user_id);
        
        if (userIds.length === 0) return null;

        // Get tokens
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
                    title: "Team Update",
                    body: `"${taskTitle}" was ${action}.`,
                },
                data: { teamId, taskId, type: "task_update" },
                tokens,
            };
            try {
                await admin.messaging().sendEachForMulticast(message);
            } catch (error) {
                logger.error("Error sending notifications:", error);
            }
        }

        // Calendar Sync logic...
        const dueDate: string | undefined = change.after.exists
            ? change.after.data()?.dueDate
            : undefined;

        const calEventId = `team_task_${teamId}_${taskId}`;

        const calendarOps = userIds.map(async uid => {
            const calRef = admin.firestore()
                .collection("users").doc(uid)
                .collection("calendar_events").doc(calEventId);

            if (isDeleted || !dueDate) {
                await calRef.delete().catch(() => null);
                return;
            }

            const startAt = new Date(dueDate);
            const endAt = new Date(startAt.getTime() + 60 * 60 * 1000);

            await calRef.set({
                userId: uid,
                title: `[Team] ${taskTitle}`,
                description: `Due date synced from team board.`,
                startAt: startAt.toISOString(),
                endAt: endAt.toISOString(),
                eventType: "team",
                teamId,
                isRecurring: false,
            }, { merge: true });
        });

        await Promise.all(calendarOps);
        return null;
    });

export const deleteTask = https.onCall(async (data, context) => {
    if (!context.auth) throw new https.HttpsError("unauthenticated", "Auth required.");
    await admin.firestore().collection("users").doc(context.auth.uid).collection("tasks").doc(data.taskId).delete();
    return { success: true };
});
export * from "./calendar-sync";
export * from "./rag";