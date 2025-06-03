# 01-ssm - AWS Systems Manager エージェントセットアップ

このディレクトリには、自宅サーバーにAWS Systems Manager (SSM) エージェントをインストールし、AWSから管理できるようにするためのTerraformとAnsibleコードが含まれています。

## 概要

AWS Systems Managerを使用することで、自宅サーバーを以下のように管理できます。

- リモートからのコマンド実行
- Session Managerによるリモート接続
- パッチ管理とシステム更新
- インベントリ収集
- パラメータストアからの設定取得

## ファイル構成

### Terraform
- `terraform/main.tf`: SSMに必要なAWSリソース（IAMロール、アクティベーション、KMSキー）を作成

### Ansible
- `ssm_register.yml`: SSMエージェントのインストールと登録
- `ssm_config_deploy.yml`: SSMエージェント設定ファイルのデプロイ
- `ssm_uninstall.yml`: SSMエージェントのアンインストール
- `amazon-ssm-agent.json.template`: SSMエージェント設定テンプレート
- `inventory.ini`: 管理対象サーバーの定義ファイル
- `group_vars/all.yml`: クレデンシャル情報の定義ファイル

## セットアップ手順

### 1. Terraformでの AWS リソース作成

```bash
cd terraform/
terraform init
terraform apply
```

このコマンドにより以下のリソースが作成されます：
- IAMロール（SSMエージェント用）
- SSMアクティベーション（最大6台のサーバー登録可能）
- KMSキー（通信暗号化用）

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
AWS認証情報とサーバー接続情報を設定：
```bash
mkdir group_vars
cat << EOF > group_vars/all.yml
---
# AWS設定
aws_region: "ap-northeast-1"
ssm_activation_code: "XXXXXXXXXXXXXXXXXX"  # Terraformのoutputから取得
ssm_activation_id: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"  # Terraformのoutputから取得

# サーバー接続設定
ansible_user: user  # サーバーのユーザー名
ansible_ssh_private_key_file: ~/.ssh/key_name  # SSH秘密鍵のパス
ansible_become_pass: password  # sudoパスワード
EOF
```

### 3. SSMエージェントのインストールと登録

```bash
ansible-playbook -i inventory.ini ssm_register.yml -v
```

このプレイブックは以下を実行します：
1. SSMセットアップCLIのダウンロード
2. SSMエージェントのインストール
3. AWSへのサーバー登録

### 4. SSMエージェント設定のデプロイ

```bash
ansible-playbook -i inventory.ini ssm_config_deploy.yml -v
```

このプレイブックは設定ファイルをデプロイし、SSMエージェントを再起動します。

### 5. Advanced Instance Tierの有効化（オプション）

高度な機能（Session Manager、パッチ管理など）を使用する場合：

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=ap-northeast-1

aws ssm update-service-setting \
    --setting-id "arn:aws:ssm:$REGION:$ACCOUNT_ID:servicesetting/ssm/managed-instance/activation-tier" \
    --setting-value advanced
```

**注意**: Advanced Tierは追加料金が発生します。

## セットアップの確認

### アクティベーション状態の確認
```bash
aws ssm describe-activations \
  --filters FilterKey=DefaultInstanceName,FilterValues=ssm-agent-homeserver-activation
```

### 登録済みインスタンスの確認
```bash
aws ssm describe-instance-information
```

登録されたサーバーがオンライン状態で表示されることを確認してください。

## 使用例

### リモートコマンド実行
AWS コンソールまたはCLIから、登録されたサーバーに対してコマンドを実行できます：

```bash
aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --document-version "1" \
    --targets "Key=instanceids,Values=mi-XXXXXXXXXXXXXXXXX" \
    --parameters "commands='hostname'" \
    --query Command.CommandId;
```

### Session Manager接続
Session Managerで、SSHキーなしでサーバーにセキュアに接続できます。

```bash
aws ssm start-session --target mi-XXXXXXXXXXXXXXXXX;
```

## クリーンアップ

### 1. 管理対象インスタンスの登録解除

```bash
aws ssm describe-instance-information \
  --query "InstanceInformationList[].InstanceId" \
  --output text | \
  tr '\t' '\n' | grep '^mi-' | \
  xargs -n1 -I{} aws ssm deregister-managed-instance --instance-id {}
```

### 2. Instance Tierを標準に戻す

```bash
aws ssm update-service-setting \
    --setting-id "arn:aws:ssm:$REGION:$ACCOUNT_ID:servicesetting/ssm/managed-instance/activation-tier" \
    --setting-value standard
```

### 3. SSMエージェントのアンインストール

```bash
ansible-playbook -i inventory.ini ssm_uninstall.yml -v
```

### 4. AWSリソースの削除

```bash
cd terraform/
terraform destroy
```
