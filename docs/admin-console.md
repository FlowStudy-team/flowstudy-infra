# FlowStudy 管理面

## 权限

管理接口统一使用 `/api/v1/admin/**`，必须携带管理员 JWT。Core 通过 Spring Security 校验 `ROLE_ADMIN`；普通用户返回 `40300`，未登录返回 `40100`。

## 功能

- 运营概览：用户、内容、订单和待审核数量。
- 用户管理：查询、启用/禁用、USER/ADMIN 角色调整、管理员发券。
- 内容管理：博客、教程、题目查询及发布、下线。
- 商城管理：会员 Token 商品、库存、定时活动、优惠券。
- 订单管理：模拟支付订单查询和状态查看；支付接口预留适配层，当前不接第三方支付。
- 操作审计：记录管理员的状态、角色、内容和商城操作。

## 数据库

新环境执行 `mysql/init/01-init.sql`；已有环境执行：

```bash
mysql -u flowstudy -p flowstudy < mysql/migration/20260823-admin-console.sql
```

迁移脚本会创建 `fs_admin_audit_log`，并以 MySQL 5.7 兼容方式补充用户角色/状态查询索引。

## 前端入口

拥有 `ADMIN` 角色的账号登录后，在顶部导航进入 `/admin`。管理端页面不保存额外的管理员凭证，复用现有 JWT。
