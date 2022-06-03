# SAM: API Gateway with Application Load Balancer and Fargate cluster through VPC-link

Client --> API_GW --> VPC_LINK --> ALB --> Fargate

## USE

When using `sam deploy -t aws-stack.yml -g` the prompt will ask you for `vpc_id` and `subnet_ids`.  
Just enter available vpc and subnet ids or create new on from you AWS console.
CLI will ask you to store the config in `samconfig.toml` if you want to keep it.  

Example input:

VPC: `vpc-12345678`  
Subnets: `subnet-12345678,subnet-12345679`  

### AWS resources

AWS creates two stacks on Cloud Formation: one for the actual stack, the other for managing versions.

## Source

- [https://serverlessland.com/patterns/apigw-vpclink-pvt-alb](https://serverlessland.com/patterns/apigw-vpclink-pvt-alb)  
