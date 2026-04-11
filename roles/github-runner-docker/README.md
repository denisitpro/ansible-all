# github-runner-docker

## Configuration

Define `github_repos` in `group_vars/<your_group>/github_runner.yml`.  
Each item registers one self-hosted runner container.

```yaml
github_repos:
  - name: my-repo                                          # unique suffix: container name, data dir, RUNNER_NAME
    full_url: https://github.com/your-org/my-repo         # repository URL
    runner_token: "{{ vault_github_runner_token }}"        # registration token from repo Settings → Actions → Runners
    labels:
      - linux
      - x64
      - "{{ inventory_hostname_short }}"                  # ansible short hostname as runner label
      - some-custom-label

  - name: another-repo
    full_url: https://github.com/your-org/another-repo
    runner_token: "{{ vault_github_another_runner_token }}"
    labels:
      - linux
      - x64
      - "{{ inventory_hostname_short }}"
```

### Fields

| Field | Required | Description |
|---|---|---|
| `name` | yes | Unique name per host. Used as container name, data directory, and part of `RUNNER_NAME` |
| `full_url` | yes | Full URL of the repository (or org) to register the runner against |
| `runner_token` | yes* | Short-lived registration token from repo Settings → Actions → Runners. Needed only on initial setup; runner files are persisted between restarts |
| `access_token` | alt | GitHub PAT (Classic or Fine-grained). Auto-fetches a fresh registration token on every container start — use when full container recreation is expected |
| `labels` | no | List of labels assigned to the runner in GitHub Actions |

`runner_token` and `access_token` are mutually exclusive; `access_token` takes priority if both are set.

### Token lifetime note

`token` is valid for ~1 hour from generation. Since this role persists runner state
(`CONFIGURED_ACTIONS_RUNNER_FILES_DIR` is mounted as a volume), re-registration on
container **restart** is not required. A new token is only needed when the runner data
directory is wiped or the container is recreated from scratch.
