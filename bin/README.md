## /hashistuff/bin

Two simple scripts:

* *install_cluster.sh* installs nomad, consul, vault binaries, creates working folders and sets up services in the system,
* *install_certs.sh* install local Root and Intermediate CAs, using cfssl; The script places them into system trusted store, as well as into respective nomad, consul, vault cert dedicated folders,
