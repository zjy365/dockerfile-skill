# Docker 到 Sealos 转换映射指南

本文档提供 Docker Compose 配置到 Sealos 模板的详细映射规则。

## 双源输入归并（Compose + 官方 Kubernetes）

当应用同时提供 Docker Compose 与官方 Kubernetes 安装方案时，转换必须采用双源归并而非单源推断。

### 归并原则

1. Sealos 规范与 SKILL MUST 规则优先（安全/平台约束不可破坏）
2. 官方 Kubernetes 安装方案优先于 Compose 的应用运行语义
3. Compose 作为服务拓扑与依赖的基线
4. 通用默认值仅在上述来源缺失时使用

### 重点对齐字段

- 首次初始化与管理员引导字段（bootstrap admin/org/user/password）
- 外部访问相关字段（domain/port/secure/tls termination assumption）
- 协议与网关行为（Ingress backend protocol、service appProtocol、path routing）
- 健康检查与启动顺序（liveness/readiness/startup probe）
- 官方推荐的启动参数与命令

### 冲突处理

当官方 Kubernetes 方案与 Compose 冲突时：

- 保留 Sealos MUST 与安全规则
- 其余应用行为默认对齐官方 Kubernetes 方案
- 在输出中记录关键决策（仅记录存在歧义的项）

## 核心概念映射

### Docker Compose Service → Sealos Resources

Docker Compose 中的一个 service 需要转换为多个 Sealos 资源：

```yaml
# Docker Compose
services:
  app:
    image: myapp:1.0.0
    ports:
      - "3000:3000"
    volumes:
      - ./data:/app/data
    environment:
      - DB_HOST=postgres
```

转换为：

```yaml
# Sealos Template
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${{ defaults.app_name }}

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: ${{ defaults.app_name }}
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}

---
# Ingress (如果需要公网访问)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${{ defaults.app_name }}
```

## 镜像映射

⚠️ 示例镜像必须使用固定版本，优先精确版本 tag（如 `v2.2.0`）；仅在无法确定稳定版本 tag 时使用 digest。禁止使用 `:latest`。
⚠️ 禁止在最终模板中保留 Compose 变量镜像表达式（如 `${IMAGE}`, `${IMAGE:-ghcr.io/example/app}`），必须在转换阶段解析为具体镜像引用。

### Docker Compose
```yaml
services:
  app:
    image: nginx:1.27.2
    # 或
    build: ./app
```

### Sealos Template
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    originImageName: nginx:1.27.2  # 必须添加
spec:
  revisionHistoryLimit: 1
  template:
    spec:
      automountServiceAccountToken: false
      containers:
        - name: ${{ defaults.app_name }}
          image: nginx:1.27.2
          imagePullPolicy: IfNotPresent  # 必须设置
```

## 端口映射

### Docker Compose
```yaml
services:
  app:
    ports:
      - "3000:3000"
      - "8080:80"
```

> Sealos 网关默认在 Ingress 层终止 TLS。若 Compose 同时暴露 `80` 与 `443`，且业务服务不是“必须后端 HTTPS”，转换时应优先保留 HTTP 端口并移除 `443`，同时不再挂载容器内证书目录（例如 `/etc/nginx/ssl`、`/etc/ssl`、`/certs`）。

### Sealos Template

#### 容器端口配置
```yaml
spec:
  revisionHistoryLimit: 1
  template:
    spec:
      automountServiceAccountToken: false
      containers:
        - name: ${{ defaults.app_name }}
          ports:
            - containerPort: 3000
            - containerPort: 80
```

#### Service 配置
```yaml
apiVersion: v1
kind: Service
metadata:
  name: ${{ defaults.app_name }}
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}
spec:
  ports:
    - name: tcp-3000
      port: 3000
      targetPort: 3000
    - name: tcp-8080
      port: 8080
      targetPort: 80
  selector:
    app: ${{ defaults.app_name }}
```

#### Ingress 配置（公网访问）
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${{ defaults.app_name }}
  labels:
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
                  number: 3000
  tls:
    - hosts:
        - ${{ defaults.app_host }}.${{ SEALOS_CLOUD_DOMAIN }}
      secretName: ${{ SEALOS_CERT_SECRET_NAME }}
```

#### TLS Offload 归一化（80/443 双端口场景）

```yaml
# Docker Compose
services:
  app:
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - certs:/etc/nginx/ssl

# 转换后（Sealos）
# - workload/service 仅保留 80
# - Ingress 继续使用平台证书
# - /etc/nginx/ssl 不再转换为 PVC 挂载
```

## 环境变量映射

### Docker Compose
```yaml
services:
  app:
    environment:
      - NODE_ENV=production
      - API_KEY=secret123
      - DB_HOST=postgres
```

### Sealos Template

#### 普通环境变量
```yaml
spec:
  revisionHistoryLimit: 1
  template:
    spec:
      automountServiceAccountToken: false
      containers:
        - name: ${{ defaults.app_name }}
          env:
            - name: NODE_ENV
              value: production
```

#### 业务容器敏感值（非数据库连接字段）
```yaml
# Deployment
spec:
  template:
    spec:
      containers:
        - name: ${{ defaults.app_name }}
          env:
            - name: API_KEY
              value: ${{ defaults.api_key }}
```

说明：
- 非数据库连接字段的敏感值使用 `env[].value`（来自 `defaults` 或 `inputs`）。
- 数据库连接字段（`endpoint`/`host`/`port`/`username`/`password`）必须使用 `secretKeyRef`。
- 仅允许使用 Kubeblocks 数据库 Secret 与对象存储 Secret。

#### 引用数据库连接
```yaml
env:
  - name: DB_ENDPOINT
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: endpoint
  - name: DB_HOST
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
```

#### URL/DSN 变量组合（当 `endpoint` 仅为 `host:port` 时）
```yaml
env:
  - name: SEALOS_DATABASE_POSTGRES_HOST
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: host
  - name: SEALOS_DATABASE_POSTGRES_PORT
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: port
  - name: SEALOS_DATABASE_POSTGRES_USERNAME
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: username
  - name: SEALOS_DATABASE_POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: password
  - name: DATABASE_URL
    value: postgres://$(SEALOS_DATABASE_POSTGRES_USERNAME):$(SEALOS_DATABASE_POSTGRES_PASSWORD)@$(SEALOS_DATABASE_POSTGRES_HOST):$(SEALOS_DATABASE_POSTGRES_PORT)/postgres
```

说明：
- 仅在源值为 URL/DSN 且指向已识别数据库服务时使用此模式。
- `DATABASE_URL` 等 URL 字段允许通过 `$(VAR)` 引用由 approved DB `secretKeyRef` 注入的组件变量。
- 不允许引用非密钥来源变量拼装数据库 URL。

## 卷映射

### Docker Compose Volumes → Sealos VolumeClaimTemplates

⚠️ **重要**：Sealos 不支持 emptyDir，所有存储必须是持久化的。

#### Docker Compose
```yaml
services:
  app:
    volumes:
      - ./data:/app/data
      - ./config:/app/config
```

#### Sealos Template (使用 StatefulSet)
```yaml
apiVersion: apps/v1
kind: StatefulSet
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
            - name: vn-appvn-data
              mountPath: /app/data
            - name: vn-appvn-config
              mountPath: /app/config
  volumeClaimTemplates:
    - metadata:
        annotations:
          path: /app/data
          value: '1'
        name: vn-appvn-data
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
    - metadata:
        annotations:
          path: /app/config
          value: '1'
        name: vn-appvn-config
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
```

### Docker Compose ConfigMap → Sealos ConfigMap

#### Docker Compose
```yaml
services:
  nginx:
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
```

#### Sealos Template
```yaml
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${{ defaults.app_name }}
data:
  vn-etcvn-nginxvn-nginxvn-conf: |
    server {
      listen 80;
      ...
    }

---
# Deployment
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: ${{ defaults.app_name }}
          volumeMounts:
            - name: vn-etcvn-nginxvn-nginxvn-conf
              mountPath: /etc/nginx/nginx.conf
              subPath: ./etc/nginx/nginx.conf
      volumes:
        - name: vn-etcvn-nginxvn-nginxvn-conf
          configMap:
            name: ${{ defaults.app_name }}
            items:
              - key: vn-etcvn-nginxvn-nginxvn-conf
                path: ./etc/nginx/nginx.conf
            defaultMode: 420
```

## 数据库服务映射

### Docker Compose
```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - pgdata:/var/lib/postgresql/data
```

### Sealos Template

使用完整的 Kubeblocks Cluster 配置（参考 `database-templates.md`）：

```yaml
apiVersion: apps.kubeblocks.io/v1alpha1
kind: Cluster
metadata:
  name: ${{ defaults.app_name }}-pg
  labels:
    kb.io/database: postgresql-16.4.0
    clusterdefinition.kubeblocks.io/name: postgresql
    clusterversion.kubeblocks.io/name: postgresql-16.4.0
spec:
  clusterDefinitionRef: postgresql
  clusterVersionRef: postgresql-16.4.0
  # ... 完整配置见 database-templates.md
```

## 服务依赖映射

### Docker Compose
```yaml
services:
  app:
    depends_on:
      - postgres
      - redis
    environment:
      - DB_HOST=postgres
      - REDIS_HOST=redis
```

### Sealos Template

#### 服务间通信使用 FQDN
```yaml
env:
  - name: DB_HOST
    value: ${{ defaults.app_name }}-pg-postgresql.${{ SEALOS_NAMESPACE }}.svc.cluster.local
  - name: REDIS_HOST
    value: ${{ defaults.app_name }}-redis-redis.${{ SEALOS_NAMESPACE }}.svc.cluster.local
```

#### 或使用 Secret
```yaml
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: ${{ defaults.app_name }}-pg-conn-credential
        key: password
  - name: DB_URL
    value: postgresql://postgres:$(POSTGRES_PASSWORD)@${{ defaults.app_name }}-pg-postgresql.${{ SEALOS_NAMESPACE }}.svc:5432/mydb
```

## 资源限制映射

### Docker Compose
```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### Sealos Template
```yaml
spec:
  template:
    spec:
      containers:
        - name: ${{ defaults.app_name }}
          resources:
            limits:
              cpu: 1000m
              memory: 1024Mi
            requests:
              cpu: 500m
              memory: 512Mi
```

## 健康检查映射

转换优先级：
1. Docker Compose 存在 `healthcheck` 时，转换为 `livenessProbe` + `readinessProbe`
2. Compose 未提供但官方文档明确给出健康端点/命令时，仍必须生成 `livenessProbe` + `readinessProbe`
3. 对首次启动较慢的应用（如需要初始化数据库），必须额外生成 `startupProbe`，避免启动期被过早判定失败

### Docker Compose
```yaml
services:
  app:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 官方健康检查示例（authentik）
```yaml
containers:
  - image: ghcr.io/goauthentik/server:2025.12.3
    imagePullPolicy: IfNotPresent
    startupProbe:
      httpGet:
        path: /-/health/ready/
        port: 9000
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 90
    livenessProbe:
      httpGet:
        path: /-/health/live/
        port: 9000
    readinessProbe:
      httpGet:
        path: /-/health/ready/
        port: 9000
```

### Sealos Template
```yaml
spec:
  template:
    spec:
      containers:
        - name: ${{ defaults.app_name }}
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 30
            timeoutSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
```

## 命令和参数映射

### Docker Compose
```yaml
services:
  app:
    command: ["npm", "start"]
    # 或
    entrypoint: /app/start.sh
    command: arg1 arg2
```

### Sealos Template
```yaml
spec:
  template:
    spec:
      containers:
        - name: ${{ defaults.app_name }}
          command: ["npm", "start"]
          # 或
          command: ["/app/start.sh"]
          args: ["arg1", "arg2"]
```

## 网络模式映射

### 内置边缘网关（Traefik）处理

当 Compose 同时包含 Traefik 与业务服务时，优先使用 Sealos 平台 Ingress 能力，不保留 Traefik 作为模板内工作负载。

处理规则：

- 若服务名或镜像可识别为 Traefik，且存在至少一个非数据库业务服务，则跳过 Traefik 资源生成。
- 主访问入口指向业务服务（通常为首个业务服务）的 Service，由 Sealos Ingress 暴露公网域名。
- 仅当应用服务里只有 Traefik（不存在其他业务服务）时，才保留 Traefik 作为回退行为，避免生成空工作负载。

动机：

- 避免双层网关（Traefik + Sealos Ingress）引入额外转发复杂度。
- 减少端口、路由与 TLS 配置漂移风险，使模板更贴合 Sealos 平台能力。

### Docker Compose
```yaml
services:
  app:
    network_mode: host
    # 或
    ports:
      - "3000:3000"
```

### Sealos Template

Sealos 不支持 host 网络模式，全部使用 Service + Ingress：

```yaml
# Service (集群内访问)
apiVersion: v1
kind: Service
metadata:
  name: ${{ defaults.app_name }}
  labels:
    app: ${{ defaults.app_name }}
    cloud.sealos.io/app-deploy-manager: ${{ defaults.app_name }}
spec:
  ports:
    - name: tcp-3000
      port: 3000
  selector:
    app: ${{ defaults.app_name }}

---
# Ingress (公网访问)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${{ defaults.app_name }}
  labels:
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
                  number: 3000
```

## 对象存储映射

### Docker Compose (使用 Minio)
```yaml
services:
  minio:
    image: minio/minio
    command: server /data
    volumes:
      - minio-data:/data
```

### Sealos Template
```yaml
apiVersion: objectstorage.sealos.io/v1
kind: ObjectStorageBucket
metadata:
  name: ${{ defaults.app_name }}
spec:
  policy: private

---
# 应用中使用对象存储
spec:
  template:
    spec:
      containers:
        - name: ${{ defaults.app_name }}
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
```

## 常见模式总结

### 单容器应用
- Docker Service → Deployment + Service + Ingress

### 多容器应用
- 每个 Docker Service → 独立的 Deployment + Service
- 主应用使用 `${{ defaults.app_name }}`
- 其他组件使用 `${{ defaults.app_name }}-<component>`

### 数据库服务
- Docker postgres/mysql/mongo/redis → Kubeblocks Cluster + ServiceAccount + Role + RoleBinding

### 持久化存储
- Docker volumes → StatefulSet + volumeClaimTemplates

### 配置文件
- Docker config files → ConfigMap (使用 vn- 命名规则)

### 敏感信息
- Docker business env vars → `env[].value` (`defaults`/`inputs`)
