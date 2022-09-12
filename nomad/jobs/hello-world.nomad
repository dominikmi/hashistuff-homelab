# a test job for Traefik proxy testing
# v0.1

job "hello-world" {
 type        = "service"
 datacenters = ["dc1"]
 
 
 group "hello-world" {
 
   network {
     mode = "bridge"
 
     port "http" {
       to = 80
     }
   }
 
   service {
     tags = [
       "traefik.http.routers.hello-world.rule=Host(`hello-world.nukelab.home`)",
       "traefik.http.routers.hello-world.entrypoints=web",
       "traefik.http.routers.hello-world.tls=true",
       "traefik.enable=true",
     ]
 
     port = "http"
 
     check {
       type     = "tcp"
       interval = "10s"
       timeout  = "5s"
     }
   }
 
   task "hello-world" {
     driver = "docker"
 
     config {
       image = "caddy"
       ports = ["http"]
     }
 
     resources {}
   }
 }
}
