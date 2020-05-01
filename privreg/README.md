### TL;DR
### Quick and dirty way to set up quickly a private docker registry.

We already have our nomad up and running. All prerequisites are in place (the certs, keys, docker etc.).
Here's the `registry.nomad` [job definition](../nomad/jobs/registry.nomad).

```
$ export NOMAD_ADDR=https://dmthin.nukelab.local
$ export NOMAD_TOKEN=<the one we already used before>
$ nomad plan registry.nomad
```
See if we are ok - we were not, at the first shot - I went too far and added a variable not neccessarily required:
```
[hobbes@dmthin deployments]$ nomad plan registry.nomad 
+/- Job: "registry"
+/- Task Group: "registry" (1 create/destroy update)
  +/- Task: "registry" (forces create/destroy update)
    + Env[REGISTRY_HTTP_ADDR]:            "dmthin.nukelab.local:5000"
    + Env[REGISTRY_HTTP_TLS_CERTIFICATE]: "/certs/dmthin-peer.pem"
    + Env[REGISTRY_HTTP_TLS_KEY]:         "/certs/dmthin-peer-key.pem"

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 3935
To submit the job with version verification run:

nomad job run -check-index 3935 registry.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
[hobbes@dmthin deployments]$ nomad job run -check-index 3935 registry.nomad
==> Monitoring evaluation "aa912ed9"
    Evaluation triggered by job "registry"
    Evaluation within deployment: "09806ca2"
    Allocation "fee37fa1" created: node "112c23f5", group "registry"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "aa912ed9" finished with status "complete"
[hobbes@dmthin deployments]$ vim registry.nomad 
[hobbes@dmthin deployments]$ nomad plan registry.nomad 
+/- Job: "registry"
+/- Task Group: "registry" (1 create/destroy update)
  +/- Task: "registry" (forces create/destroy update)
    +/- Env[REGISTRY_HTTP_ADDR]: "dmthin.nukelab.local:5000" => "192.168.120.235:5000"

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 3971
To submit the job with version verification run:

nomad job run -check-index 3971 registry.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
[hobbes@dmthin deployments]$ nomad job run -check-index 3971 registry.nomad
==> Monitoring evaluation "28ff0fad"
    Evaluation triggered by job "registry"
    Evaluation within deployment: "552e117a"
    Allocation "c4bb0503" created: node "112c23f5", group "registry"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "28ff0fad" finished with status "complete"
```

Are we Ok?

```
curl -X GET https://dmthin.nukelab.local:5000/v2/_catalog
{"repositories":["centos","jenkins"]}
```

We are. Previously downloaded and retagged images are there and the repo responds on TLS 5000 port.

**ps. Yeah, I've got another Nomad server, reanimated an old thinkpad :-) More coming soon.**

