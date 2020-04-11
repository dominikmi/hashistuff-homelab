## /hashistuff/bin

Two simple scripts:

* __install_cluster.sh__ installs nomad, consul, vault binaries, creates working folders and sets up services in the system,
* __install_certs.sh__ installs local Root and Intermediate CAs, using cfssl; The script places them into system trusted store, as well as into respective nomad, consul, vault cert dedicated folders,
