
### Setting up Consul
---

#### 1. Create firewalld services for Consul.

We have to create tcp and udp services called "_Consul services_" and apply them to libvirtd zone: 

* tcp ports: 8300, 8301, 8302, 8400, 8500, 8600 
* udp: 8301, 8302, 8600

#### 2. Create Consul encryption key 

This encryption key is required to provide encryption to communication between agents (in server and client mode).
```
consul keygen
uFO39ExWFLHFf/TwnOPdkhROaowqnfyKyaMht/BC/A8=
```

#### 3. Create config for the server

Now we can create a config file for the server in *.json* format.

(/etc/consul.d/consul.json)
```
{
    # min. number of the server to initialize the consul cluster
    "bootstrap_expect": 1,
    # default setting, consul client will listen on all ifaces incl. loopback - good for CLI
    "client_addr": "0.0.0.0",
    # name of your datacenter
    "datacenter": "nukelab",
    # where all the operational data of the cluster is stored
    "data_dir": "/var/devops/consul",
    # cluster domain name
    "domain": "consul",
    "enable_script_checks": true,
    "dns_config": {
        "enable_truncate": true,
        "only_passing": true
    },
    # enable logging to system logs
    "enable_syslog": true,
    # our encryption key generated in step 2
    "encrypt": "uFO39ExWFLHFf/TwnOPdkhROaowqnfyKyaMht/BC/A8=",
    "leave_on_terminate": true,
    "log_level": "INFO",
    "rejoin_after_leave": true,
    # is this agent a server?
    "server": true,
    # join itself
    "start_join": [
        "192.168.100.1"
    ],
    # turn on webUI
    "ui": true
}
```

#### 4. Create config for consul clients

(both 192.168.100.101 & 102 - /etc/consul.d/consul.json)

```
{
    "client_addr": "0.0.0.0",
    "datacenter": "nukelab",
    "data_dir": "/var/devops/consul",
    "domain": "consul",
    "enable_script_checks": true,
    "dns_config": {
        "enable_truncate": true,
        "only_passing": true
    },
    "enable_syslog": true,
    "encrypt": "uFO39ExWFLHFf/TwnOPdkhROaowqnfyKyaMht/BC/A8=",
    "leave_on_terminate": true,
    "log_level": "INFO",
    "rejoin_after_leave": true,
    # we workers are not servers
    "server": false,
    "start_join": [
        "192.168.100.1"
    ],
    "ui": true
}
```

#### 5. Modify consul.service
(/etc/systemd/system/consul.service)
Modify the `ExecStart` entry to bind the agent to specific interface on the server and the workers.

```
[Unit]
Description=Consul Startup process
After=network.target
 
[Service]
Type=simple
ExecStart=/bin/bash -c '/usr/local/bin/consul agent -config-dir /etc/consul.d/ **-bind 192.168.100.1** *[101 and 102]*'
TimeoutStartSec=0
 
[Install]
WantedBy=default.target
```

Start and check consul cluster setup:
```
$ sudo systemctl daemon-reload
$ sudo systemctl start consul
```
..and check Consul:

```
$ consul members
Node                Address               Status  Type    Build  Protocol  DC       Segment
nuke.nukelab.local  192.168.100.1:8301    alive   server  1.7.2  2         nukelab  <all>
worker01            192.168.100.101:8301  alive   client  1.7.2  2         nukelab  <default>
worker02            192.168.100.102:8301  alive   client  1.7.2  2         nukelab  <default>
```

Now, we can go to the [vault setup](../vault/README.md) and get the basic vault cluster running. Once we get that done, we will come back and follow up remaining steps on TLS and ACL for consul.


### Setting up TLS for consul
---

#### 1. extend the *consul.json* config on the server by the following entries:
(Note: we use the same certificates we have created for Nomad),
```
  "verify_incoming": true,
   "verify_outgoing": true,
   "verify_server_hostname": true,
   "ca_file": "/etc/consul.d/certs/intermediate_ca.pem",
   "cert_file": "/etc/consul.d/certs/nuke-peer.pem",
   "key_file": "/etc/consul.d/certs/nuke-peer-key.pem",
   "auto_encrypt": {
   "allow_tls": true
```

#### 2. Configure the consul clients

Add the below piece of config to the _consul.json_ file
```
  "verify_incoming": false,
  "verify_outgoing": true,
  "verify_server_hostname": true,
  "ca_file": "intermediate_ca.pem",
  "auto_encrypt": {
    "tls": true
  }
```

#### 3. Restart consul server and the clients

```
$ sudo systemctl restart consul
$ sudo systemctl status consul
[..]
Apr 08 10:35:11 nuke.nukelab.local bash[25454]:     2020-04-08T10:35:11.308+0200 [INFO]  agent: Synced node info
Apr 08 10:35:11 nuke.nukelab.local consul[25454]:  agent: Synced node info
Apr 08 10:35:18 nuke.nukelab.local bash[25454]:     2020-04-08T10:35:18.733+0200 [INFO]  agent.server.serf.lan: serf: EventMemberJoin: worker01 192.168.100.101
Apr 08 10:35:18 nuke.nukelab.local bash[25454]:     2020-04-08T10:35:18.733+0200 [INFO]  agent.server: member joined, marking health alive: member=worker01
Apr 08 10:35:18 nuke.nukelab.local consul[25454]:  agent.server.serf.lan: serf: EventMemberJoin: worker01 192.168.100.101
Apr 08 10:35:18 nuke.nukelab.local consul[25454]:  agent.server: member joined, marking health alive: member=worker01
Apr 08 10:35:35 nuke.nukelab.local bash[25454]:     2020-04-08T10:35:35.593+0200 [INFO]  agent.server.serf.lan: serf: EventMemberJoin: worker02 192.168.100.102
Apr 08 10:35:35 nuke.nukelab.local bash[25454]:     2020-04-08T10:35:35.594+0200 [INFO]  agent.server: member joined, marking health alive: member=worker02
Apr 08 10:35:35 nuke.nukelab.local consul[25454]:  agent.server.serf.lan: serf: EventMemberJoin: worker02 192.168.100.102
Apr 08 10:35:35 nuke.nukelab.local consul[25454]:  agent.server: member joined, marking health alive: member=worker02
```

#### 4. You can define HTTPS access only

By adding this piece to the /etc/consul.d/consul.json:
```
[..]
"ports": {
        "http": -1,    # turn off http
        "https": 8500  # leave the https on 8500
    },
 [..]
```

Please note, that now your browser has to have a client certificate to present to consul server set for mutual authentication.
Use this [tutorial](install-certs.md) to create another client cert and add it to your browser.

#### 5. Final configs

Ultimately, your consul server _consul.json_ file should look like this:
```
{
    "bootstrap_expect": 1,
    "client_addr": "0.0.0.0",
    "datacenter": "nukelab",
    "data_dir": "/var/devops/consul",
    "domain": "consul",
    "enable_script_checks": true,
    "dns_config": {
        "enable_truncate": true,
        "only_passing": true
    },
    "ports": {
        "http": 8500,
        "https": 8501
    },
    "enable_syslog": true,
    "encrypt": "uFO39ExWFLHFf/TwnOPdkhROaowqnfyKyaMht/BC/A8=",
    "leave_on_terminate": true,
    "log_level": "INFO",
    "rejoin_after_leave": true,
    "server": true,
    "start_join": [
        "192.168.100.1"
    ],
    "ui": true,
    "verify_incoming": true,
    "verify_outgoing": true,
    "verify_server_hostname": true,
    "ca_file": "/etc/consul.d/certs/intermediate_ca.pem",
    "cert_file": "/etc/consul.d/certs/nuke-peer.pem",
    "key_file": "/etc/consul.d/certs/nuke-peer-key.pem",
    "auto_encrypt": {
    "allow_tls": true
  }

}
```

And the client configs (on both nodes) should look like in the below snippet. Please make sure you've got appropriate certificates places in both nodes.
```
{
    "client_addr": "0.0.0.0",
    "datacenter": "nukelab",
    "data_dir": "/var/devops/consul",
    "domain": "consul",
    "enable_script_checks": true,
    "dns_config": {
        "enable_truncate": true,
        "only_passing": true
    },
    "enable_syslog": true,
    "encrypt": "uFO39ExWFLHFf/TwnOPdkhROaowqnfyKyaMht/BC/A8=",
    "leave_on_terminate": true,
    "log_level": "INFO",
    "rejoin_after_leave": true,
    "server": false,
    "start_join": [
        "192.168.100.1"
    ],
    "ui": true,

    "verify_incoming": true,
    "verify_outgoing": true,
    "verify_server_hostname": true,
    "ca_file": "/etc/consul.d/certs/intermediate_ca.pem",
    "cert_file": "/etc/consul.d/certs/worker01-client.pem",
    "key_file": "/etc/consul.d/certs/worker01-client-key.pem",
    "auto_encrypt": {
    "tls": true
    }
}
``` 

Our Consul cluster can enjoy now secured communication.
