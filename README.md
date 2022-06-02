# AWS Infra as Code

Starter for AWS Infrastructure as Code with SAM and Terraform

## Prerequisite

- Install and configure [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)  
- Install [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli)  

## WARNING

Use `example.secrets.tfvars` and `example.tfvars.json` to store sensitive config.  
When using in production it MUST be kept SECRET !  

Please copy-paste content in new files `dev.secrets.tfvars` and `dev.tfvars.json` to use them.  

## Use

### Terraform

- `cd <Example of your choice>`  
- `terraform init` only the first time  
- create 'dev' workspace: `terraform workspace new dev`  
- use 'dev' workspace: `terraform workspace select dev`  
- list workspaces: `terraform workspace list`  
- `terraform validate`  
- `terraform plan -var-file="dev.secrets.tfvars.json" -out="out.plan"`  
- Or if multiple var files: `terraform plan -var-file="dev.secrets.tfvars.json" -var-file="dev.tfvars.json" -out="out.plan"`  
- `terraform apply out.plan`  
- `terraform destroy -var-file="dev.secrets.tfvars.json" -var-file="dev.tfvars.json"`

### SAM

- `cd <Example of your choice>`  
- `sam validate -t aws-stack.yml`  
- `sam deploy -t aws-stack.yml -g`  
- `sam delete` or `sam delete --stack-name sam-app`
