disable_cache = true
disable_mlock = true
ui = true

{% for node in vault_cluster.nodes %}
{% if node.name == ansible_fqdn %}
listener "tcp" {
    address          = "{{ vault_listener_addr }}"
    cluster_address  = "{{ vault_cluster_addr  }}"
    tls_cert_file    = "{{ vault_conf_path }}/ssl/fullchain.pem"
    tls_key_file     = "{{ vault_conf_path }}/ssl/privkey.pem"
}

storage "raft" {
  path  = "{{ vault_data_path }}/raft"
  node_id = "raft_node_{{ node.id }}"

{% for node in vault_cluster.nodes %}
{% if node.name != ansible_fqdn %}
  retry_join {
    leader_api_addr = "{{ node.protocol }}://{{ node.name }}{% if node.port_api != '' %}:{% endif %}{{ node.port_api }}"
  }
{% endif %}
{% endfor %}

}

api_addr     = "{{ node.protocol }}://{{ node.name }}{% if node.port_api != '' %}:{% endif %}{{ node.port_api }}"
cluster_addr = "https://{{ ansible_fqdn }}:8201"

{% endif %}
{% endfor %}


max_lease_ttl         = "10h"
default_lease_ttl    = "10h"
cluster_name         = "{{vault_cluster_name}}"
raw_storage_endpoint     = true
disable_printable_check = true
