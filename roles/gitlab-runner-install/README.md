# register runner
```bash
cd /opt/docker/runner
docker compose run --rm runner-nocache  register  --url https://gitlab.example.com --token glrt-aaaa

docker compose run --rm runner-cache  register  --url https://gitlab.example.com --token glrt-aaaa
```

Need change default created config.toml
use template /opt/runner-nocache/config/config.toml.example
move vars /opt/runner-nocache/config/config.toml
```
  id = 95
  token = "glrt-"
  token_obtained_at = 
  token_expires_at = 
```  