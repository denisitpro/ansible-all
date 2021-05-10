# Docker disable firewall management

## Desctiption
One of the security concerns is that docker manages the firewall itself at the OS level. 

If we disable this control, then outgoing traffic and traffic between containers stop going

## Targets and solution to the problem
* Monitor incoming traffic
* Allow outbound traffic from containers
* Allow traffic between containers

The role below does the following
* Allows outgoing traffic
* Allows traffic between containers
* Configures UFW default policy forrward - allow
* Add autostart  rule after reboot

As a result, we manage the filtering of incoming traffic, but at the same time we still have working containers.