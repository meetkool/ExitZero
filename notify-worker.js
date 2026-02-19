// /**
//  * 📱 Android Notification Worker (via ntfy.sh)
//  *
//  * Setup (one-time):
//  *   1. Install the "ntfy" app on your Android phone
//  *   2. Subscribe to your chosen topic (e.g. "my-secret-topic-123")
//  *   3. Set TOPIC below to match
//  *
//  * Usage:
//  *   node notify-worker.js
//  *   node notify-worker.js "Custom message here"
//  */

// // Fixed topic as per plan
// const TOPIC = "exitzero-notifications-worker";
// const SERVER = "https://ntfy.sh";

// async function sendNotification({ title = "Worker Alert", message = "Hello from your JS worker!", priority = "default", tags = [] } = {}) {
//     const response = await fetch(`${SERVER}/${TOPIC}`, {
//         method: "POST",
//         headers: {
//             "Title": title,
//             "Priority": priority,        // min | low | default | high | urgent
//             "Tags": tags.join(","),  // emoji tags, e.g. ["warning", "robot"]
//             "Content-Type": "text/plain",
//         },
//         body: message,
//     });

//     if (!response.ok) {
//         throw new Error(`Failed to send notification: ${response.status} ${response.statusText}`);
//     }

//     const data = await response.json();
//     console.log(`✅ Notification sent! ID: ${data.id}`);
//     return data;
// }

// // ─── Example: scheduled worker loop ────────────────────────────────────────
// async function workerLoop() {
//     console.log(`🚀 Worker started — sending to topic: "${TOPIC}"`);
//     console.log(`👉 Subscribe to this topic in the ntfy app to receive notifications!`);

//     // Send an immediate startup notification
//     await sendNotification({
//         title: "Worker Started",
//         message: process.argv[2] || "Your JS worker is now running!",
//         priority: "high",
//         tags: ["robot", "white_check_mark"],
//     });

//     // Example: send a heartbeat every 60 seconds
//     setInterval(async () => {
//         await sendNotification({
//             title: "Heartbeat",
//             message: `Still alive — ${new Date().toLocaleTimeString()}`,
//             tags: ["heartbeat"],
//         });
//     }, 60_000);
// }

// workerLoop().catch((err) => {
//     console.error("❌ Worker error:", err.message);
//     process.exit(1);
// });


/**
 * 📱 Android Notification Worker (via ntfy.sh)
 */

// Fixed topic as per plan
const TOPIC = "exitzero-notifications-worker";
const SERVER = "https://ntfy.sh";

async function sendNotification({ title = "Worker Alert", message = "Hello from your JS worker!", priority = "default", tags = [] } = {}) {
    const response = await fetch(`${SERVER}/${TOPIC}`, {
        method: "POST",
        headers: {
            "Title": title,
            "Priority": priority,        // min | low | default | high | urgent
            "Tags": tags.join(","),  // emoji tags, e.g. ["warning", "robot"]
            "Content-Type": "text/plain",
        },
        body: message,
    });

    if (!response.ok) {
        throw new Error(`Failed to send notification: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    console.log(`✅ Notification sent! ID: ${data.id}`);
    return data;
}

// ─── Example: scheduled worker loop ────────────────────────────────────────
async function workerLoop() {
    console.log(`🚀 Worker started — sending to topic: "${TOPIC}"`);
    console.log(`👉 Subscribe to this topic in the ntfy app to receive notifications!`);

    // Send an immediate startup notification
    await sendNotification({
        title: "Worker Started",
        message: process.argv[2] || "Your JS worker is now running!",
        priority: "high",
        tags: ["robot", "white_check_mark"],
    });

    // Example: send a heartbeat every 60 seconds
    setInterval(async () => {
        await sendNotification({
            title: "Heartbeat",
            message: `Still alive — ${new Date().toLocaleTimeString()}`,
            tags: ["heartbeat"],
        });
    }, 60_000);
}

workerLoop().catch((err) => {
    console.error("❌ Worker error:", err.message);
    process.exit(1);
});