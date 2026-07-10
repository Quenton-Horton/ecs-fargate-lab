# ECS Fargate Lab — Containerized Deployment on AWS

A production-topology container deployment built entirely in Terraform: an
Application Load Balancer fronting AWS Fargate tasks running across two
Availability Zones in private subnets, with outbound access through a NAT
gateway and logs shipped to CloudWatch.

## Architecture

    Internet
       |
       v
    Application Load Balancer   (public subnets, 2 AZs)
       |
       v
    Target Group  (target_type = ip)
       |
       v
    ECS Service  (FARGATE, desired_count = 2)
       |
       +--> Fargate task --> private subnet us-east-1a (10.20.11.0/24)
       +--> Fargate task --> private subnet us-east-1b (10.20.12.0/24)
                |
                v
           NAT Gateway (public subnet) --> Internet  (image pull, outbound)
                |
                v
           CloudWatch Logs  (/ecs/ecs-fargate-lab)

## Components

- VPC 10.20.0.0/16 — 2 public + 2 private subnets across us-east-1a/b
- Internet Gateway for public-subnet egress; NAT Gateway for private-subnet
  outbound (image pulls, AWS API calls)
- Application Load Balancer in public subnets; HTTP listener on port 80
  forwarding to a target group with target_type = ip (required for Fargate —
  tasks register by ENI IP, not by instance)
- ECS Cluster (Fargate) with Container Insights enabled
- Task Definition — awsvpc network mode, 256 CPU / 512 MB, nginx demo
  container, logs to CloudWatch
- ECS Service — 2 tasks in private subnets, assign_public_ip = false,
  registered to the ALB target group
- Security groups — ALB accepts port 80 from the internet; ECS tasks accept
  traffic only from the ALB security group (tasks are not directly reachable)
- IAM — task execution role scoped to the AWS-managed
  AmazonECSTaskExecutionRolePolicy (image pull + log writes)

## Verification

Hitting the ALB URL returns the nginx demo page. Refreshing alternates between
the two tasks, showing different private IPs in different AZs — proof the load
balancer is distributing across both Availability Zones:

    Server address: 10.20.11.156:80   (us-east-1a)
    Server address: 10.20.12.202:80   (us-east-1b)

If one AZ's task fails, the ALB routes all traffic to the surviving task —
high availability by design.

## Security model

- Containers run in private subnets with no public IP; the only ingress path
  is through the ALB.
- The ECS security group references the ALB security group as its ingress
  source, so nothing but the load balancer can reach the tasks.
- Outbound from tasks goes through the NAT gateway, not a direct internet route.

## Stack

AWS ECS · Fargate · Application Load Balancer · VPC · NAT Gateway ·
CloudWatch Logs · IAM · Terraform

## Notes from the build

This lab was built and debugged live over a mobile hotspot, and the CI/CD
pipeline took several iterations to go green. The failures were instructive and
worth recording:

- **Non-breaking spaces in JSON.** Pasting `taskdef.json` through the terminal
  introduced non-breaking spaces (U+00A0, bytes `\xc2\xa0`) in place of regular
  spaces in the indentation. JSON parsers reject these, and the error
  ("Expecting property name enclosed in double quotes: line 2 column 1") points
  at the wrong cause. Diagnosed by dumping the raw bytes with
  `python3 -c "print(repr(open('taskdef.json','rb').read()[:60]))"` and stripping
  `\xc2\xa0` back to normal spaces.

- **sed vs. jq for JSON templating.** The first pipeline used `sed` to inject the
  image URI into the task definition. Because the ECR URI contains `/` and `:`,
  string substitution produced invalid JSON. Switched to `jq --arg`, which
  manipulates JSON structurally and cannot corrupt it.

- **Merge tangles in the workflow file.** A git pull merged two versions of
  `deploy.yml` instead of replacing it, leaving duplicate steps and orphaned
  fragments. Resolved by overwriting the file wholesale rather than editing into
  the conflict.

- **AWS CLI exit codes.** Exit 252 is parameter validation (malformed input);
  exit 5 is an API-level error (permissions or resource). Reading the code
  narrowed each failure to the right layer before touching the fix.

The lesson underneath all of them: validate inputs at the boundary. The pipeline
now validates JSON (`jq empty`) before registering the task definition, and
checks the task-definition ARN is non-empty before updating the service — so a
bad input fails loudly at the step that caused it, not three steps later.
