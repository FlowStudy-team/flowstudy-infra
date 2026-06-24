-- FlowStudy migration: article/chapter -> tutorial/blog
-- MySQL version: 5.7.24+
--
-- Target model:
--   fs_tutorial: tutorial/course container
--   fs_blog: readable blog post; tutorial_id is nullable for standalone blogs
--
-- Run after backing up the database:
--   mysqldump -uroot -p flowstudy > flowstudy_backup_before_tutorial_blog.sql
--   mysql -uroot -p flowstudy < mysql/migration/20260621-article-chapter-to-tutorial-blog.sql

SET @OLD_CHARACTER_SET_CLIENT = @@CHARACTER_SET_CLIENT;
SET @OLD_CHARACTER_SET_RESULTS = @@CHARACTER_SET_RESULTS;
SET @OLD_COLLATION_CONNECTION = @@COLLATION_CONNECTION;
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET @OLD_SQL_MODE = @@SQL_MODE;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET FOREIGN_KEY_CHECKS = 0;
SET SESSION SQL_MODE = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE TABLE IF NOT EXISTS fs_tutorial (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '教程ID',
    title VARCHAR(255) NOT NULL COMMENT '教程标题',
    summary VARCHAR(512) DEFAULT NULL COMMENT '教程摘要',
    cover_url VARCHAR(512) DEFAULT NULL COMMENT '封面URL',
    author_id BIGINT DEFAULT NULL COMMENT '作者ID，对应sys_user.id',
    status VARCHAR(32) NOT NULL DEFAULT 'DRAFT' COMMENT '状态：DRAFT/PUBLISHED/OFFLINE',
    view_count BIGINT NOT NULL DEFAULT 0 COMMENT '浏览次数',
    like_count BIGINT NOT NULL DEFAULT 0 COMMENT '点赞次数',
    sort_order INT NOT NULL DEFAULT 0 COMMENT '排序值，越小越靠前',
    published_at DATETIME DEFAULT NULL COMMENT '发布时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    KEY idx_fs_tutorial_author_id (author_id),
    KEY idx_fs_tutorial_status (status),
    KEY idx_fs_tutorial_sort_order (sort_order),
    KEY idx_fs_tutorial_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='教程表';

CREATE TABLE IF NOT EXISTS fs_blog (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '博客ID',
    tutorial_id BIGINT DEFAULT NULL COMMENT '所属教程ID，NULL表示独立博客',
    title VARCHAR(255) NOT NULL COMMENT '博客标题',
    content_md MEDIUMTEXT NOT NULL COMMENT 'Markdown正文',
    summary VARCHAR(512) DEFAULT NULL COMMENT '博客摘要',
    cover_url VARCHAR(512) DEFAULT NULL COMMENT '封面URL',
    author_id BIGINT DEFAULT NULL COMMENT '作者ID，对应sys_user.id',
    sort_order INT NOT NULL DEFAULT 0 COMMENT '教程内排序值',
    estimated_minutes INT DEFAULT NULL COMMENT '预计阅读分钟数',
    status VARCHAR(32) NOT NULL DEFAULT 'PUBLISHED' COMMENT '状态：DRAFT/PUBLISHED/OFFLINE',
    view_count BIGINT NOT NULL DEFAULT 0 COMMENT '浏览次数',
    like_count BIGINT NOT NULL DEFAULT 0 COMMENT '点赞次数',
    published_at DATETIME DEFAULT NULL COMMENT '发布时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    KEY idx_fs_blog_tutorial_id (tutorial_id),
    KEY idx_fs_blog_author_id (author_id),
    KEY idx_fs_blog_status (status),
    KEY idx_fs_blog_sort_order (sort_order),
    KEY idx_fs_blog_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='博客表';

INSERT IGNORE INTO fs_tutorial (
    id, title, summary, cover_url, author_id, status,
    view_count, like_count, sort_order, published_at,
    created_at, updated_at, deleted
)
SELECT
    id, title, summary, cover_url, author_id, status,
    view_count, like_count, sort_order, published_at,
    created_at, updated_at, deleted
FROM fs_article;

INSERT IGNORE INTO fs_blog (
    id, tutorial_id, title, content_md, sort_order,
    estimated_minutes, status, created_at, updated_at, deleted
)
SELECT
    id, article_id, title, content_md, sort_order,
    estimated_minutes, status, created_at, updated_at, deleted
FROM fs_chapter;

ALTER TABLE fs_problem
    DROP INDEX idx_fs_problem_chapter_id,
    CHANGE chapter_id blog_id BIGINT NOT NULL COMMENT '所属博客ID',
    ADD KEY idx_fs_problem_blog_id (blog_id);

ALTER TABLE fs_behavior_event
    DROP INDEX idx_fs_behavior_article_chapter,
    CHANGE article_id tutorial_id BIGINT DEFAULT NULL COMMENT '教程ID',
    CHANGE chapter_id blog_id BIGINT DEFAULT NULL COMMENT '博客ID',
    ADD KEY idx_fs_behavior_tutorial_blog (tutorial_id, blog_id);

ALTER TABLE fs_ai_conversation
    DROP INDEX idx_fs_ai_conversation_context,
    CHANGE article_id tutorial_id BIGINT DEFAULT NULL COMMENT '关联教程ID',
    CHANGE chapter_id blog_id BIGINT DEFAULT NULL COMMENT '关联博客ID',
    ADD KEY idx_fs_ai_conversation_context (tutorial_id, blog_id, problem_id);

ALTER TABLE fs_learning_note
    DROP INDEX idx_fs_learning_note_article_chapter,
    CHANGE article_id tutorial_id BIGINT DEFAULT NULL COMMENT '教程ID',
    CHANGE chapter_id blog_id BIGINT DEFAULT NULL COMMENT '博客ID',
    ADD KEY idx_fs_learning_note_tutorial_blog (tutorial_id, blog_id);

-- Keep old data tables as legacy backups. Drop them manually after application
-- code has been fully switched to fs_tutorial/fs_blog and data is verified.
RENAME TABLE fs_article TO fs_article_legacy;
RENAME TABLE fs_chapter TO fs_chapter_legacy;

SET SESSION SQL_MODE = @OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;
SET CHARACTER_SET_CLIENT = @OLD_CHARACTER_SET_CLIENT;
SET CHARACTER_SET_RESULTS = @OLD_CHARACTER_SET_RESULTS;
SET COLLATION_CONNECTION = @OLD_COLLATION_CONNECTION;
