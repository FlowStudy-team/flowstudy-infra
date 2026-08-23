-- FlowStudy membership, coupon and token quota store.
-- MySQL 5.7 compatible. Run after 01-init.sql.
USE flowstudy;

CREATE TABLE IF NOT EXISTS fs_membership_product (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(128) NOT NULL,
    description VARCHAR(512) DEFAULT NULL,
    price_cents INT NOT NULL,
    token_amount INT NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    sold_count INT NOT NULL DEFAULT 0,
    sale_start_at DATETIME DEFAULT NULL,
    sale_end_at DATETIME DEFAULT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    sort_order INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_fs_product_sale (status, sale_start_at, sale_end_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS fs_coupon (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(128) NOT NULL,
    coupon_type VARCHAR(16) NOT NULL DEFAULT 'FIXED',
    discount_cents INT NOT NULL,
    min_order_cents INT NOT NULL DEFAULT 0,
    total_count INT NOT NULL DEFAULT 0,
    claimed_count INT NOT NULL DEFAULT 0,
    start_at DATETIME NOT NULL,
    end_at DATETIME NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_fs_coupon_active (status, start_at, end_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS fs_user_coupon (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    coupon_id BIGINT NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'AVAILABLE',
    valid_until DATETIME NOT NULL,
    used_at DATETIME DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_fs_user_coupon (user_id, coupon_id),
    KEY idx_fs_user_coupon_available (user_id, status, valid_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS fs_membership_order (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_no VARCHAR(64) NOT NULL,
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    coupon_id BIGINT DEFAULT NULL,
    original_amount_cents INT NOT NULL,
    discount_amount_cents INT NOT NULL DEFAULT 0,
    payable_amount_cents INT NOT NULL,
    token_amount INT NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at DATETIME DEFAULT NULL,
    UNIQUE KEY uk_fs_order_no (order_no),
    KEY idx_fs_order_user_created (user_id, created_at),
    KEY idx_fs_order_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS fs_token_account (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    total_tokens INT NOT NULL DEFAULT 0,
    used_tokens INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_fs_token_account_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO fs_membership_product (id,name,description,price_cents,token_amount,stock,sale_start_at,sale_end_at,status,sort_order)
VALUES (1,'Starter Token Pack','适合体验 AI 学习助手',990,1000,9999,NULL,NULL,'ACTIVE',1),
       (2,'Pro Token Pack','适合持续使用 AI 学习和代码分析',2990,5000,1000,NULL,NULL,'ACTIVE',2),
       (3,'限时学习季礼包','定时会员价格秒杀活动，数量有限',9900,20000,100,'2026-01-01 00:00:00','2099-12-31 23:59:59','ACTIVE',3)
ON DUPLICATE KEY UPDATE name=VALUES(name),description=VALUES(description),price_cents=VALUES(price_cents),token_amount=VALUES(token_amount),status=VALUES(status);

INSERT INTO fs_coupon (id,name,coupon_type,discount_cents,min_order_cents,total_count,start_at,end_at,status)
VALUES (1,'新用户优惠券','FIXED',500,1990,10000,'2026-01-01 00:00:00','2099-12-31 23:59:59','ACTIVE')
ON DUPLICATE KEY UPDATE name=VALUES(name),discount_cents=VALUES(discount_cents),status=VALUES(status);
