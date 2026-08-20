const admin = require('firebase-admin');
admin.initializeApp({
  projectId: 'erpcomp-6ae45'
});
const db = admin.firestore();

async function run() {
  try {
    const companies = await db.collection('companies').get();
    for (const companyDoc of companies.docs) {
      console.log("====================================");
      console.log("Company ID:", companyDoc.id);
      const tasks = await companyDoc.ref.collection('tasks').get();
      console.log("Tasks count:", tasks.size);
      for (const doc of tasks.docs) {
        const data = doc.data();
        console.log("Task ID:", doc.id);
        console.log("Title:", data.title);
        console.log("Status:", data.status);
        console.log("assignedToEmployeeId:", data.assignedToEmployeeId);
        console.log("assignedToUid:", data.assignedToUid);
        console.log("taskStartTime:", data.taskStartTime ? (data.taskStartTime.toDate ? data.taskStartTime.toDate().toISOString() : data.taskStartTime) : null);
        console.log("deadlineTime:", data.deadlineTime ? (data.deadlineTime.toDate ? data.deadlineTime.toDate().toISOString() : data.deadlineTime) : null);
        console.log("dueDate:", data.dueDate ? (data.dueDate.toDate ? data.dueDate.toDate().toISOString() : data.dueDate) : null);
        console.log("actualCompletionTime:", data.actualCompletionTime ? (data.actualCompletionTime.toDate ? data.actualCompletionTime.toDate().toISOString() : data.actualCompletionTime) : null);
        console.log("completionTiming:", data.completionTiming);
        console.log("totalTimeTakenMinutes:", data.totalTimeTakenMinutes);
        console.log("lateDurationMinutes:", data.lateDurationMinutes);
        console.log("performanceScore:", data.performanceScore);
        console.log("performanceRating:", data.performanceRating);
        console.log("------------------------------------");
      }
    }
  } catch (err) {
    console.error("Error fetching tasks:", err);
  }
}

run();
