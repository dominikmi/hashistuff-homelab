#### 0. Create service and rules for the firewalld.

The whole nomad cluster communication will take place in the libvirt zone (in the 192.168.100.0/24 network), therefore firewalld should contain defined and allowed all nomad services with default ports: tcp: 4646,4647,4648 (or any other should you decide to change the defaults).

#### 1. Server config:

(/etc/nomad.d/server.hcl)
```
data_dir  = "/var/devops/nomad"

bind_addr = "0.0.0.0" # the default

advertise {
  # Defaults to the first private IP address.
  http = "192.168.100.1:4646"
  rpc  = "192.168.100.1:4647"
  serf = "192.168.100.1:4648"
}

server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled       = true
  network_speed = 10
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

consul {
  address = "192.168.100.1:8500"
}
```

#### 2. Client config (.101 & .102):
(/etc/nomad.d/client.hcl on both worker nodes)

```
data_dir  = "/var/devops/nomad"

bind_addr = "0.0.0.0" # the default

advertise {
  http = "192.168.100.101"
  rpc  = "192.168.100.101"
  serf = "192.168.100.101:5648" # non-default ports may be specified
}

server {
  enabled = false
}

client {
  enabled       = true
  network_speed = 10
  servers = ["192.168.100.1:4647"]
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

consul {
  address = "192.168.100.101:8500"
}
```

#### 3. Check nomad status:

```
$ NOMAD_ADDR=http://nuke:4646
$ nomad node status
ID        DC   Name                Class   Drain  Eligibility  Status
2c14abe9  dc1  worker02            <none>  false  eligible     ready
896ec7ef  dc1  worker01            <none>  false  eligible     ready
c138ca0b  dc1  nuke.nukelab.local  <none>  false  eligible     ready
```
