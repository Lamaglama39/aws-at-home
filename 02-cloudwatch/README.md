# 02-cloudwatch - AWS CloudWatch エージェントセットアップ

このディレクトリには、自宅サーバーにAWS CloudWatch エージェントをインストールし、メトリクスとログをAWS CloudWatchに送信するためのTerraformとAnsibleコードが含まれています。

## 概要

AWS CloudWatchエージェントを使用することで、自宅サーバーの以下の情報を収集できます。

- システムメトリクス（CPU、メモリ、ディスク使用率など）
- ログファイルの収集（/var/log/messagesなど）
- CloudWatchアラームによる監視

## ファイル構成

### Terraform
- `terraform/main.tf`: CloudWatchエージェント用のAWSリソース（IAMユーザー、アクセスキー、SSMパラメータ、CloudWatch Alarm）を作成
- `terraform/alarm.tf`: CloudWatch Alarm を作成
- `terraform/amazon-cloudwatch-agent.json`: CloudWatchエージェントの設定ファイル

### Ansible
- `aws_credentials_setup.yml`: CloudWatchエージェント用のクレデンシャル設定
- `aws_credentials_remove.yml`: CloudWatchエージェント用のクレデンシャル削除
- `inventory.ini`: 管理対象サーバーの定義ファイル
- `group_vars/all.yml`: クレデンシャル情報の定義ファイル

## 前提条件

- AWS SSMエージェントが既にインストール・設定済みであること（01-ssmディレクトリの手順を完了）
- サーバーがSSM管理下にあること

## セットアップ手順

### 1. Terraformでの AWS リソース作成

CloudWatchエージェント用のリソースを作成：

```bash
cd terraform/
terraform init
terraform apply
```

このコマンドにより以下のリソースが作成されます：
- IAMユーザー（CloudWatchエージェント専用）
- アクセスキー（メトリクス送信用）
- SSMパラメータ（CloudWatchエージェント設定の保存）
- CloudWatch Alarm (メトリクス監視用)

作成されたリソース情報を確認：
```bash
terraform output -json
```

### 2. Ansible設定

```bash
cd ansible/
```

#### インベントリファイルの作成
管理対象サーバーの情報を設定：
```bash
cat << EOF > inventory.ini
[home_servers]
server-name-01 ansible_host=XXX.XXX.XXX.XXX
server-name-02 ansible_host=XXX.XXX.XXX.XXX
server-name-03 ansible_host=XXX.XXX.XXX.XXX
EOF
```

#### 設定変数ファイルの作成
AWSクレデンシャル情報とサーバー接続情報を設定：
```bash
mkdir group_vars
cat << EOF > group_vars/all.yml
---
# AWSクレデンシャル情報
aws_region: "ap-northeast-1"
iam_user_access_key_id: "XXXXXXXXXXX"  # TerraformのoutputからIAMアクセスキーIDを取得
iam_user_access_key_secret: "XXXXXXXXXXX"  # TerraformのoutputからIAMシークレットアクセスキーを取得

# サーバー接続設定
ansible_user: user  # サーバーのユーザー名
ansible_ssh_private_key_file: ~/.ssh/key_name  # SSH秘密鍵のパス
ansible_become_pass: password  # sudoパスワード
EOF
```

### 3. CloudWatchエージェント用クレデンシャルの設定

```bash
ansible-playbook -i inventory.ini aws_credentials_setup.yml -v
```

このプレイブックは以下を実行します：
1. `/root/.aws`ディレクトリの作成
2. CloudWatchエージェント用のクレデンシャルを`/root/.aws/credentials`に追加

### 4. CloudWatchエージェントのインストール

SSM Run Commandを使用してCloudWatchエージェントをインストール：

```bash
aws ssm send-command \
  --document-name "AWS-ConfigureAWSPackage" \
  --comment "Install CloudWatch Agent" \
  --targets "Key=InstanceIds,Values=$(aws ssm describe-instance-information \
    --query "join(',', InstanceInformationList[?starts_with(InstanceId, 'mi-')].InstanceId)" \
    --output text)" \
  --parameters '{"action":["Install"],"name":["AmazonCloudWatchAgent"],"version":["latest"]}' \
  --region ap-northeast-1
```

インストール状況の確認：
```bash
aws ssm list-command-invocations \
  --command-id XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX \
  --output json | jq -r '.CommandInvocations[] | "\(.InstanceId)\t\(.Status)"'
```

### 5. CloudWatchエージェントの設定

SSMパラメータストアの設定を使用してCloudWatchエージェントを設定：

```bash
aws ssm send-command \
  --document-name "AmazonCloudWatch-ManageAgent" \
  --comment "Configure CloudWatch Agent with predefined config" \
  --targets "Key=InstanceIds,Values=$(aws ssm describe-instance-information \
    --query "join(',', InstanceInformationList[?starts_with(InstanceId, 'mi-')].InstanceId)" \
    --output text)" \
  --parameters '{
    "action": ["configure"],
    "mode": ["onPremise"],
    "optionalConfigurationSource": ["ssm"],
    "optionalConfigurationLocation": ["AmazonCloudWatch-HomeServer-Config"]
  }' \
  --region ap-northeast-1
```

設定状況の確認：
```bash
aws ssm list-command-invocations \
  --command-id XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX \
  --output json | jq -r '.CommandInvocations[] | "\(.InstanceId)\t\(.Status)"'
```

## 収集される情報

### メトリクス
- **CPU使用率**: idle、iowait、steal、guest、user、system
- **メモリ使用量**: used、cached、total
- **ディスク使用率**: 使用率（%）
- **ディスクI/O**: read/write bytes、read/write回数、I/O時間

### ログ
- **ログストリーム名**: `{hostname}`（サーバー名別に分類）
- **システムログ**: `/var/log/messages`

### CLIでのリソース確認
```bash
# メトリクス一覧の取得
aws cloudwatch list-metrics --namespace CWAgent

# 特定メトリクスの取得例（CPU使用率）
aws cloudwatch get-metric-statistics \
  --namespace CWAgent \
  --metric-name cpu_usage_active \
  --dimensions Name=InstanceId,Value=mi-XXXXXXXXXXXXXXXXX \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## クリーンアップ

### 1. CloudWatchエージェントのアンインストール

```bash
aws ssm send-command \
  --document-name "AWS-ConfigureAWSPackage" \
  --comment "Uninstall CloudWatch Agent" \
  --targets "Key=InstanceIds,Values=$(aws ssm describe-instance-information \
    --query "join(',', InstanceInformationList[?starts_with(InstanceId, 'mi-')].InstanceId)" \
    --output text)" \
  --parameters '{"action":["Uninstall"],"name":["AmazonCloudWatchAgent"],"version":["latest"]}' \
  --region ap-northeast-1
```

### 2. クレデンシャル情報の削除

```bash
ansible-playbook -i inventory.ini aws_credentials_remove.yml -v
```

### 3. AWSリソースの削除

```bash
cd terraform/
terraform destroy
```

### 4. CloudWatchデータの削除（オプション）

```bash
# ロググループの削除
aws logs delete-log-group --log-group-name /var/log/messages

# カスタムメトリクスは自動的に期限切れになるため手動削除不要
```
