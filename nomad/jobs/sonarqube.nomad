# Sonarqube + postgresql deployed in Nomad 1.2.6
# 26-03-2022, v0.1
# 23-06-2022, v0.2

job "sonarqube" {
  datacenters = ["dc1"]
  type = "service"
  priority = 10
  constraint {
      attribute = "${attr.unique.hostname}"
      value     = "srv2u100"
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

# volumes

    volume "store1" {
      type      = "host"
      read_only = false
      source    = "store1"
    }

    volume "store2" {
      type      = "host"
      read_only = false
      source    = "store2"
    }

# This is where postgresql is deployed

    task "postgresql" {
      driver = "docker"
      
      volume_mount {
        volume      = "store1"
        destination = "/var/lib/postgresql"
        read_only   = false
      }
      
      config {
        image = "postgres:12.10"
#	      image = "powernuke.nukelab.home:5443/postgres:12.10-2"
        ports = ["postgres"]
      }

      env {
        POSTGRES_USER=sonar
        POSTGRES_PASSWORD=sonar
      }
      service {
        name = "sonarqube"
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
      
      volume_mount {
        volume      = "store2"
        destination = "/opt/sonarqube"
        read_only   = false
      }
      
      config {
        image = "sonarqube:9.3.0-community"
#	      image = "powernuke.nukelab.home:5443/sonarqube:9.3.0-1"
        ports = ["sonar"] 
      }
      env {
        SONAR_JDBC_URL="jdbc:postgresql://192.168.100.102:5432/sonar"
        SONAR_JDBC_USERNAME=sonar
        SONAR_JDBC_PASSWORD=sonar
      }
      service {
        name = "sonarqube"
        tags = ["global", "cache"]
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
        cpu    = 512 # 512Mhz
        memory = 2048 # 2GB
      }
    } # close task

  } # close group
} # close job
