# allow docker access section
#allow all traffic for docker interface
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i docker0 -j ACCEPT

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o docker0 -j ACCEPT


# Create a new chain
iptables -N DOCKER
iptables -A FORWARD -o docker0 -j DOCKER

# Enable masquerading and allow connections to containers
iptables -t nat -A POSTROUTING -s 172.17.0.0/12 ! -o docker0 -j MASQUERADE
iptables -t filter -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow internal and external container communication
iptables -t filter -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
iptables -t filter -A FORWARD -i docker0 -o docker0 -j ACCEPT

iptables -A DOCKER -j RETURN