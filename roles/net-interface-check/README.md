# README
* register vars  second_interface_name
* check address second interface  {{ ansible_facts[second_interface_name].ipv4.address }}