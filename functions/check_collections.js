const admin = require('firebase-admin');
admin.initializeApp({
  projectId: 'erpcomp-6ae45'
});
const db = admin.firestore();

async function run() {
  try {
    const companies = await db.collection('companies').get();
    console.log("Companies count:", companies.size);
    for (const doc of companies.docs) {
      console.log("Company ID:", doc.id, "Data:", doc.data());
      const subcollections = await doc.ref.listCollections();
      console.log("Subcollections for company", doc.id, ":", subcollections.map(c => c.id));
    }
  } catch (err) {
    console.error("Error fetching database collections:", err);
  }
}

run();
