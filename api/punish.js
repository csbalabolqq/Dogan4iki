export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { from, user, reason, time, advice } = req.body;

  if (!from || !user || !reason) {
    return res.status(400).json({ error: "Missing fields" });
  }

  const webhook = process.env.DISCORD_WEBHOOK_URL;

  await fetch(webhook, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      username: "Punishment Panel",
      embeds: [
        {
          title: "Нове покарання",
          color: 0xff0000,
          fields: [
            { name: "Від кого", value: from, inline: false },
            { name: "Кому", value: user, inline: false },
            { name: "Причина", value: reason, inline: false },
            { name: "Час", value: time || "Не вказано", inline: false },
            { name: "Порада", value: advice || "Не вказано", inline: false }
          ],
          timestamp: new Date().toISOString()
        }
      ]
    })
  });

  res.status(200).json({ ok: true });
}
