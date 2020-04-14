
### Basic setup
---

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

### TLS for Nomad
---

#### 1. Follow the procedure desribed [here](cfssl/README.md)

#### 2. Modify config nomad server

```
tls {
  http = true
  rpc  = true

  ca_file   = "/etc/nomad.d/certs/intermediate_ca.pem"
  cert_file = "/etc/nomad.d/certs/nuke-peer.pem"
  key_file  = "/etc/nomad.d/certs/nuke-peer-key.pem"
  # leave these set as false for now
  verify_server_hostname = false
  verify_https_client    = false
}
```

#### 3. Modify config nomad client

```
tls {
  http = true
  rpc  = true

  ca_file   = "/etc/nomad.d/certs/intermediate_ca.pem"
  cert_file = "/etc/nomad.d/certs/worker01-client.pem"
  key_file  = "/etc/nomad.d/certs/worker01-client-key.pem"

  verify_server_hostname = false
  verify_https_client    = false
}
```

#### 4. Restart nomad server - then nomad clients,one by one.
 
You can now test the `verify_server_hostname` and `verify_https_client` set to `true`. Observe nomad logs, if you see that nomad is missing specific client/server name in the cert and throws error, you'd have to re-generate you server or/and client certs and try again.

#### 5. Test Nomad 

Set the `NOMAD_ADDR` to https addr prefix and run some nomad commands. I already have some jobs prepared, so I tried some operations on them.

```
$ export NOMAD_ADDR=https://nuke.nukelab.local:4646
[hobbes@dmlap jobs]$ nomad job plan haproxy.nomad 
+/- Job: "haproxy"
+   Affinity {
    + LTarget: "${attr.kernel.version}"
    + Operand: "version"
    + RTarget: ">= 4.18"
    + Weight:  "50"
    }
+/- Task Group: "haproxy" (1 create/destroy update)
  +/- Update {
        AutoPromote:      "false"
        AutoRevert:       "false"
        Canary:           "0"
        HealthCheck:      "checks"
        HealthyDeadline:  "300000000000"
        MaxParallel:      "1"
    +/- MinHealthyTime:   "10000000000" => "30000000000"
        ProgressDeadline: "600000000000"
      }
      Task: "haproxy"

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 11648
To submit the job with version verification run:

nomad job run -check-index 11648 haproxy.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
```
```
$ nomad job run -check-index 11648 haproxy.nomad 
==> Monitoring evaluation "7839c50d"
    Evaluation triggered by job "haproxy"
    Evaluation within deployment: "faa80eaa"
    Allocation "20e35554" created: node "2c14abe9", group "haproxy"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "7839c50d" finished with status "complete"
```
