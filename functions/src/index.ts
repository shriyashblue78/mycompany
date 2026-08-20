import { setGlobalOptions } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentUpdated, onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// Set global options for cost control
setGlobalOptions({ maxInstances: 10 });

// Helper to declare global fetch to prevent TypeScript compilation errors in node envs
declare const fetch: any;

/**
 * Helper to fetch a caller's user profile from Firestore.
 */
async function getCallerProfile(uid: string): Promise<admin.firestore.DocumentData | undefined> {
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists) {
    throw new HttpsError("permission-denied", "Caller profile not found in Firestore.");
  }
  return doc.data();
}

/**
 * createOwner
 * Super Admin-only function to create a company owner account, Firestore user profile,
 * and standard owner employee record.
 */
export const createOwner = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerProfile = await getCallerProfile(request.auth.uid);
  if (callerProfile?.role !== "super_admin") {
    throw new HttpsError("permission-denied", "Only super_admin can create owners.");
  }

  const { companyId, ownerName, ownerEmail, ownerPhone, temporaryPassword } = request.data;

  if (!companyId || !ownerName || !ownerEmail || !ownerPhone || !temporaryPassword) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  try {
    // Create Firebase Auth user
    const userRecord = await admin.auth().createUser({
      email: ownerEmail,
      password: temporaryPassword,
      displayName: ownerName,
    });

    const uid = userRecord.uid;
    const nowIso = new Date().toISOString();

    const batch = db.batch();

    // Update companies/{companyId} with owner details
    const companyRef = db.collection("companies").doc(companyId);
    batch.set(companyRef, {
      ownerUid: uid,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      ownerPhone: ownerPhone,
      ownerStatus: "Active",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Create users/{uid}
    const userRef = db.collection("users").doc(uid);
    batch.set(userRef, {
      uid: uid,
      companyId: companyId,
      employeeId: "EMP0001",
      name: ownerName,
      email: ownerEmail,
      phone: ownerPhone,
      role: "Owner",
      department: "Management",
      designation: "Owner",
      status: "Active",
      joiningDate: nowIso,
      createdAt: nowIso,
      updatedAt: nowIso,
    });

    // Create companies/{companyId}/employees/EMP0001
    const employeeRef = companyRef.collection("employees").doc("EMP0001");
    batch.set(employeeRef, {
      employeeId: "EMP0001",
      uid: uid,
      companyId: companyId,
      name: ownerName,
      email: ownerEmail,
      phone: ownerPhone,
      role: "Owner",
      department: "Management",
      designation: "Owner",
      status: "Active",
      joiningDate: nowIso,
      createdAt: nowIso,
      updatedAt: nowIso,
    });

    await batch.commit();

    logger.info("Owner created successfully", {
      actorUid: request.auth.uid,
      actorRole: callerProfile.role,
      companyId: companyId,
      targetUid: uid,
      targetRole: "Owner",
      timestamp: nowIso,
    });

    return { uid, employeeId: "EMP0001" };
  } catch (error: any) {
    logger.error("Error creating owner", error);
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "The email address is already in use by another account.");
    }
    if (error.code === "auth/invalid-password" || error.code === "auth/weak-password") {
      throw new HttpsError("invalid-argument", "The password must be at least 6 characters long.");
    }
    throw new HttpsError("internal", error.message || "Failed to create owner.");
  }
});

/**
 * createEmployee
 * Creates a new employee user account and generates sequential employee ID transactionally.
 */
export const createEmployee = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerProfile = await getCallerProfile(request.auth.uid);
  const isSuperAdmin = callerProfile?.role === "super_admin";
  const { companyId, name, email, phone, role, department, designation, temporaryPassword } = request.data;

  if (!companyId || !name || !email || !phone || !role || !department || !designation || !temporaryPassword) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  if (!isSuperAdmin) {
    if (callerProfile?.companyId !== companyId) {
      throw new HttpsError("permission-denied", "You can only create employees for your own company.");
    }
    if (callerProfile?.role !== "Owner" && callerProfile?.role !== "HR" && callerProfile?.role !== "Supervisor") {
      throw new HttpsError("permission-denied", "Insufficient permissions to create employee.");
    }
  }

  try {
    const companyRef = db.collection("companies").doc(companyId);

    // Run transaction to get next unique Employee ID
    const employeeId = await db.runTransaction(async (transaction) => {
      const companyDoc = await transaction.get(companyRef);
      if (!companyDoc.exists) {
        throw new Error("COMPANY_NOT_FOUND");
      }

      const companyData = companyDoc.data();
      // If lastEmployeeCounter doesn't exist, start with 2 (as EMP0001 is reserved for Owner)
      const currentCounter = companyData?.lastEmployeeCounter || 1;
      const nextCounter = currentCounter + 1;

      transaction.update(companyRef, { lastEmployeeCounter: nextCounter });

      // Generate Padded Code e.g. EMP0002
      return "EMP" + String(nextCounter).padStart(4, "0");
    });

    // Create Firebase Auth user
    const userRecord = await admin.auth().createUser({
      email: email,
      password: temporaryPassword,
      displayName: name,
    });

    const uid = userRecord.uid;
    const nowIso = new Date().toISOString();

    const batch = db.batch();

    // Create users/{uid}
    const userRef = db.collection("users").doc(uid);
    batch.set(userRef, {
      uid: uid,
      companyId: companyId,
      employeeId: employeeId,
      name: name,
      email: email,
      phone: phone,
      role: role,
      department: department,
      designation: designation,
      status: "Active",
      joiningDate: nowIso,
      createdAt: nowIso,
      updatedAt: nowIso,
    });

    // Create companies/{companyId}/employees/{employeeId}
    const employeeRef = companyRef.collection("employees").doc(employeeId);
    batch.set(employeeRef, {
      employeeId: employeeId,
      uid: uid,
      companyId: companyId,
      name: name,
      email: email,
      phone: phone,
      role: role,
      department: department,
      designation: designation,
      status: "Active",
      joiningDate: nowIso,
      createdAt: nowIso,
      updatedAt: nowIso,
    });

    await batch.commit();

    logger.info("Employee created successfully", {
      actorUid: request.auth.uid,
      actorRole: callerProfile.role,
      companyId: companyId,
      targetUid: uid,
      targetRole: role,
      timestamp: nowIso,
    });

    return { uid, employeeId };
  } catch (error: any) {
    logger.error("Error creating employee", error);
    if (error.message === "COMPANY_NOT_FOUND") {
      throw new HttpsError("not-found", "The specified company was not found.");
    }
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "The email address is already in use by another account.");
    }
    if (error.code === "auth/invalid-password" || error.code === "auth/weak-password") {
      throw new HttpsError("invalid-argument", "The password must be at least 6 characters long.");
    }
    throw new HttpsError("internal", error.message || "Failed to create employee.");
  }
});

/**
 * updateUser
 * Updates name, phone, department, designation, status, and role for a user.
 * Blocks UID/Company modifications, and restricts regular users from changing administrative fields.
 */
export const updateUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerUid = request.auth.uid;
  const callerProfile = await getCallerProfile(callerUid);
  const isSuperAdmin = callerProfile?.role === "super_admin";

  const { uid, companyId, employeeId, name, phone, department, designation, status, role } = request.data;

  if (!uid || !companyId || !employeeId) {
    throw new HttpsError("invalid-argument", "Missing target identifiers (uid, companyId, employeeId).");
  }

  const userRef = db.collection("users").doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "Target user profile not found.");
  }

  const userData = userDoc.data();
  if (userData?.companyId !== companyId || userData?.employeeId !== employeeId) {
    throw new HttpsError("invalid-argument", "Target user companyId or employeeId mismatch.");
  }

  const isSelf = callerUid === uid;
  const isCompanyAdmin = callerProfile?.companyId === companyId && (callerProfile?.role === "Owner" || callerProfile?.role === "HR");

  if (!isSuperAdmin && !isCompanyAdmin && !isSelf) {
    throw new HttpsError("permission-denied", "You do not have permission to update this user.");
  }

  // Prevent regular employees from elevating their own roles or changing their own status/department/designation
  if (isSelf && !isSuperAdmin && !isCompanyAdmin) {
    if (role !== userData?.role || status !== userData?.status || department !== userData?.department || designation !== userData?.designation) {
      throw new HttpsError("permission-denied", "Employees are not allowed to update their own administrative fields.");
    }
  }

  try {
    // Update display name in Firebase Auth
    await admin.auth().updateUser(uid, {
      displayName: name,
    });

    const nowIso = new Date().toISOString();
    const batch = db.batch();

    // Update users/{uid}
    batch.update(userRef, {
      name: name,
      phone: phone,
      department: department,
      designation: designation,
      status: status,
      role: role,
      updatedAt: nowIso,
    });

    // Update companies/{companyId}/employees/{employeeId}
    const employeeRef = db.collection("companies").doc(companyId).collection("employees").doc(employeeId);
    batch.update(employeeRef, {
      name: name,
      phone: phone,
      department: department,
      designation: designation,
      status: status,
      role: role,
      updatedAt: nowIso,
    });

    // Sync with company document if editing the main Owner
    if (employeeId === "EMP0001") {
      const companyRef = db.collection("companies").doc(companyId);
      batch.update(companyRef, {
        ownerName: name,
        ownerPhone: phone,
        ownerStatus: status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    logger.info("User updated successfully", {
      actorUid: callerUid,
      actorRole: callerProfile?.role,
      companyId: companyId,
      targetUid: uid,
      targetRole: role,
      timestamp: nowIso,
    });

    return { success: true };
  } catch (error: any) {
    logger.error("Error updating user", error);
    throw new HttpsError("internal", error.message || "Failed to update user.");
  }
});

/**
 * disableUser
 * Suspends user login in Auth and updates Firestore status to 'Suspended'.
 */
export const disableUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerUid = request.auth.uid;
  const callerProfile = await getCallerProfile(callerUid);
  const isSuperAdmin = callerProfile?.role === "super_admin";

  const { uid, companyId, employeeId } = request.data;

  if (!uid || !companyId || !employeeId) {
    throw new HttpsError("invalid-argument", "Missing required target fields (uid, companyId, employeeId).");
  }

  const isCompanyAdmin = callerProfile?.companyId === companyId && (callerProfile?.role === "Owner" || callerProfile?.role === "HR");
  if (!isSuperAdmin && !isCompanyAdmin) {
    throw new HttpsError("permission-denied", "Only Owners or HR administrators can disable users.");
  }

  try {
    await admin.auth().updateUser(uid, { disabled: true });

    const nowIso = new Date().toISOString();
    const batch = db.batch();

    batch.update(db.collection("users").doc(uid), {
      status: "Suspended",
      updatedAt: nowIso,
    });

    batch.update(db.collection("companies").doc(companyId).collection("employees").doc(employeeId), {
      status: "Suspended",
      updatedAt: nowIso,
    });

    if (employeeId === "EMP0001") {
      batch.update(db.collection("companies").doc(companyId), {
        ownerStatus: "Suspended",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    logger.info("User disabled successfully", {
      actorUid: callerUid,
      actorRole: callerProfile?.role,
      companyId: companyId,
      targetUid: uid,
      timestamp: nowIso,
    });

    return { success: true };
  } catch (error: any) {
    logger.error("Error disabling user", error);
    throw new HttpsError("internal", error.message || "Failed to disable user.");
  }
});

/**
 * enableUser
 * Activates user login in Auth and updates Firestore status to 'Active'.
 */
export const enableUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerUid = request.auth.uid;
  const callerProfile = await getCallerProfile(callerUid);
  const isSuperAdmin = callerProfile?.role === "super_admin";

  const { uid, companyId, employeeId } = request.data;

  if (!uid || !companyId || !employeeId) {
    throw new HttpsError("invalid-argument", "Missing required target fields (uid, companyId, employeeId).");
  }

  const isCompanyAdmin = callerProfile?.companyId === companyId && (callerProfile?.role === "Owner" || callerProfile?.role === "HR");
  if (!isSuperAdmin && !isCompanyAdmin) {
    throw new HttpsError("permission-denied", "Only Owners or HR administrators can enable users.");
  }

  try {
    await admin.auth().updateUser(uid, { disabled: false });

    const nowIso = new Date().toISOString();
    const batch = db.batch();

    batch.update(db.collection("users").doc(uid), {
      status: "Active",
      updatedAt: nowIso,
    });

    batch.update(db.collection("companies").doc(companyId).collection("employees").doc(employeeId), {
      status: "Active",
      updatedAt: nowIso,
    });

    if (employeeId === "EMP0001") {
      batch.update(db.collection("companies").doc(companyId), {
        ownerStatus: "Active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    logger.info("User enabled successfully", {
      actorUid: callerUid,
      actorRole: callerProfile?.role,
      companyId: companyId,
      targetUid: uid,
      timestamp: nowIso,
    });

    return { success: true };
  } catch (error: any) {
    logger.error("Error enabling user", error);
    throw new HttpsError("internal", error.message || "Failed to enable user.");
  }
});

/**
 * resetUserPassword
 * Triggers standard Firebase password reset email via Identity Toolkit REST API.
 */
export const resetUserPassword = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerUid = request.auth.uid;
  const callerProfile = await getCallerProfile(callerUid);
  const isSuperAdmin = callerProfile?.role === "super_admin";

  const { email } = request.data;
  if (!email) {
    throw new HttpsError("invalid-argument", "Missing required field: email.");
  }

  const usersSnap = await db.collection("users").where("email", "==", email).limit(1).get();
  if (usersSnap.empty) {
    throw new HttpsError("not-found", "No user profile found with that email address.");
  }

  const targetUserDoc = usersSnap.docs[0];
  const targetUserData = targetUserDoc.data();
  const targetUid = targetUserDoc.id;
  const targetCompanyId = targetUserData?.companyId;

  const isSelf = callerUid === targetUid;
  const isCompanyAdmin = callerProfile?.companyId === targetCompanyId && (callerProfile?.role === "Owner" || callerProfile?.role === "HR");

  if (!isSuperAdmin && !isCompanyAdmin && !isSelf) {
    throw new HttpsError("permission-denied", "Insufficient permissions to reset password for this user.");
  }

  try {
    const apiKey = "AIzaSyAC40uAPOJuvHyQZhmO-g5k0bXSElM9m7M";
    const url = `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${apiKey}`;

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        requestType: "PASSWORD_RESET",
        email: email,
      }),
    });

    if (!response.ok) {
      const errData: any = await response.json();
      const errCode = errData?.error?.message || "REST_API_ERROR";
      if (errCode === "EMAIL_NOT_FOUND") {
        throw new HttpsError("not-found", "The email address is not registered in Authentication.");
      }
      throw new Error(errCode);
    }

    logger.info("Password reset email sent successfully", {
      actorUid: callerUid,
      actorRole: callerProfile?.role,
      targetEmail: email,
      timestamp: new Date().toISOString(),
    });

    return { success: true };
  } catch (error: any) {
    logger.error("Error in resetUserPassword", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message || "Failed to trigger password reset email.");
  }
});

/**
 * onTaskUpdated
 * Firestore trigger to detect task completion, automatically calculate performance score & rating,
 * and create/update employee performance history record idempotently.
 */
export const onTaskUpdated = onDocumentUpdated("companies/{companyId}/tasks/{taskId}", async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!beforeData || !afterData) {
    logger.info("No data found for document change");
    return;
  }

  // Detect status change to Completed
  if (beforeData.status !== "Completed" && afterData.status === "Completed") {
    const companyId = event.params.companyId;
    const taskId = event.params.taskId;
    const employeeId = afterData.assignedToEmployeeId;

    if (!companyId || !employeeId) {
      logger.error("Missing companyId or employeeId on task completion trigger", { companyId, employeeId });
      return;
    }

    try {
      // 1. Fetch company settings
      const companyDoc = await db.collection("companies").doc(companyId).get();
      let performanceDeduction = 1;
      if (companyDoc.exists) {
        const companyData = companyDoc.data();
        if (companyData && typeof companyData.performanceDeductionPerMinute === "number") {
          performanceDeduction = companyData.performanceDeductionPerMinute;
        }
      }

      // 2. Parse timestamps securely (do not trust UI values)
      const getTimestampDate = (val: any): Date | null => {
        if (!val) return null;
        if (val.toDate && typeof val.toDate === "function") return val.toDate();
        const parsed = Date.parse(val);
        return isNaN(parsed) ? null : new Date(parsed);
      };

      const actualCompletionTime = getTimestampDate(afterData.actualCompletionTime) || new Date();
      const taskStartTime = getTimestampDate(afterData.taskStartTime) || getTimestampDate(afterData.startDate);
      const deadlineTime = getTimestampDate(afterData.deadlineTime) || getTimestampDate(afterData.dueDate);

      if (!taskStartTime || !deadlineTime) {
        logger.error("Missing critical timing data for performance calculation", {
          taskId,
          taskStartTime,
          deadlineTime,
          startDate: afterData.startDate,
          dueDate: afterData.dueDate,
        });
        return;
      }

      // 3. Calculate timing and durations
      const totalTimeTakenMinutes = Math.max(0, Math.round((actualCompletionTime.getTime() - taskStartTime.getTime()) / 60000));
      const isPastDeadline = actualCompletionTime.getTime() > deadlineTime.getTime();
      
      let completionTiming: "Early" | "On Time" | "Late" = "On Time";
      let lateDurationMinutes = 0;

      if (isPastDeadline) {
        completionTiming = "Late";
        lateDurationMinutes = Math.max(0, Math.round((actualCompletionTime.getTime() - deadlineTime.getTime()) / 60000));
      } else {
        const isEarly = actualCompletionTime.getTime() < deadlineTime.getTime();
        completionTiming = isEarly ? "Early" : "On Time";
      }

      // 4. Calculate score & rating
      let score = 0;
      let rating = "";

      if (completionTiming === "Early") {
        score = 100;
        rating = "Excellent";
      } else if (completionTiming === "On Time") {
        score = 90;
        rating = "Very Good";
      } else if (completionTiming === "Late") {
        let baseScore = 80;
        if (lateDurationMinutes >= 15) {
          baseScore = 50;
        }
        score = baseScore - (lateDurationMinutes * performanceDeduction);
        if (score < 0) score = 0;
        if (score > 100) score = 100;

        if (score >= 70) {
          rating = "Good";
        } else if (score >= 50) {
          rating = "Average";
        } else {
          rating = "Poor";
        }
      }

      // 5. Update task document & write performance history in a batch
      const batch = db.batch();

      const taskRef = db.collection("companies").doc(companyId).collection("tasks").doc(taskId);
      batch.update(taskRef, {
        actualCompletionTime: admin.firestore.Timestamp.fromDate(actualCompletionTime),
        totalTimeTakenMinutes: totalTimeTakenMinutes,
        completionTiming: completionTiming,
        lateDurationMinutes: lateDurationMinutes,
        performanceScore: score,
        performanceRating: rating,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Calculate estimated completion time
      let estimatedCompletionTimeStr = "";
      if (afterData.estimatedDurationMinutes) {
        const estDate = new Date(taskStartTime.getTime() + afterData.estimatedDurationMinutes * 60000);
        estimatedCompletionTimeStr = estDate.toISOString();
      }

      const historyRef = db
        .collection("companies")
        .doc(companyId)
        .collection("employees")
        .doc(employeeId)
        .collection("performanceHistory")
        .doc(taskId);

      const historyRecord = {
        taskId: taskId,
        taskName: afterData.title || "",
        machine: afterData.machineName || "",
        department: afterData.department || "",
        assignedDate: afterData.startDate || "",
        startDate: admin.firestore.Timestamp.fromDate(taskStartTime),
        estimatedCompletionTime: estimatedCompletionTimeStr || admin.firestore.Timestamp.fromDate(deadlineTime),
        allowedTime: afterData.allowedDurationMinutes || 0,
        actualCompletionTime: admin.firestore.Timestamp.fromDate(actualCompletionTime),
        totalTimeTaken: totalTimeTakenMinutes,
        completionTiming: completionTiming,
        lateDuration: lateDurationMinutes,
        lateReason: afterData.lateReason || "",
        selectedTooling: afterData.selectedToolNames || [],
        performanceRating: rating,
        performanceScore: score,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      batch.set(historyRef, historyRecord, { merge: true });
      await batch.commit();

      logger.info("Successfully calculated performance score and saved performance history.", {
        companyId,
        employeeId,
        taskId,
        score,
        rating,
        totalTimeTakenMinutes,
        lateDurationMinutes,
        completionTiming,
      });
    } catch (err) {
      logger.error("Error processing task performance update", err);
    }
  }
});

/**
 * onNotificationCreated
 * Firestore trigger to automatically send FCM push notifications to target employees when a notification is created.
 */
export const onNotificationCreated = onDocumentCreated("companies/{companyId}/notifications/{notificationId}", async (event) => {
  const data = event.data?.data();
  if (!data) {
    logger.info("No data found for new notification");
    return;
  }

  const companyId = event.params.companyId;
  const targetType = data.targetType || "Company";
  const targetDepartment = data.targetDepartment;
  const targetEmployeeIds: string[] = data.targetEmployeeIds || [];
  const title = data.title || "New Notification";
  const message = data.message || "";

  let recipientEmployeeIds: string[] = [];

  try {
    if (targetType === "Company") {
      const employeesSnap = await db.collection("companies").doc(companyId).collection("employees").get();
      recipientEmployeeIds = employeesSnap.docs
        .filter(doc => doc.data()?.status === "Active")
        .map(doc => doc.id);
    } else if (targetType === "Department") {
      const employeesSnap = await db.collection("companies").doc(companyId).collection("employees")
        .where("department", "==", targetDepartment).get();
      recipientEmployeeIds = employeesSnap.docs
        .filter(doc => doc.data()?.status === "Active")
        .map(doc => doc.id);
    } else if (targetType === "Employee") {
      recipientEmployeeIds = targetEmployeeIds;
    }

    if (recipientEmployeeIds.length === 0) {
      logger.info("No recipient employee IDs resolved for FCM push.");
      return;
    }

    // Fetch FCM tokens for resolved recipient employees
    const tokens: string[] = [];
    const promises = recipientEmployeeIds.map(async (empId) => {
      const tokensSnap = await db.collection("companies").doc(companyId)
        .collection("employees").doc(empId).collection("fcmTokens").get();
      tokensSnap.forEach((doc) => {
        const token = doc.data()?.token;
        if (token && !tokens.includes(token)) {
          tokens.push(token);
        }
      });
    });

    await Promise.all(promises);

    if (tokens.length === 0) {
      logger.info("No FCM tokens registered for resolved recipient employees.");
      return;
    }

    // Send push notification using admin.messaging()
    const payload = {
      notification: {
        title: title,
        body: message,
      },
      data: {
        type: String(data.type || ""),
        relatedDocumentId: String(data.relatedDocumentId || ""),
        companyId: String(companyId || ""),
        notificationId: String(event.params.notificationId || ""),
      },
      android: {
        priority: "high" as const,
        notification: {
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: message,
            },
            sound: "default",
            badge: 1,
            contentAvailable: true,
          },
        },
      },
      webpush: {
        notification: {
          title: title,
          body: message,
          icon: "/favicon.png",
        },
      },
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(payload);
    logger.info("FCM push sent successfully", {
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  } catch (error) {
    logger.error("Error sending FCM notification", error);
  }
});
