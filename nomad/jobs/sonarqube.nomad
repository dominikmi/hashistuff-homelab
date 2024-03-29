# 24-08-2022, v0.3, Nomad 1.3.3
# Postgresql runs as prestart sidecar for Sonarqube

job "sonarqube" {
  datacenters = ["dc1"]
  type = "service"
  namespace = "infra"
  priority = 10
  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "srv3u100"
  }
  update {
    stagger          = "15s"
    max_parallel     = 1
    min_healthy_time = "30s"  
    healthy_deadline = "5m"
    auto_revert      = true
  }
  group "sonarqube" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "30s"
      mode = "delay"
    }

# define network within the group

    network {
      port "sonar" { 
        static = 9000
        to     = 9000 
      }
      port "postgres" {
        static = 5432
        to     = 5432
      }
      dns { servers = ["192.168.100.1"] }
    }

# This is where postgresql is deployed

    task "postgresql" {
      driver = "docker"
      config {
	      image   = "powernuke.nukelab.home:5443/postgres:12.10-4"
        volumes = [
          "/data/store1/:/var/lib/postgresql",
          "/data/store1/data:/var/lib/postgresql/data",
        ]
        ports   = ["postgres"]
      }
      vault {
        policies = ["postgres-access"]
      }
      template {
        destination = "secrets/file.env"
        env = true
# Read postgres initial settings from Vault
        data = <<EOF
{{with secret "kv/data/postgres"}}
{{range $key, $value := .Data.data}}
{{$key}}={{$value | toJSON}}{{end}}
{{end}}
EOF
      }

      lifecycle {
        sidecar = true
        hook = "prestart"
      }

      service {
        name = "postgres"
        tags = ["global", "cache"]
        port = "postgres"
        check {
          name     = "tcp_validate"    
          type     = "tcp"    
          port     = "postgres"    
          interval = "15s"    
          timeout  = "30s"
        }
      }
      resources {
        cpu    = 512 # 512Mhz
        memory = 512 # 512MB
      }
    } # close task

# This is where the sonarqube gets deployed

    task "sonar" {
      driver = "docker"
      config {
	      image   = "powernuke.nukelab.home:5443/sonarqube:9.8.0-1"
        volumes = [
          "/data/store2/data:/opt/sonarqube/data",
          "/data/store2/extensions:/opt/sonarqube/extensions",
          "/data/store2/logs:/opt/sonarqube/logs",
          "/data/store2/temp:/opt/sonarqube/temp",
        ]
        ports   = ["sonar"] 
      }
      vault {
        policies = ["sonar-access"]
      }
      template {
        destination = "secrets/file.env"
        env = true
# Read sonarqube secrets from Vault
        data = <<EOF
{{with secret "kv/data/sonar"}}
{{range $key, $value := .Data.data}}
{{$key}}={{$value | toJSON}}{{end}}
{{end}}
EOF
      }
      service {
        name = "sonarqube"
        tags = [
          "traefik",
          "traefik.enable=true",
          "traefik.http.routers.sonarqube.rule=Host(`sonar.nukelab.home`)",
          "traefik.http.routers.sonarqube.tls=true",
        ]
        port = "sonar"
        check {
          name     = "tcp_validate"    
          type     = "tcp"    
          port     = "sonar"    
          interval = "15s"    
          timeout  = "30s"
        }
      }
      resources {
        cpu    = 1024 # up to 1Ghz
        memory = 2048 # up to 2GB
      }
    } # close task
  } # close group
} # close job
