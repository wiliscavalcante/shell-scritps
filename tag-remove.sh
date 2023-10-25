#!/bin/bash

TAG_NAME="MinhaChave"
REGION="us-west-1" # Modifique para sua região desejada
output_file="recursos_a_alterar.txt"

# Limpar arquivo de saída
> $output_file

# Listar Auto Scaling Groups com a tag
ASGS=$(aws autoscaling describe-auto-scaling-groups --region $REGION --query "AutoScalingGroups[?contains(Tags[?Key==\`${TAG_NAME}\`].Key, \`${TAG_NAME}\`)].AutoScalingGroupName" --output text)
echo "ASGs com a tag '$TAG_NAME':" >> $output_file
for asg in $ASGS; do
  echo $asg >> $output_file
done

# Listar instâncias EC2 com a tag
INSTANCES=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:$TAG_NAME,Values=*" --query 'Reservations[*].Instances[*].InstanceId' --output text)
echo "\nInstâncias EC2 com a tag '$TAG_NAME':" >> $output_file
for instance in $INSTANCES; do
  echo $instance >> $output_file
done

cat $output_file

# Pedir confirmação
read -p "Você deseja remover a tag '$TAG_NAME' dos recursos listados no arquivo '$output_file'? (s/n) " -n 1 -r
echo
if [[ $REPLY == s || $REPLY == S ]]
then
    for asg in $ASGS; do
      aws autoscaling delete-tags --region $REGION --tags "ResourceId=$asg,ResourceType=auto-scaling-group,Key=$TAG_NAME"
    done

    for instance in $INSTANCES; do
      aws ec2 delete-tags --resources $instance --tags "Key=$TAG_NAME" --region $REGION
    done
fi


#######
aws ec2 create-tags --resources i-1234567890abcdef0 --tags Key=NomeDaTag,Value=ValorDaTag
aws autoscaling create-or-update-tags --tags ResourceId=my-asg-name,ResourceType=auto-scaling-group,Key=NomeDaTag,Value=ValorDaTag,PropagateAtLaunch=true
