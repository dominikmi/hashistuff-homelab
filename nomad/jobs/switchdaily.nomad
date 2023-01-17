# A cronjob to run ON/OFF sequence on a list of devices

job "switch_daily" {
  datacenters = ["dc1"]
  type        = "batch"
  namespace   = "testbed"
  priority    = 20
  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "powernuke"
  }
  periodic {
    cron = "00 22,08,13,15,18,20 * * *"
    time_zone = "Europe/Warsaw"
  }
  group "switch_daily" {
    task "switch" {
      driver = "docker"
      config {
        image   = "powernuke.nukelab.home:5443/switch:1.1-2"
        command = "/var/empty/run.sh"
        args    = ["${DEVICES}"]
      }
    vault {
        policies = ["switch-access"]
      }
    template {
      destination = "secrets/file.env"
      env = true
# Read all neccessary settings from Vault 
      data = <<EOH
{{with secret "kv/data/heaters"}}
USER={{.Data.data.user | toJSON}}
DEVICES={{.Data.data.devices | toJSON}}
PASSWORDS={{.Data.data.passwords | toJSON}}
DOMAIN={{.Data.data.domain | toJSON}}
{{end}}
EOH
      }
    }
  }
}
