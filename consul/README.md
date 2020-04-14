
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
~~~
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

Now, 
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

