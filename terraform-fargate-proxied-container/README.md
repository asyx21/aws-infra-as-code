# Terraform: Mockserver multicontainer Fargate Cluster behind API Gateway with Application Load Balancer

Client --> API_GW --> VPC_LINK --> ALB --> Fargate (multi-container)

## Description

Cluster with two containers:
- 'echo' server
- 'proxy' server

Proxy server forwards requests to 'echo' server that mirrors the request back to client through 'proxy' server. 

## Docker

Use locally with docker-compose: `docker-compose up -d`. And stop with ``docker-compose down`  
Use `docker ps` to see port mapping. By default 'proxy' server listens on port 80.
You can comment/uncomment `ports` section in `docker-compose.yml` for 'echo' server to make port 8080 publicly available if you want to access it without 'proxy' server as proxy.  

## Terraform

Use variables `cert_arn` and `domain_name` as your convinience if you have a custom DNS.  

When calling API gateway endpoint, Load Balancer sends request to 'proxy' server. Other available routes are:
- `/` nginx front page  
- `/proxy/*` echo server proxied by proxy server  
- `/echo/*` echo server directly  

You can comment `resource "aws_lb_listener_rule" "echo_route"` line 177 to hide 'echo' server behind 'proxy' server proxy.  

Please do not modify variables `echo_port` and `proxy_port` because security groups rules depends on it.  

NB. mockserver can't use port lower than 1024 as a server unless the service is run by root user  
