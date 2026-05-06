export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" })
  }

  const { user, reason, time } = req.body

  if (!user || !reason) {
    return res.status(400).json({ error: "Missing fields" })
  }

  const webhook = process.env.DISCORD_WEBHOOK_URL

  await fetch(webhook, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      username: "Punishment Panel",
      embeds: [
        {
          title: "Новое наказание",
          color: 0xff0000,
          fields: [
            { name: "Игрок", value: user },
            { name: "Причина", value: reason },
            { name: "Время", value: time || "Не указано" }
          ]
        }
      ]
    })
  })

  res.status(200).json({ ok: true })
}
