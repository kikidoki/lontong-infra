# 0004: WhatsApp: manual wa.me now; official Cloud API (not Baileys) if automation is ever added
Baileys is an unofficial WhatsApp Web client: ban risk and it needs an always-on process, which does not fit Lambda and breaks the
near-zero-cost goal. The official Cloud API works from Lambda + SQS. Note that the "1,000 free messages" are *service* messages
(replies inside a 24h window); proactive status updates are paid utility templates. Real usage therefore stays on free wa.me links.
Details and the full plan: lontong-stack `apps/api/docs/TODO_WHATSAPP_CLOUD_API.md`. Infra seam: the commented block in `environments/*/main.tf`.
