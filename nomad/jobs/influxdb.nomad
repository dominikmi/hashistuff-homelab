# This is first approach to deploy InfluxDB into Nomad cluster
# 6-12-2022, Nomad v.1.4.3

job "influxdb" {
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
  group "influxdb" {
    count = 1
    network {
      mode     = "bridge"
      port "influx" {
        to     = 8086
        static = 8086
      }
    dns {
        servers = ["192.168.120.231"]
      }
    }

    service {
      name = "influx-instance"
      port = "influx"
      tags = [
        "traefik",
        "traefik.enable=true",
        "traefik.http.routers.influxdb.rule=Host(`influx.nukelab.home`)",
        "traefik.http.routers.influxdb.tls=true"
      ]
      check {
        type     = "https"
        path     = "/"    
        port     = "influx"    
        interval = "30s"    
        timeout  = "15s"
      }
    }
    restart {
      attempts = 2
      interval = "5m"
      delay = "15s"
      mode = "fail"
    }

    task "influxdb" {
      driver = "docker"
      config {
        image         = "powernuke.nukelab.home:5443/influxdb:2.5.1-2"
        volumes       = [
          "/data/influxdb/data:/var/lib/influxdb2",
          "/data/influxdb/etc:/etc/influxdb2"
        ]
        ports = ["influx"]
      }
      vault {
        policies = ["influxdb-access"]
      }
      template {
        destination = "secrets/file.env"
        env = true
# Read initial Influxdb settings from Vault
        data = <<EOF
{{with secret "kv/data/influxdb"}}
{{range $key, $value := .Data.data}}
{{$key}}={{$value | toJSON}}{{end}}
{{end}}
EOF
      }
      resources {
        cpu    = 300 # 500 MHz
        memory = 384 # 256MB
      }
    }
  }
}
