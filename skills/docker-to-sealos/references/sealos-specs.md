# Sealos 模板开发规范

## 模板文件组织规范

### 目录结构要求

所有模板必须按照以下目录结构组织：

```
templates/
└── template/
    └── <template-name>/    # 文件夹名称必须与模板的 name 字段一致
        └── index.yaml       # 模板文件必须命名为 index.yaml
```

### 示例

```
templates/
└── template/
    ├── formbricks/
    │   └── index.yaml      # formbricks 模板文件
    ├── langflow/
    │   └── index.yaml      # langflow 模板文件
    └── fastgpt/
        └── index.yaml      # fastgpt 模板文件
```

### 命名规则

1. 文件夹名称必须与模板 Template CR 中的 `metadata.name` 字段保持一致
2. 模板文件必须命名为 `index.yaml`
3. 文件夹名称应该使用小写字母和连字符，避免使用下划线或其他特殊字符
4. **Template CR 的 `metadata.name` 必须硬编码为小写字母**，不能使用变量（如 `${{ defaults.app_name }}`）

### 示例

```yaml
# 正确示例
apiVersion: app.sealos.io/v1
kind: Template
metadata:
  name: typesense  # ✅ 硬编码的小写名称
spec:
  defaults:
    app_name:
      type: string
      value: typesense-${{ random(8) }}  # ✅ 这里可以用变量

# 错误示例
metadata:
  name: ${{ defaults.app_name }}  # ❌ 错误：不能使用变量
```

## 资源创建顺序规范

模板内各个资源必须按照以下顺序创建：

### 1. Template CR
首先创建 Template 元数据定义

### 2. 对象存储
```yaml
apiVersion: objectstorage.sealos.io/v1
kind: ObjectStorageBucket
```

### 3. 数据库资源
数据库各资源按以下顺序创建：
1. **ServiceAccount**
2. **Role**
3. **RoleBinding**
4. **Cluster** (实际的数据库实例)
5. **Job** (如果需要初始化数据库)

### 4. 应用资源
应用各资源按以下顺序创建：
1. **ConfigMap** (应用配置文件)
2. **Deployment/StatefulSet** (主应用)
3. **Service**
4. **Ingress**
5. **App**

### 示例结构
```
Template CR
---
ObjectStorageBucket
---
Redis ServiceAccount
---
Redis Role
---
Redis RoleBinding
---
Redis Cluster
---
PostgreSQL ServiceAccount
---
PostgreSQL Role
---
PostgreSQL RoleBinding
---
PostgreSQL Cluster
---
PostgreSQL Init Job
---
Application StatefulSet
---
Application Service
---
Application Ingress
---
App
```

## Defaults 和 Inputs 配置规范

### 基本原则

**重要区分：**
- `defaults`：用于存放**自动生成**的值（如随机字符串、随机端口等）
- `inputs`：用于存放**需要用户输入**的值（如邮箱、API Key、自定义配置等）

### Defaults 配置

`defaults` 中的值会在模板解析时自动生成，不需要用户交互：

```yaml
defaults:
  app_host:
    type: string
    value: typesense-${{ random(8) }}  # ✅ 带应用名称前缀
  app_name:
    type: string
    value: typesense-${{ random(8) }}  # ✅ 应用名称
  api_key:
    type: string
    value: ${{ random(32) }}           # ✅ 随机生成的密钥
```

**注意事项：**
1. `app_host` 必须带应用名称前缀（如 `typesense-${{ random(8) }}`）
2. `app_name` 必须包含 `${{ random(8) }}` 以确保唯一性
3. 随机生成的配置（密钥、密码等）放在 `defaults` 中，不要放在 `inputs` 中

### Inputs 配置

`inputs` 中的值需要用户在部署时填写：

```yaml
inputs:
  admin_email:
    description: 'Administrator email address'
    type: string
    default: ''
    required: true
  enable_feature_x:
    description: 'Enable advanced feature X'
    type: boolean
    default: 'false'
    required: false
```

**何时使用 inputs：**
- ✅ 用户的邮箱地址
- ✅ 自定义域名
- ✅ 外部服务的 API Key（需要用户提供）
- ✅ 功能开关（启用/禁用某些特性）
- ❌ 随机生成的密钥（应该放在 defaults）
- ❌ 自动生成的配置（应该放在 defaults）

## 国际化（i18n）配置

### 基本格式

模板需要添加 `locale` 和 `i18n` 配置来支持多语言：

```yaml
spec:
  locale: en  # 默认语言
  i18n:
    zh:
      description: '中文描述'
```

### 配置示例

```yaml
apiVersion: app.sealos.io/v1
kind: Template
metadata:
  name: example
spec:
  title: 'Example App'
  description: 'An example application for demonstration'
  locale: en
  i18n:
    zh:
      description: '一个用于演示的示例应用程序'
```

### 支持的字段

i18n 配置支持以下字段的翻译：
- `description` - 应用描述

### 注意事项

1. `locale` 指定默认语言，通常设置为 `en`
2. 目前只支持 `zh`（中文）翻译
3. `i18n.zh.description` 应使用简体中文
4. 技术性的字段名称和默认值不需要翻译
5. 如果中文标题与 `spec.title` 一致，建议省略 `i18n.zh.title`

## Categories 类别限制

在创建 Sealos 模板时，`categories` 字段不能自定义，必须从以下预定义的选项中选择：

- `tool` - 工具类应用
- `ai` - AI/机器学习相关应用
- `game` - 游戏类应用
- `database` - 数据库类应用
- `low-code` - 低代码平台
- `monitor` - 监控类应用
- `dev-ops` - DevOps 工具
- `blog` - 博客/内容管理系统
- `storage` - 存储类应用
- `frontend` - 前端类应用
- `backend` - 后端类应用

### 示例
```yaml
categories:
  - storage  # 正确：使用预定义的类别
  - tool     # 正确：可以选择多个类别
  # - media  # 错误：不在允许的列表中
```

## 存储规范

### emptyDir 限制（重要！）

**⚠️ Sealos 不支持 emptyDir！** 所有需要临时存储的场景都必须转换为持久化存储。

**❌ 错误示例：**
```yaml
volumes:
  - name: config-storage
    emptyDir: {}  # 错误！Sealos 不支持 emptyDir
```

**✅ 正确做法：**
- 对于 StatefulSet：使用 `volumeClaimTemplates` 创建持久化存储
- 对于 Deployment：考虑是否真的需要存储，如果需要则改用 StatefulSet
- 对于临时配置：考虑使用 ConfigMap 或 Secret

### PersistentVolumeClaim 使用限制

存储不能单独创建 PersistentVolumeClaim，必须在 Deployment 或者 StatefulSet 中使用 `volumeClaimTemplates` 字段。

### volumeClaimTemplates 格式

```yaml
volumeClaimTemplates:
  - metadata:
      annotations:
        path: /var/lib/headscale  # 挂载路径
        value: '1'                 # 固定值
      name: vn-varvn-libvn-headscale  # 名称规则见下方
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
```

### 命名规则

`metadata.name` 将复用 `metadata.annotations.path` 的值，并将特殊字符替换为 "vn-"：
- `/` 替换为 `vn-`
- `-` 替换为 `vn-`
- 其他特殊字符也替换为 `vn-`

例如：
- `/var/lib/headscale` → `vn-varvn-libvn-headscale`
- `/usr/src/app/upload` → `vn-usrvn-srcvn-appvn-upload`
- `/cache` → `vn-cache`

## ConfigMap 配置规范

### 命名规则

ConfigMap 的名称必须和挂载该 ConfigMap 的应用的 `metadata.name` 值一样

### 文件存储规则（极其重要！！！）

**⚠️ 重要提醒：ConfigMap 的 data 字段中的所有键名（key）必须严格遵循 vn- 转换规则！**

所有配置文件都应该放到同一个 ConfigMap 中，ConfigMap 中的 `data.<文件名>` 键名**必须**将挂载路径中的特殊字符替换为 "vn-"：

**转换规则：**
- 将路径中的 `/` 替换为 `vn-`
- 将路径中的 `-` 替换为 `vn-`
- 将路径中的 `.` 替换为 `vn-`
- 其他特殊字符也替换为 `vn-`

**❌ 错误示例（绝对不要这样写）：**
```yaml
data:
  inifile: |  # 错误！没有使用 vn- 转换
    content here
  chart.ini: | # 错误！包含点号
    content here
```

**✅ 正确示例：**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${{ defaults.app_name }}
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}
data:
  # 原路径: /etc/nginx/conf.d/default.conf
  # 转换后: vn-etcvn-nginxvn-confvn-dvn-defaultvn-conf
  vn-etcvn-nginxvn-confvn-dvn-defaultvn-conf: |
    server {
      listen 80;
      ...
    }
  # 原路径: /tmp/chart.ini
  # 转换后: vn-tmpvn-chartvn-ini
  vn-tmpvn-chartvn-ini: |
    [cluster]
    seedlist = example
```

### Volume 挂载规范

#### Volumes 格式

```yaml
volumes:
  - name: vn-etcvn-nginxvn-confvn-dvn-defaultvn-conf
    configMap:
      name: ${{ defaults.app_name }}
      items:
        - key: vn-etcvn-nginxvn-confvn-dvn-defaultvn-conf
          path: ./etc/nginx/conf.d/default.conf
      defaultMode: 420
```

#### VolumeMount 格式

```yaml
volumeMounts:
  - name: vn-etcvn-nginxvn-confvn-dvn-defaultvn-conf
    mountPath: /etc/nginx/conf.d/default.conf
    subPath: ./etc/nginx/conf.d/default.conf
```

### 完整示例

```yaml
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${{ defaults.app_name }}
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}
data:
  vn-etcvn-nginxvn-confvn-dvn-defaultvn-conf: |
    server {
      listen 80;
      server_name localhost;
      location / {
        root /usr/share/nginx/html;
        index index.html;
      }
    }
  vn-appvn-configvn-ymlvn-: |
    database:
      host: localhost
      port: 5432

---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${{ defaults.app_name }}
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}
spec:
  revisionHistoryLimit: 1
  template:
    spec:
      automountServiceAccountToken: false
      containers:
        - name: ${{ defaults.app_name }}
          volumeMounts:
            - name: vn-etcvn-nginxvn-confvn-dvn-defaultvn-conf
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: ./etc/nginx/conf.d/default.conf
            - name: vn-appvn-configvn-ymlvn-
              mountPath: /app/config.yml
              subPath: ./app/config.yml
      volumes:
        - name: vn-etcvn-nginxvn-confvn-dvn-defaultvn-conf
          configMap:
            name: ${{ defaults.app_name }}
            items:
              - key: vn-etcvn-nginxvn-confvn-dvn-defaultvn-conf
                path: ./etc/nginx/conf.d/default.conf
            defaultMode: 420
        - name: vn-appvn-configvn-ymlvn-
          configMap:
            name: ${{ defaults.app_name }}
            items:
              - key: vn-appvn-configvn-ymlvn-
                path: ./app/config.yml
            defaultMode: 420
```

## 标签和命名规范

### app-deploy-manager 标签规则

1. 应用工作负载（Deployment/StatefulSet/DaemonSet）必须包含 `metadata.labels.app`，且值必须和资源的 `metadata.name` 保持一致
2. `cloud.sealos.io/app-deploy-manager` 的值必须和资源的 `metadata.name` 的值保持一致
3. 每个模板的主应用（提供公网端口的前端应用）的 `metadata.name` 必须是 `${{ defaults.app_name }}`
4. 其他组件的命名应该基于 `${{ defaults.app_name }}` 加上组件标识，例如：
   - `${{ defaults.app_name }}-server` 
   - `${{ defaults.app_name }}-ml`
   - `${{ defaults.app_name }}-redis`
5. 应用 Service 必须包含 `metadata.labels.app` 和 `metadata.labels.cloud.sealos.io/app-deploy-manager`，且 `metadata.name`、两个标签以及 `spec.selector.app` 必须完全一致
6. 组件级 ConfigMap 必须包含 `metadata.labels.app` 和 `metadata.labels.cloud.sealos.io/app-deploy-manager`，且二者都必须与 `metadata.name` 保持一致
7. 应用 Ingress 的 `metadata.name` 必须与 `metadata.labels.cloud.sealos.io/app-deploy-manager` 以及 backend `service.name` 保持一致

### 容器命名规则

`containers.name` 的名称必须和 `metadata.name` 的值保持一致。

```yaml
# 正确示例
metadata:
  name: ${{ defaults.app_name }}
spec:
  template:
    spec:
      containers:
        - name: ${{ defaults.app_name }}  # 必须与 metadata.name 一致

# 子组件的正确示例
metadata:
  name: ${{ defaults.app_name }}-ml
spec:
  template:
    spec:
      containers:
        - name: ${{ defaults.app_name }}-ml  # 必须与 metadata.name 一致
```

### 示例

```yaml
# 主应用（正确）
metadata:
  name: ${{ defaults.app_name }}
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}

# 子组件（正确）
metadata:
  name: ${{ defaults.app_name }}-ml
  labels:
    app: ${{ defaults.app_name }}-ml
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}-ml

# 错误示例
metadata:
  name: ${{ defaults.app_name }}-server
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}  # 错误：标签值与name不一致
```

### 特殊情况：数据库资源

数据库资源（通过 kubeblocks 创建的 Cluster）使用特殊的标签 `sealos-db-provider-cr` 而不是 `cloud.sealos.io/app-deploy-manager`：

```yaml
# 数据库资源的正确标签
metadata:
  name: ${{ defaults.app_name }}-redis
  labels:
    sealos-db-provider-cr: ${{ defaults.app_name }}-redis
```

## 对象存储配置

### 环境变量设置

对象存储的环境变量配置必须遵循以下格式：

```yaml
env:
  - name: S3_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: object-storage-key
        key: accessKey
  - name: S3_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: object-storage-key
        key: secretKey
  - name: S3_BUCKET
    valueFrom:
      secretKeyRef:
        name: object-storage-key-${{ SEALOS_SERVICE_ACCOUNT }}-${{ defaults.app_name }}
        key: bucket
  - name: S3_ENDPOINT
    value: "https://$(BACKEND_STORAGE_MINIO_EXTERNAL_ENDPOINT)"
  - name: BACKEND_STORAGE_MINIO_EXTERNAL_ENDPOINT
    valueFrom:
      secretKeyRef:
        name: object-storage-key
        key: external
  - name: S3_PUBLIC_DOMAIN
    value: "https://$(BACKEND_STORAGE_MINIO_EXTERNAL_ENDPOINT)"
  - name: S3_ENABLE_PATH_STYLE
    value: "1"
```

### 注意事项

1. `object-storage-key` 是固定的 secret 名称（不包含应用名称）
2. 只有 bucket 的 secret 名称包含应用名称：`object-storage-key-${{ SEALOS_SERVICE_ACCOUNT }}-${{ defaults.app_name }}`
3. S3_ENDPOINT 和 S3_PUBLIC_DOMAIN 使用环境变量引用：`$(BACKEND_STORAGE_MINIO_EXTERNAL_ENDPOINT)`
4. S3_ENABLE_PATH_STYLE 必须设置为 "1"

## Ingress 配置规范

### 标准格式

Ingress 必须使用以下格式：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${{ defaults.app_name }}
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager-domain: ${{ defaults.app_host }}
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: 32m
    nginx.ingress.kubernetes.io/server-snippet: |
      client_header_buffer_size 64k;
      large_client_header_buffers 4 128k;
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/backend-protocol: HTTP
    nginx.ingress.kubernetes.io/client-body-buffer-size: 64k
    nginx.ingress.kubernetes.io/proxy-buffer-size: 64k
    nginx.ingress.kubernetes.io/proxy-send-timeout: '300'
    nginx.ingress.kubernetes.io/proxy-read-timeout: '300'
    nginx.ingress.kubernetes.io/configuration-snippet: |
      if ($request_uri ~* \.(js|css|gif|jpe?g|png)) {
        expires 30d;
        add_header Cache-Control "public";
      }
spec:
  rules:
    - host: ${{ defaults.app_host }}.${{ SEALOS_CLOUD_DOMAIN }}
      http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              service:
                name: ${{ defaults.app_name }}
                port:
                  number: <端口号>
  tls:
    - hosts:
        - ${{ defaults.app_host }}.${{ SEALOS_CLOUD_DOMAIN }}
      secretName: ${{ SEALOS_CERT_SECRET_NAME }}
```

### 注意事项

1. `metadata.name` 必须是 `${{ defaults.app_name }}`
2. 必须包含 `cloud.sealos.io/app-deploy-manager-domain` 标签
3. `ssl-redirect` 默认为 `'true'`
4. 包含静态资源缓存的 configuration-snippet
5. backend service name 必须是 `${{ defaults.app_name }}`

## 数据库连接配置

### PostgreSQL 环境变量

PostgreSQL 的所有环境变量都从 kubeblocks 自动创建的 secret 中获取。Secret 名称格式为：`${{ defaults.app_name }}-pg-conn-credential`

Secret 包含以下 keys：
- `endpoint`: 完整的连接端点（host:port）
- `host`: 主机名
- `password`: 密码
- `port`: 端口号
- `username`: 用户名（通常是 postgres）

### 使用示例

```yaml
env:
  # 使用 host 和 port 分别配置
  - name: DB_HOSTNAME
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: host
  - name: DB_PORT
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: port
  - name: DB_USERNAME
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: username
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: password
  
  # 或者使用 endpoint 直接获取 host:port
  - name: DB_ENDPOINT
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: endpoint
```

### 其他数据库

其他数据库（Redis、MySQL、MongoDB）也遵循类似的模式：
- Redis: `${{ defaults.app_name }}-redis-account-default`
- MySQL: `${{ defaults.app_name }}-mysql-conn-credential`
- MongoDB: `${{ defaults.app_name }}-mongodb-account-root`

### PostgreSQL 数据库初始化

PostgreSQL 默认不会创建数据库，如果应用需要自定义数据库（而不是使用默认的 postgres 数据库），必须通过 Job 来创建。

**重要规范：**
- 数据库名称应该使用应用的默认值，不应该作为用户输入参数
- 数据库名称应该与应用名称相关，通常使用应用的简称或标识符
- 例如：langflow 应用使用 'langflow' 数据库，fastgpt 应用使用 'fastgpt' 数据库

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ${{ defaults.app_name }}-pg-init
spec:
  backoffLimit: 3
  template:
    spec:
      containers:
        - name: pgsql-init
          image: postgres:16-alpine
          imagePullPolicy: IfNotPresent
          env:
            - name: PG_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${{ defaults.app_name }}-pg-conn-credential
                  key: password
            - name: PG_ENDPOINT
              valueFrom:
                secretKeyRef:
                  name: ${{ defaults.app_name }}-pg-conn-credential
                  key: endpoint
            - name: PG_DATABASE
              value: langflow
          command:
            - /bin/sh
            - -c
            - |
              set -eu
              for i in $(seq 1 60); do
                if pg_isready -h "${PG_ENDPOINT%:*}" -p "${PG_ENDPOINT##*:}" -U postgres -d postgres >/dev/null 2>&1; then
                  break
                fi
                sleep 2
              done
              pg_isready -h "${PG_ENDPOINT%:*}" -p "${PG_ENDPOINT##*:}" -U postgres -d postgres >/dev/null 2>&1
              if ! psql "postgresql://postgres:$(PG_PASSWORD)@$(PG_ENDPOINT)/postgres" -tAc "SELECT 1 FROM pg_database WHERE datname='$(PG_DATABASE)'" | grep -q 1; then
                psql "postgresql://postgres:$(PG_PASSWORD)@$(PG_ENDPOINT)/postgres" -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$(PG_DATABASE)\";"
              fi
      restartPolicy: OnFailure
  ttlSecondsAfterFinished: 300
```

**注意事项：**
1. Job 名称使用 `${{ defaults.app_name }}-pg-init` 格式
2. 使用 `postgres:16-alpine` 镜像以保持轻量
3. `ttlSecondsAfterFinished: 300` 确保 Job 完成后 5 分钟自动清理
4. 初始化脚本必须先等待 PostgreSQL 就绪（例如 `pg_isready`）
5. 初始化脚本必须幂等（先检查 `pg_database`，不存在才创建）
6. 数据库名称应该硬编码在模板中，使用应用的默认数据库名称（如上例中的 'langflow'）

## 应用配置规范

### 服务间通信规则

**重要**：服务之间相互引用必须使用全域名（FQDN），不能直接使用服务名。

全域名格式：`<service-name>.${{ SEALOS_NAMESPACE }}.svc.cluster.local`

```yaml
# 正确示例：使用全域名
env:
  - name: WORKER_URL
    value: http://${{ defaults.app_name }}-worker.${{ SEALOS_NAMESPACE }}.svc.cluster.local:4003
  - name: COUCH_DB_URL
    value: http://${{ defaults.app_name }}-svc-couchdb.${{ SEALOS_NAMESPACE }}.svc.cluster.local:5984
  - name: REDIS_URL
    value: redis://:$(REDIS_PASSWORD)@${{ defaults.app_name }}-redis-redis.${{ SEALOS_NAMESPACE }}.svc:6379

# 错误示例：直接使用服务名
# - name: WORKER_URL
#   value: http://worker-service:4003  # 错误：可能无法解析
```

注意：虽然 `.svc.cluster.local` 后缀在某些情况下可以省略（如上面 REDIS_URL 的例子），但为了保证跨命名空间的兼容性和明确性，建议始终包含完整的域名。

### 环境变量依赖顺序规则

**重要**：如果一个环境变量引用了另一个环境变量，被引用的变量必须定义在引用它的变量之前。

```yaml
env:
  # 正确示例：REDIS_PASSWORD 在前，REDIS_URL 在后
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-redis-account-default
        key: password
  - name: REDIS_URL
    value: redis://:$(REDIS_PASSWORD)@${{ defaults.app_name }}-redis.${{ SEALOS_NAMESPACE }}.svc:6379
  
  # 错误示例：如果 REDIS_URL 在 REDIS_PASSWORD 之前定义
  # - name: REDIS_URL
  #   value: redis://:$(REDIS_PASSWORD)@...  # 错误：REDIS_PASSWORD 未定义
  # - name: REDIS_PASSWORD
  #   valueFrom: ...
```

这是因为 Kubernetes 按照环境变量在 YAML 中的顺序进行解析，如果引用的变量还未定义，会导致引用失败。

### 必需的安全和资源管理配置

所有应用的 Deployment 或 StatefulSet 必须包含以下配置：

1. **automountServiceAccountToken**: 必须设置为 `false`，避免不必要的权限暴露
2. **revisionHistoryLimit**: 必须设置为 `1`，减少历史版本占用的资源
3. **metadata.annotations**: 必须包含以下注解：
   - `originImageName`: 原始镜像名称
   - `deploy.cloud.sealos.io/minReplicas`: 最小副本数，通常设置为 `'1'`
   - `deploy.cloud.sealos.io/maxReplicas`: 最大副本数，通常设置为 `'1'`

```yaml
apiVersion: apps/v1
kind: Deployment  # 或 StatefulSet
metadata:
  name: ${{ defaults.app_name }}
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}
  annotations:
    originImageName: example/app:1.0.0  # 必须：原始镜像名称
    deploy.cloud.sealos.io/minReplicas: '1'  # 必须：最小副本数
    deploy.cloud.sealos.io/maxReplicas: '1'  # 必须：最大副本数
spec:
  revisionHistoryLimit: 1  # 必须设置为 1
  template:
    spec:
      automountServiceAccountToken: false  # 必须设置为 false
      containers:
        - name: ${{ defaults.app_name }}
          # 其他容器配置...
```

### 完整示例

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${{ defaults.app_name }}
  annotations:
    originImageName: example/app:1.0.0
    deploy.cloud.sealos.io/minReplicas: '1'
    deploy.cloud.sealos.io/maxReplicas: '1'
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}
spec:
  revisionHistoryLimit: 1  # 保留历史版本数量限制为 1
  replicas: 1
  selector:
    matchLabels:
      app: ${{ defaults.app_name }}
  template:
    metadata:
      labels:
        app: ${{ defaults.app_name }}
    spec:
      automountServiceAccountToken: false  # 禁用服务账户令牌自动挂载
      containers:
        - name: ${{ defaults.app_name }}
          image: example/app:1.0.0
          imagePullPolicy: IfNotPresent
```

## 资源配额规范

### 资源限制配置

**⚠️ 重要：所有容器的 resources 字段必须包含 requests 和 limits！**

所有应用的 Deployment 或 StatefulSet 中的容器必须配置资源配额：

```yaml
containers:
  - name: ${{ defaults.app_name }}
    image: example/app:1.0.0
    imagePullPolicy: IfNotPresent
    resources:
      requests:
        cpu: 100m      # 最小 CPU 请求（必须）
        memory: 128Mi  # 最小内存请求（必须）
      limits:
        cpu: 500m      # CPU 上限（必须）
        memory: 512Mi  # 内存上限（必须）
```

**配额设置原则**：

1. **轻量级前端应用**（静态文件服务、简单 Web 应用）：
   ```yaml
   resources:
     requests:
       cpu: 20m
       memory: 25Mi
     limits:
       cpu: 200m
       memory: 256Mi
   ```

2. **标准后端应用**（API 服务、中等负载应用）：
   ```yaml
   resources:
     requests:
       cpu: 100m
       memory: 256Mi
     limits:
       cpu: 1000m
       memory: 1Gi
   ```

3. **重负载应用**（AI 处理、视频处理、大数据处理）：
   ```yaml
   resources:
     requests:
       cpu: 500m
       memory: 512Mi
     limits:
       cpu: 2000m
       memory: 2Gi
   ```

4. **AI/机器学习应用**（需要 GPU 或大量计算资源）：
   ```yaml
   resources:
     requests:
       cpu: 1000m
       memory: 1Gi
     limits:
       cpu: 4000m
       memory: 4Gi
   ```

**配额设置说明**：

- **requests（请求值）**：容器保证能获得的最小资源
  - CPU 使用 `m` 单位（1000m = 1 CPU 核心）
  - 内存使用 `Mi` 或 `Gi` 单位
  - 建议：requests 设置为实际使用量的 70-80%

- **limits（限制值）**：容器能使用的最大资源
  - CPU 可突发使用到 limit 值
  - 内存超过 limit 会被 OOM Kill
  - 建议：limits 设置为 requests 的 2-4 倍

**配额设置的黄金法则**：

1. **总是同时设置 requests 和 limits**
   - ❌ 只设置 requests：可能导致资源饥饿
   - ❌ 只设置 limits：可能导致调度失败
   - ✅ 两者都设置：保证性能和稳定性

2. **合理的 requests/limits 比例**
   - CPU: limits 可以是 requests 的 2-10 倍（CPU 可压缩）
   - 内存: limits 建议是 requests 的 1.5-2 倍（内存不可压缩）

3. **根据应用类型调整**
   - 计算密集型：提高 CPU 配额
   - 内存密集型：提高内存配额
   - I/O 密集型：平衡 CPU 和内存

4. **监控和调整**
   - 初次部署使用保守配额
   - 监控实际资源使用情况
   - 根据监控数据动态调整

**示例对比**：

```yaml
# ❌ 错误：没有资源限制
containers:
  - name: app
    image: app:1.0.0

# ❌ 错误：只有 requests
containers:
  - name: app
    image: app:1.0.0
    resources:
      requests:
        cpu: 100m
        memory: 128Mi

# ❌ 错误：只有 limits
containers:
  - name: app
    image: app:1.0.0
    resources:
      limits:
        cpu: 500m
        memory: 512Mi

# ✅ 正确：requests 和 limits 都有
containers:
  - name: app
    image: app:1.0.0
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

## 镜像配置规范

### 镜像拉取策略

所有容器的镜像拉取策略必须设置为 `IfNotPresent`：

```yaml
spec:
  template:
    spec:
      containers:
        - name: ${{ defaults.app_name }}
          image: example/app:1.0.0
          imagePullPolicy: IfNotPresent  # 必须使用 IfNotPresent
```

这样可以：
- 减少不必要的镜像拉取，提高部署速度
- 降低对镜像仓库的压力
- 节省网络带宽

## 其他注意事项

（待补充更多规范和最佳实践）
