locals {
  service_config      = {
    proxy: {
      name              = "proxy"
      image             = var.image_proxy
      container_port    = var.proxy_port
      environment       = var.proxy_envs
      cpu               = 256
      memory            = 512
      desired_count     = 1
      target_group = {
        port              = var.proxy_port
        protocol          = "HTTP"
        path_pattern      = ["/proxy*"]
        health_check_path = "/health"
        priority          = 2
      }
    },
    echo: {
      name              = "echo"
      image             = var.image_echo
      container_port    = var.echo_port
      environment       = var.echo_envs
      cpu               = 256
      memory            = 512
      desired_count     = 1
      target_group = {
        port              = var.echo_port
        protocol          = "HTTP"
        path_pattern      = ["/echo*"]
        health_check_path = "/health"
        priority          = 2
      }
    }
  }
}
