<!--
 * @Author       : lastshrek
 * @Date         : 2026-03-27 11:47:28
 * @LastEditors  : lastshrek
 * @LastEditTime : 2026-03-27 14:22:40
 * @FilePath     : /Frontend-Integration-Guide.md
 * @Description  : 
 * Copyright 2026 lastshrek, All Rights Reserved.
 * 2026-03-27 11:47:28
-->
# 前端对接文档 - 登录/注册功能变更

## 一、接口变更汇总

| 接口                     | 方法 | 用途           | 变更说明                                      |
| ------------------------ | ---- | -------------- | --------------------------------------------- |
| `/users/register`        | POST | 用户注册       | 手机号已存在时返回400错误（不再自动更新密码） |
| `/users/login`           | POST | 用户登录       | 无变化                                        |
| `/users/reset-password`  | POST | 重置密码       | **新增**                                      |
| `/users/change-password` | POST | 修改密码       | **新增**                                      |
| `/users/init-passwords`  | POST | 批量初始化密码 | **新增**（仅管理员）                          |

---

## 二、接口详细说明

### 1. 用户注册（POST /users/register）

**请求参数：**

```json
{
  "phone": "13800138000",
  "password": "123456"
}
```

**成功响应（200）：**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "phone": "13800138000",
    "nickname": "",
    "avatar": null,
    "intro": "",
    "gender": ""
  }
}
```

**错误响应（400）：**

```json
{
  "message": "手机号已注册，请直接登录",
  "error": "Bad Request"
}
```

---

### 2. 用户登录（POST /users/login）

**请求参数：**

```json
{
  "phone": "13800138000",
  "password": "123456"
}
```

**成功响应（200）：**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": { ... }
}
```

**错误响应（401）：**

```json
{
  "message": "手机号或密码错误",
  "error": "Unauthorized"
}
```

---

### 3. 重置密码（POST /users/reset-password）

**请求参数：**

```json
{
  "phone": "13800138000",
  "password": "新密码"
}
```

**成功响应（200）：**

```json
"密码重置成功"
```

**错误响应（404）：**

```json
{
  "message": "用户不存在",
  "error": "Not Found"
}
```

---

### 4. 修改密码（POST /users/change-password）

**请求参数：**

```json
{
  "phone": "13800138000",
  "oldPassword": "旧密码",
  "newPassword": "新密码"
}
```

**成功响应（200）：**

```json
"密码修改成功"
```

**错误响应（401）：**

```json
{
  "message": "手机号或旧密码错误",
  "error": "Unauthorized"
}
```

---

## 三、老用户迁移方案

### 问题说明

老用户之前通过手机号+验证码登录，密码字段为 `null`，无法使用密码登录。

### 解决方案

**方案A：管理员批量处理（推荐）**

1. 后端调用 `POST /users/init-passwords` 设置默认密码（如"123456"）
2. 通知老用户默认密码，引导首次登录后修改

**方案B：用户自助重置**

1. 登录页引导老用户点击"忘记密码"
2. 调用 `POST /users/reset-password` 重置

---

## 四、前端页面改造建议

### 1. 登录页

- 保留手机号+密码登录表单
- 新增"忘记密码"入口 → 调用 reset-password

### 2. 注册页

- 手机号已存在时，提示"该手机号已注册，请直接登录"
- 禁止自动更新密码

### 3. 个人中心

- 新增"修改密码"入口 → 调用 change-password

---

## 五、安全与加密方案

### ⚠️ 重要：前端必须对密码进行 SHA256 预处理

**当前架构（2026-03-26更新）：**

- 前端：`SHA256(原始密码)` → 发送到后端
- 后端：`bcrypt(SHA256哈希值)` → 存储到数据库

**流程图：**

```
注册/登录流程：
┌─────────┐    SHA256    ┌─────────┐   bcrypt    ┌─────────┐
│ 原始密码 │ ──────────→ │ SHA256  │ ──────────→ │ bcrypt  │
└─────────┘    前端      └─────────┘    后端     └─────────┘
                           │                       │
                           └─────── 对比验证 ───────┘
```

### 前端实现（必须）

#### 1. Flutter端（Dart）

```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// SHA256 预哈希（登录/注册/修改密码时调用）
String hashPassword(String rawPassword) {
  return sha256.convert(utf8.encode(rawPassword)).toString();
}

// 使用示例
final hashedPassword = hashPassword('用户输入的密码');

// 调用接口
final response = await http.post(
  Uri.parse('$baseUrl/users/login'),
  body: jsonEncode({
    'phone': phone,
    'password': hashedPassword,  // ← 传入 SHA256 哈希值
  }),
);
```

#### 2. Web端（JavaScript/TypeScript）

```javascript
import CryptoJS from 'crypto-js';

/// SHA256 预哈希（登录/注册/修改密码时调用）
function hashPassword(rawPassword) {
  return CryptoJS.SHA256(rawPassword).toString();
}

// 使用示例
const hashedPassword = hashPassword('用户输入的密码');

// 调用接口
const response = await fetch('/users/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    phone,
    password: hashedPassword, // ← 传入 SHA256 哈希值
  }),
});
```

### 后端处理逻辑

```typescript
// 后端验证流程
1. 接收前端 SHA256 哈希值
2. 使用 bcrypt.compare(sha256Hash, storedHash) 验证
3. 如果是旧 MD5 格式密码，自动升级为 bcrypt
```

### 旧用户兼容说明

- 老用户使用 MD5 密码时，登录后自动升级为 bcrypt
- 前端始终使用 SHA256 预处理，无需区分新旧用户
- 后端自动处理兼容性

---

## 六、注意事项

1. **Token 管理**：JWT token 保存在本地，请求 Header 携带：

   ```
   Authorization: Bearer <token>
   ```

2. **Token 刷新**：token 过期后需重新登录，建议前端检测 401 状态码后跳转登录页

3. **错误处理**：统一展示响应 `message` 字段内容

4. **输入校验**：前端需验证手机号11位、密码非空

5. **HTTPS 必须**：生产环境强制 HTTPS，禁止明文传输密码

---

**文档版本**：1.1.0

**最后更新**：2026-03-26

**适用范围**：Flutter移动端 + Web端

**变更说明**：

- v1.1.0 (2026-03-26)：密码加密方案升级为前端SHA256 + 后端bcrypt
