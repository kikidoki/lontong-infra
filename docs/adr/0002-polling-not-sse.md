# 0002: pseudo-real-time by conditional polling, not SSE
API Gateway REST APIs gained response streaming in Nov 2025, so SSE is possible, but each open tab pins a Lambda for the whole
connection: 3 admins x 10 h/day at 512 MB is about 54k GB-s/day, ~1.1M GB-s per three-week season versus 400k free (~$10-12, growing with
every extra tab). Polling a Redis version key (ETag/304) is one command and zero SQL per poll, bounded by construction.
Mutations return the fresh totals, so the editing admin never waits for a poll.
