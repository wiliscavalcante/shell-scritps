output_file="recursos_a_alterar.txt"

# Limpar arquivo de saída
> $output_file

# Listar Auto Scaling Groups com a tag
ASGS=$(aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[?contains(Tags[?Key==`MinhaChave`].Key, `MinhaChave`)].AutoScalingGroupName' --output text)
echo "ASGs com a tag 'MinhaChave':" >> $output_file
for asg in $ASGS; do
  echo $asg >> $output_file
done

# Listar instâncias EC2 com a tag
INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:MinhaChave,Values=*" --query 'Reservations[*].Instances[*].InstanceId' --output text)
echo "\nInstâncias EC2 com a tag 'MinhaChave':" >> $output_file
for instance in $INSTANCES; do
  echo $instance >> $output_file
done

cat $output_file

# Pedir confirmação
read -p "Você deseja remover a tag 'MinhaChave' dos recursos listados no arquivo '$output_file'? (s/n) " -n 1 -r
echo
if [[ $REPLY == s || $REPLY == S ]]
then
    for asg in $ASGS; do
      aws autoscaling delete-tags --tags "ResourceId=$asg,ResourceType=auto-scaling-group,Key=MinhaChave"
    done

    for instance in $INSTANCES; do
      aws ec2 delete-tags --resources $instance --tags "Key=MinhaChave"
    done
fi
