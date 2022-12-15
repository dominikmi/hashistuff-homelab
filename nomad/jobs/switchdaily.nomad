# A cronjob to run ON/OFF sequence on a list of devices

job "switch_daily" {
  datacenters = ["dc1"]
  type        = "batch"
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
        image   = "powernuke.nukelab.home:5443/switch:1.0-3"
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
TCMD={{.Data.data.cmd | toJSON}}
DEVICES={{.Data.data.devices | toJSON}}
DOMAIN={{.Data.data.domain | toJSON}}
{{end}}
EOH
      }
    }
  }
}