---
description: Cold start docker stack on remote-server (shutdown, clear cache, restart)
---

ssh remote-server "cd /haf-pool/syncad/haf_api_node && docker compose down && sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' && cd ~ && sudo zpool export haf-pool && sudo zpool import haf-pool && cd /haf-pool/syncad/haf_api_node && docker compose up -d haf"