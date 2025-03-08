# Expanding the ClickHouse Keeper Cluster

## Scenario

Expanding the current ClickHouse Keeper cluster to 5 nodes.

## Assumptions and Limitations

- You already have 3 working nodes in the cluster.
- The cluster nodes have correctly configured `hostname`, e.g., `keeper-01`, and a properly configured DNS suffix `example.com`.
- The servers in the cluster can resolve addresses such as `keeper-02.example.com` correctly.
- The servers are already configured, and only the Keeper role remains to be deployed.
- The configuration includes the following parameter:
  ```xml
  <enable_reconfiguration>true</enable_reconfiguration>
  ```

### Example host group (04 and 05 are new nodes being added)

```ini
[keeper_group]
keeper-01.example.com
keeper-02.example.com
keeper-03.example.com
keeper-04.example.com
keeper-05.example.com
```

## Execution Steps

### Steps to Follow:

1. **Update the configuration on existing nodes**, adding new nodes to `server.xml`.
2. **Restart the existing nodes** (one at a time) to apply the updated configuration.
3. **Start the new nodes with the same configuration**.
4. **Verify cluster consistency**, ensuring the new set of nodes is functioning correctly.

### Main Issue

If the role runs on all servers simultaneously, it may cause cluster instability. We need to update the existing nodes first and then add new ones sequentially.

Since the role computes the ID based on the group, it does not suit our needs. Therefore, we explicitly define the array of servers.

## Execution Steps

1. **Check the current Keeper nodes and their IDs**:

   ```bash
   cat /opt/keeper/config/keeper_config.xml
   ```

2. **Form an array of existing and new servers**:

   ```yaml
   keeper_raft_servers:
   - id: 1
     hostname: keeper-01.example.com
   - id: 2
     hostname: keeper-02.example.com
   - id: 3
     hostname: keeper-03.example.com
   - id: 4
     hostname: keeper-04.example.com
   - id: 5
     hostname: keeper-05.example.com
   ```

3. **Enable `serial: 1` in the Ansible playbook** to ensure the existing servers update sequentially:

   ```yaml
   ---
   - hosts: keeper_group
     become: true
     # serial: 1
     roles:
       - clickhouse-keeper-install
   ```

4. **Verify the `hosts` file** – only the current nodes should be included in the group:

   ```ini
   [keeper_group]
   keeper-01.example.com
   keeper-02.example.com
   keeper-03.example.com
   # keeper-04.example.com
   # keeper-05.example.com
   ```

5. **Run the configuration update**:

   ```bash
   ansible-playbook -i env/devel keeper-cluster.yml -t keeper-config
   ```

6. **Ensure the cluster is functioning as expected**.

7. **Comment out `serial: 1` in the playbook** and update the `hosts` file, replacing active nodes with new ones:

   ```ini
   [keeper_group]
   # keeper-01.example.com
   # keeper-02.example.com
   # keeper-03.example.com
   keeper-04.example.com
   keeper-05.example.com
   ```

8. **Run the Ansible playbook with the `keeper` tag**:

   ```bash
   ansible-playbook -i env/devel keeper-cluster.yml -t keeper
   ```

9. **Restore the `hosts` file to its normal state**:

   ```ini
   [keeper_group]
   keeper-01.example.com
   keeper-02.example.com
   keeper-03.example.com
   keeper-04.example.com
   keeper-05.example.com
   ```

10. **Add new nodes to the cluster**:

    - This is done on the cluster leader node.
    - Verify that the node is the leader:

      ```bash
      echo srvr | nc 127.0.0.1 9181
      ```

    - Add the new node:

      ```bash
      reconfig add "server.4=keeper-04.example.com:9234"
      get "/keeper/config"
      ```

    - Check logs on the newly added node `keeper-04`:

      ```bash
      tail -f /opt/keeper/logs/clickhouse-keeper.log
      ```

11. **Check the status of the new cluster nodes**:

    ```bash
    curl http://127.0.0.1:9182/ready | jq
    ```

    Expected response:

    ```json
    {
      "details": {
        "hasLeader": true,
        "role": "follower"
      },
      "status": "ok"
    }
    ```

12. **Update the ClickHouse configuration**:

    ```bash
    ansible-playbook -i env/devel keeper-cluster.yml -t click-config
    ```

## Useful Commands

- **Connect to Keeper**:

  ```bash
  docker exec -it keeper clickhouse-keeper-client --host 127.0.0.1 --port 9181
  ```

- **Check `srvr` mode**:

  ```bash
  echo srvr | nc 127.0.0.1 9181
  ```

- **Check Keeper configuration**:

  ```bash
  get "/keeper/config"
  ```

- **Check node status**:

  ```bash
  echo stat | nc 127.0.0.1 9181
  ```
