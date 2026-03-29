import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
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

/** Push to teammates when a row on the team Kanban (`teams/{teamId}/tasks`) changes. */
export const onTeamBoardTaskWrite = onDocumentWritten(
    {
        document: "teams/{teamId}/tasks/{taskId}",
        region: "europe-west1",
    },
    async (event) => {
        const change = event.data;
        if (!change) {
            return;
        }

        const teamId = event.params.teamId as string;
        const before = change.before.exists ? change.before.data() : undefined;
        const after = change.after.exists ? change.after.data() : undefined;

        const actorUid = (after?.lastUpdatedBy ?? before?.lastUpdatedBy) as string | undefined;

        const teamSnap = await admin.firestore().collection("teams").doc(teamId).get();
        const teamName = (teamSnap.data()?.name as string | undefined) ?? "Team";

        let title = "Board updated";
        let body = `Tasks were updated on ${teamName}.`;

        if (after && !before) {
            title = "New team task";
            body = `${String(after.title ?? "Task")} added to ${teamName}.`;
        } else if (!after && before) {
            title = "Task removed";
            body = `${String(before.title ?? "A task")} removed from ${teamName}.`;
        } else if (after && before) {
            const taskTitle = String(after.title ?? "A task");
            if (after.status !== before.status) {
                title = "Task moved";
                body = `${taskTitle} → ${String(after.status)} on ${teamName}.`;
            } else {
                title = "Task updated";
                body = `${taskTitle} updated on ${teamName}.`;
            }
        }

        const membersSnap = await admin.firestore()
            .collection("team_members")
            .where("team_id", "==", teamId)
            .get();

        const tokens = new Set<string>();
        for (const m of membersSnap.docs) {
            const userId = m.data().user_id as string | undefined;
            if (!userId || userId === actorUid) {
                continue;
            }
            const userDoc = await admin.firestore().collection("users").doc(userId).get();
            const arr = userDoc.data()?.fcmTokens;
            if (Array.isArray(arr)) {
                for (const t of arr) {
                    if (typeof t === "string" && t.length > 0) {
                        tokens.add(t);
                    }
                }
            }
        }

        const tokenList = [...tokens];
        if (tokenList.length === 0) {
            return;
        }

        const chunk = 500;
        for (let i = 0; i < tokenList.length; i += chunk) {
            const batch = tokenList.slice(i, i + chunk);
            try {
                const resp = await admin.messaging().sendEachForMulticast({
                    tokens: batch,
                    notification: { title, body },
                    data: {
                        teamId,
                        type: "team_board_update",
                    },
                });
                if (resp.failureCount > 0) {
                    logger.warn("FCM partial failure", {
                        failureCount: resp.failureCount,
                        teamId,
                    });
                }
            } catch (e) {
                logger.error("FCM send failed", e);
            }
        }
    },
);
