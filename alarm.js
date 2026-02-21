/**
 * 🚨 ExitZero Alarm Trigger 🚨
 *
 * Sends an urgent notification to the ExitZero app via Ntfy.
 * The app will recognize the "alarm" tag and trigger the full-screen alarm experience.
 *
 * Usage:
 *   node alarm.js
 *   node alarm.js "Custom optional message"
 */

const TOPIC = "exitzero-notifications-worker";
const SERVER = "https://ntfy.sh";

async function triggerAlarm() {
    const message = process.argv[2] || "🚨 ALARM SYSTEM TRIGGERED 🚨";

    console.log(`🚀 Sending ALARM to topic: "${TOPIC}"...`);

    const response = await fetch(`${SERVER}/${TOPIC}`, {
        method: "POST",
        headers: {
            "Title": "EXITZERO ALARM",
            "Priority": "urgent",    // Maximum priority
            "Tags": "alarm,rotating_light",  // Tag "alarm" tells the Flutter app to ring
            "Content-Type": "text/plain",
        },
        body: message,
    });

    if (!response.ok) {
        throw new Error(`Failed to send alarm: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    console.log(`✅ Alarm successfully triggered! ID: ${data.id}`);
    console.log(`� Your phone should now be ringing.`);
}

triggerAlarm().catch((err) => {
    console.error("❌ Alarm error:", err.message);
    process.exit(1);
});
