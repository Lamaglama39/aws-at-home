# 01-ssm

## Usage

### Terraform

```
cd terraform/;
terraform init;
terraform apply;
```
```
terraform output -json;
```

### Ansible

```
cd ansible/;
```

```
cat << EOF > inventory.ini;
---
[home_servers]
server-name-01 ansible_host=XXX.XXX.XXX.XXX
server-name-02 ansible_host=XXX.XXX.XXX.XXX
server-name-03 ansible_host=XXX.XXX.XXX.XXX
EOF
```

```
mkdir group_vars;
cat << EOF > group_vars/all.yml;
---
# AWS Config
aws_region: "ap-northeast-1"
ssm_activation_code: "XXXXXXXXXXXXXXXXXX"
ssm_activation_id: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

# Home Server Credentials
ansible_user: user
ansible_ssh_private_key_file: ~/.ssh/key_name
ansible_become_pass: password
EOF
```

```
ansible-playbook -i inventory.ini ssm_register.yml -v;
```

```
ansible-playbook -i inventory.ini ssm_config_deploy.yml -v;
```

### Enable Advanced Instance Plan

```
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text);
REGION=ap-northeast-1;
```
```
aws ssm update-service-setting \
    --setting-id "arn:aws:ssm:$REGION:$ACCOUNT_ID:servicesetting/ssm/managed-instance/activation-tier" \
    --setting-value advanced;
```

## Clean Up

### Deregistering Managed Instance

```
aws ssm describe-instance-information \
  --query "InstanceInformationList[].InstanceId" \
  --output text | \
  tr '\t' '\n' | grep '^mi-' | \
  xargs -n1 -I{} aws ssm deregister-managed-instance --instance-id {};
```

### Instance Plan

```
aws ssm update-service-setting \
    --setting-id "arn:aws:ssm:$REGION:$ACCOUNT_ID:servicesetting/ssm/managed-instance/activation-tier" \
    --setting-value standard;
```

### Ansible

```
ansible-playbook -i inventory.ini ssm_uninstall.yml -v;
```

### Terraform

```
terraform destroy;
```
