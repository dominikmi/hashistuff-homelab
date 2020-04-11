## hashistuff
This is a repository with Various works and studies on Hashicorp nomad, consul and vault.
I appreciate all those on-line classes, but actually the best way is the DYI approach.

* How to setup secure Nomad cluster,
* How to setup secure Consul cluster, 
* How to setup Vault with secure consul backend,
* How to setup transit auto-unseal vault,

### Prerequisites

* A CentOS 8 machine with min. 8GB RAM, 4 cores and 128G HDD/SSD
* WiFi or any other LAN,
* Libvirtd active and configured as NAT, with static IPs and dnsmasq turned off on CentOS 8,
* BIND 9 installed and configured for hosts in both nets: public LAN and Libvirtd

### Network diagram

Here's a diagram of a simple LAN with NUC box being a firewall/router between the LAN and a virtual LAN set in libvirt. This is the environment where I am going to set up a lab grade Nomad+Consul+Vault cluster.

![Lan diagram](pictures/Diagram-LAN.png)

