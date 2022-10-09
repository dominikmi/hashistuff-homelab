# Trivy server deployed in Nomad 1.4.1
# 22-01-2022, v0.1
# 09-10-2022, v0.2

job "trivy-server" {
  datacenters = ["dc1"]
  type = "service"
  priority = 10
  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "powernuke"
  }
  update {
    stagger          = "10s"
    max_parallel     = 1
    min_healthy_time = "30s"  
    healthy_deadline = "5m"
    auto_revert      = true
  }
  group "trivy-server" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "30s"
      mode = "delay"
    }

# define network within the group

    network {
      port "scan" { 
        static = 8000
        to     = 8000 
      }
      dns { servers = ["192.168.120.231"] }
    }

# This is where the trivy server gets deployed
		
    task "trivy-scan-server" {
      driver = "docker"
      config {
        image = "powernuke.nukelab.home:5443/trivy:0.31.3-1"
        ports = ["scan"]
        args = ["server", "--listen", "0.0.0.0:${NOMAD_PORT_scan}"]
      }
      service {
        name = "trivy-scan-port"
        tags = ["global", "cache"]
        port = "scan"
        check {
          name     = "tcp_validate"    
          type     = "tcp"    
          port     = "scan"    
          interval = "15s"    
          timeout  = "30s"
        }
      }
      resources {
        cpu    = 200 # 200Mhz
        memory = 128 # 128 MB
      }
    } # close task
  } # close group
} # close job
