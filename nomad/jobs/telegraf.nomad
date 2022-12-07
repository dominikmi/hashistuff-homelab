# This is first approach to deploy InfluxDB into Nomad cluster
# 6-12-2022, Nomad v.1.4.3

job "telegraf" {
  datacenters = ["dc1"]
  type        = "service"
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
      tags = [
        "traefik",
        "traefik.enable=true",
        "traefik.http.routers.influxdb.rule=Host(`telegraf.nukelab.home`)",
        "traefik.http.routers.influxdb.tls=true"
      ]
      check {
        type     = "http"
        path     = "/"    
        port     = "tele3t"    
        interval = "30s"    
        timeout  = "10s"
      }
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
        image   = "powernuke.nukelab.home:5443/telegraf:1.2.24-1"
        command = "telegraf"
        args    = ["--config", "${INFLUX_CONFIG_URL}"]
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
{{range $key, $value := .Data.data}}
{{$key}}={{$value | toJSON}}{{end}}
{{end}}
EOF
        change_mode = "restart"
      }
      resources {
        cpu    = 300 # 300 MHz
        memory = 256 # 256MB
      }
    }
  }
}