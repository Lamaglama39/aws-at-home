# 01-ssm



## Usage

### Terraform

```
cd terraform/;
terraform init;
terraform apply;
```

### Ansible

```
cd ansible/;
```

```
cat << EOF > ansible/inventory.ini
---
[home_servers]
server-name-01 ansible_host=XXX.XXX.XXX.XXX
server-name-02 ansible_host=XXX.XXX.XXX.XXX
server-name-03 ansible_host=XXX.XXX.XXX.XXX
EOF
```

```
mkdir ansible/group_vars;
cat << EOF > ansible/group_vars/all.yml;
---
aws_region: "ap-northeast-1"
ssm_activation_code: "XXXXXXXXXXXXXXXXXX"
ssm_activation_id: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
EOF
```

```
cat << EOF > ansible/group_vars/home_servers.yml;
---
ansible_user: user
ansible_ssh_private_key_file: ~/.ssh/key_name
ansible_become_pass: password
EOF
```

```
ansible -i inventory.ini home_servers -m ping;
```
```
ansible-playbook -i inventory.ini ssm_register.yml -v;
```

```
ansible-playbook -i inventory.ini ssm_config_deploy.yml -v
```

### Enable Advanced Instance

```
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=ap-northeast-1
```
```
aws ssm update-service-setting \
    --setting-id "arn:aws:ssm:$REGION:$ACCOUNT_ID:servicesetting/ssm/managed-instance/activation-tier" \
    --setting-value advanced
```

## Clean Up



