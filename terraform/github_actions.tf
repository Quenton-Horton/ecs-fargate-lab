# ==============================================================================
# 1. GITHUB ACTIONS OIDC TRUST PROVIDER & ROLE IDENTITY
# ==============================================================================

# Establish trust with GitHub's OIDC Authority
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"] # Current GitHub OIDC Thumbprint
}

# The Target Role assumed programmatically by your GitHub Actions runner
resource "aws_iam_role" "ecs_fargate_lab_github_actions" {
  name = "ecs-fargate-lab-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Safely allows branch pushes and manual triggers while remaining fully secure
            "token.actions.githubusercontent.com:sub" = "repo:Quenton-Horton/ecs-fargate-lab:*"
          }
        }
      }
    ]
  })
}

# ==============================================================================
# 2. LEAST-PRIVILEGE PIPELINE EXECUTION POLICY
# ==============================================================================

resource "aws_iam_role_policy" "github_actions_least_privilege" {
  name = "ecs-fargate-lab-pipeline-policy"
  role = aws_iam_role.ecs_fargate_lab_github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Scope A: Amazon ECR Authentication & Registry Actions
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",  
          "ecr:PutImage"
        ]
        # Dynamic Account ID Parameterization
        Resource = "arn:aws:ecr:us-east-1:${data.aws_caller_identity.current.account_id}:repository/ecs-fargate-lab"
      },
        
      # Scope B: ECS Task Definition Lifecycle Operations
      {
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
         
      # Scope C: Secure IAM Role Passing (Prevents Privilege Escalation)
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        # Dynamic Account ID Parameterization
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecs-fargate-lab-task-execution-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecs-fargate-lab-task-role"
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }, 
      
      # Scope D: Target Cluster & Service Deployment Control
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        # Dynamic Account ID Parameterization
        Resource = "arn:aws:ecs:us-east-1:${data.aws_caller_identity.current.account_id}:service/ecs-fargate-lab-cluster/ecs-fargate-lab-service"
      }  
    ]    
  })
}

