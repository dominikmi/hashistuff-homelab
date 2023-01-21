# This is first approach to deploy InfluxDB into Nomad cluster
# 10-12-2022, Nomad v.1.4.3
# 17-01-2023, Nomad v 1.4.3, config pulled in from Vault

job "telegraf" {
  datacenters = ["dc1"]
  type        = "service"
  namespace   = "testbed"
  priority    = 20
  constraint {
      attribute = "${attr.unique.hostname}"
      value     = "powernuke"
  }
  update {
    stagger          = "15s"
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
  }
  group "telegraf" {
    count = 1
    network {
      mode     = "bridge"
      port "tele1u" {
        to     = 8125
        static = 8125
      }
      port "tele2u" {
        to     = 8092
        static = 8092
      }
      port "tele3t" {
        to     = 8094
        static = 8094
      }
    dns {
        servers = ["192.168.120.231", "192.168.100.1"]
      }
    }

    service {
      name = "telegraf-instance"
      port = "tele3t"
    }
    
    restart {
      attempts = 2
      interval = "5m"
      delay = "15s"
      mode = "fail"
    }

    task "telegraf" {
      driver = "docker"
      config {
        image   = "powernuke.nukelab.home:5443/telegraf:1.2.24-2"
        command = "telegraf"
        args    = ["--config", "/local/telegraf.conf"]
        ports = ["tele1u", "tele2u", "tele3t"]
      }
      vault {
        policies = ["telegraf-access"]
      }
      template {
        destination = "secrets/file.env"
        env = true
# Read initial Influx token and config URL from Vault
        data = <<EOF
{{with secret "kv/data/telegraf"}}
INFLUX_TOKEN={{.Data.data.INFLUX_TOKEN | toJSON}}
{{end}}
EOF
        change_mode = "restart"
      }
      template {
        data        = <<EOH
{{ with secret "kv/data/telegraf" }}
{{ .Data.data.TELEGRAF_CONFIG }}
{{ end }}
EOH
        destination = "/local/telegraf.conf"
        change_mode = "restart"
        splay       = "1m"
      }
      resources {
        cpu    = 300 # 300 MHz
        memory = 256 # 256MB
      }
    }
  }
}
