aws elbv2 create-target-group \
  --name tg-eks-nlb-dr \
  --protocol HTTPS \
  --port 443 \
  --vpc-id vpc-xxxxxxxx \
  --target-type ip


aws elbv2 register-targets \
  --target-group-arn arn:aws:elasticloadbalancing:region:account-id:targetgroup/tg-eks-nlb-dr/xxxxxxxx \
  --targets Id=10.0.0.1,AvailabilityZone=us-east-1a Id=10.0.0.2,AvailabilityZone=us-east-1b Id=10.0.0.3,AvailabilityZone=us-east-1c
