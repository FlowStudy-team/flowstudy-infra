-- Document management tables
-- Creates document categories, folders, and documents for the document center

use flowstudy;

CREATE TABLE IF NOT EXISTS fs_document_category (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '分类ID',
    name VARCHAR(64) NOT NULL COMMENT '分类名称',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    UNIQUE KEY uk_fs_document_category_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文档分类表';

INSERT IGNORE INTO fs_document_category (id, name) VALUES
    (1, '算法笔记'),
    (2, '后端开发'),
    (3, '前端开发');

CREATE TABLE IF NOT EXISTS fs_document_folder (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '文件夹ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    name VARCHAR(128) NOT NULL COMMENT '文件夹名称',
    parent_id BIGINT DEFAULT NULL COMMENT '父文件夹ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    KEY idx_fs_document_folder_user_id (user_id),
    KEY idx_fs_document_folder_parent_id (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文档文件夹表';

CREATE TABLE IF NOT EXISTS fs_document (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '文档ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    title VARCHAR(255) NOT NULL COMMENT '文档标题',
    content MEDIUMTEXT COMMENT '文档内容',
    summary VARCHAR(512) DEFAULT NULL COMMENT '文档摘要',
    folder_id BIGINT DEFAULT NULL COMMENT '文件夹ID',
    category_id BIGINT DEFAULT NULL COMMENT '分类ID',
    tags VARCHAR(512) DEFAULT NULL COMMENT '标签，逗号分隔',
    status VARCHAR(32) NOT NULL DEFAULT 'draft' COMMENT '状态：draft/private/published/archived',
    published_at DATETIME DEFAULT NULL COMMENT '发布时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除',
    KEY idx_fs_document_user_id (user_id),
    KEY idx_fs_document_folder_id (folder_id),
    KEY idx_fs_document_category_id (category_id),
    KEY idx_fs_document_status (status),
    KEY idx_fs_document_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文档表';
