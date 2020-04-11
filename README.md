## hashistuff
Various works with Hashicorp nomad, consul and vault.

* How to setup secure Nomad cluster,
* How to setup secure Consul cluster, 
* How to setup Vault with secure consul backend,
* How to setup transit auto-unseal vault,

### Prerequisites

* A CentOS 8 machine with min. 8GB RAM, 4 cores and 128G HDD/SSD
* WiFi or any other LAN,
* Libvirtd active and configured as NAT, with static IPs and dnsmasq turned off on CentOS 8,
* BIND 9 installed and configured for hosts in both nets: public LAN and Libvirtd
