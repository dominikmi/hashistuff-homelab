## Grafana initial setup
## Nomad, v1.4.3, 10-12-2022
## no external DB, no users

job "grafana" {
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
  group "grafana" {
    count = 1
    network {
      mode     = "bridge"
      port "grafana" {
        to     = 3333
        static = 3333
      }
    dns {
        servers = ["192.168.120.231"]
      }
    }
service {
      name = "grafana-instance"
      port = "grafana"
      tags = [
        "traefik",
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=Host(`grafana.nukelab.home`)",
        "traefik.http.routers.grafana.tls=true"
      ]
      check {
        type     = "http"
        path     = "/"    
        port     = "grafana"    
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

    task "grafana" {
      driver = "docker"
      config {
        image   = "powernuke.nukelab.home:5443/alpine-grafana:9.3.1-1"
        volumes = [
          "/data/grafana/data:/var/lib/grafana/data",
          "/data/grafana/log:/var/lib/grafana/logs"
        ]
        ports = ["grafana"]
      }
      vault {
        policies = ["grafana-access"]
      }
      template {
        destination = "secrets/file.env"
        env = true
# Override default Grafana settings with values from Vault
        data = <<EOF
{{with secret "kv/data/grafana"}}
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