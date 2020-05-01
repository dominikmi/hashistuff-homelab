### TL;DR
### Quick and dirty way to set up quickly a private docker registry.

We already have our nomad up and running. All prerequisites are in place (the certs, keys, docker etc.).
Here's the `registry.nomad` [job definition](../nomad/jobs/registry.nomad).

```
$ export NOMAD_ADDR=https://dmthin.nukelab.local
$ export NOMAD_TOKEN=<the one we already used before>
$ nomad plan registry.nomad
```
See if we are ok - always do `nomad plan ..` before any deployment of your jobs:
```
$ nomad plan registry.nomad 
+/- Job: "registry"
+/- Task Group: "registry" (1 create/destroy update)
  +/- Task: "registry" (forces create/destroy update)

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 3971
To submit the job with version verification run:

nomad job run -check-index 3971 registry.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
```

$ nomad job run registry.nomad
==> Monitoring evaluation "28ff0fad"
    Evaluation triggered by job "registry"
    Evaluation within deployment: "552e117a"
    Allocation "c4bb0503" created: node "112c23f5", group "registry"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "28ff0fad" finished with status "complete"
```

Are we Ok?
Check the job (it runs at last!)
```
$ nomad job status registry
ID            = registry
Name          = registry
Submit Date   = 2020-05-01T20:17:09+02:00
Type          = service
Priority      = 10
Datacenters   = dc1
Namespace     = default
Status        = running
Periodic      = false
Parameterized = false

Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost
registry    0       0         1        0       6         0

Latest Deployment
ID          = 69b315f0
Status      = failed
Description = Failed due to progress deadline

Deployed
Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
registry    1        1       0        1          2020-05-01T20:27:09+02:00

Allocations
ID        Node ID   Task Group  Version  Desired  Status   Created    Modified
7dc86f28  112c23f5  registry    8        run      running  1h39s ago  55m39s ago
```

Check the repo.
```
$ curl -X GET https://dmthin.nukelab.local:5000/v2/_catalog
{"repositories":["centos","jenkins"]}
```

We are Ok. Previously downloaded and retagged images are there and the repo responds on TLS 5000 port.

*ps. Yeah, I've got another Nomad server, reanimated an old thinkpad :-) More coming soon.*

