-- FlowStudy MySQL initialization script
-- Recommended path: flowstudy-infra/mysql/init/01-init.sql
-- MySQL version: 8.0+

CREATE DATABASE IF NOT EXISTS flowstudy
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE flowstudy;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================================================
-- 1. System user table
-- =========================================================
CREATE TABLE IF NOT EXISTS sys_user (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '用户ID',
    username VARCHAR(64) NOT NULL COMMENT '用户名',
    email VARCHAR(128) DEFAULT NULL COMMENT '邮箱',
    password_hash VARCHAR(255) NOT NULL COMMENT '密码哈希，禁止明文存储',
    nickname VARCHAR(64) DEFAULT NULL COMMENT '昵称',
    avatar_url VARCHAR(512) DEFAULT NULL COMMENT '头像URL',
    role VARCHAR(32) NOT NULL DEFAULT 'USER' COMMENT '角色：USER/ADMIN',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态：1正常 0禁用',
    last_login_at DATETIME DEFAULT NULL COMMENT '最近登录时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    UNIQUE KEY uk_sys_user_username (username),
    UNIQUE KEY uk_sys_user_email (email),
    KEY idx_sys_user_role (role),
    KEY idx_sys_user_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- =========================================================
-- 2. Article table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_article (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '文章ID',
    title VARCHAR(255) NOT NULL COMMENT '文章标题',
    summary VARCHAR(512) DEFAULT NULL COMMENT '文章摘要',
    cover_url VARCHAR(512) DEFAULT NULL COMMENT '封面图URL',
    author_id BIGINT DEFAULT NULL COMMENT '作者ID，对应sys_user.id',
    status VARCHAR(32) NOT NULL DEFAULT 'DRAFT' COMMENT '状态：DRAFT/PUBLISHED/OFFLINE',
    view_count BIGINT NOT NULL DEFAULT 0 COMMENT '浏览次数',
    like_count BIGINT NOT NULL DEFAULT 0 COMMENT '点赞次数',
    sort_order INT NOT NULL DEFAULT 0 COMMENT '排序值，越小越靠前',
    published_at DATETIME DEFAULT NULL COMMENT '发布时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    KEY idx_fs_article_author_id (author_id),
    KEY idx_fs_article_status (status),
    KEY idx_fs_article_sort_order (sort_order),
    KEY idx_fs_article_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文章表';

-- =========================================================
-- 3. Chapter table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_chapter (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '章节ID',
    article_id BIGINT NOT NULL COMMENT '所属文章ID',
    title VARCHAR(255) NOT NULL COMMENT '章节标题',
    content_md MEDIUMTEXT NOT NULL COMMENT 'Markdown章节内容',
    sort_order INT NOT NULL DEFAULT 0 COMMENT '章节排序',
    estimated_minutes INT DEFAULT NULL COMMENT '预计学习分钟数',
    status VARCHAR(32) NOT NULL DEFAULT 'PUBLISHED' COMMENT '状态：DRAFT/PUBLISHED/OFFLINE',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    KEY idx_fs_chapter_article_id (article_id),
    KEY idx_fs_chapter_status (status),
    KEY idx_fs_chapter_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='章节表';

-- =========================================================
-- 4. Problem table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_problem (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '题目ID',
    chapter_id BIGINT NOT NULL COMMENT '所属章节ID',
    title VARCHAR(255) NOT NULL COMMENT '题目标题',
    description_md MEDIUMTEXT NOT NULL COMMENT 'Markdown题目描述',
    difficulty VARCHAR(32) NOT NULL DEFAULT 'EASY' COMMENT '难度：EASY/MEDIUM/HARD',
    input_description TEXT DEFAULT NULL COMMENT '输入说明',
    output_description TEXT DEFAULT NULL COMMENT '输出说明',
    support_languages VARCHAR(255) NOT NULL DEFAULT 'java,cpp,go,python' COMMENT '支持语言，逗号分隔',
    time_limit_ms INT NOT NULL DEFAULT 1000 COMMENT '时间限制，毫秒',
    memory_limit_mb INT NOT NULL DEFAULT 256 COMMENT '内存限制，MB',
    status VARCHAR(32) NOT NULL DEFAULT 'PUBLISHED' COMMENT '状态：DRAFT/PUBLISHED/OFFLINE',
    submit_count BIGINT NOT NULL DEFAULT 0 COMMENT '提交次数',
    accepted_count BIGINT NOT NULL DEFAULT 0 COMMENT '通过次数',
    sort_order INT NOT NULL DEFAULT 0 COMMENT '排序值',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    KEY idx_fs_problem_chapter_id (chapter_id),
    KEY idx_fs_problem_difficulty (difficulty),
    KEY idx_fs_problem_status (status),
    KEY idx_fs_problem_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='题目表';

-- =========================================================
-- 5. Problem testcase table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_problem_testcase (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '测试用例ID',
    problem_id BIGINT NOT NULL COMMENT '所属题目ID',
    input_text MEDIUMTEXT NOT NULL COMMENT '输入内容',
    expected_output MEDIUMTEXT NOT NULL COMMENT '期望输出',
    is_sample TINYINT NOT NULL DEFAULT 0 COMMENT '是否样例：1样例 0隐藏测试点',
    sort_order INT NOT NULL DEFAULT 0 COMMENT '测试点排序',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    KEY idx_fs_problem_testcase_problem_id (problem_id),
    KEY idx_fs_problem_testcase_sample (problem_id, is_sample),
    KEY idx_fs_problem_testcase_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='题目测试用例表';

-- =========================================================
-- 6. Code template table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_code_template (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '代码模板ID',
    problem_id BIGINT NOT NULL COMMENT '所属题目ID',
    language VARCHAR(32) NOT NULL COMMENT '语言：java/cpp/go/python',
    template_code MEDIUMTEXT NOT NULL COMMENT '代码模板',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    UNIQUE KEY uk_fs_code_template_problem_language (problem_id, language),
    KEY idx_fs_code_template_problem_id (problem_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='题目代码模板表';

-- =========================================================
-- 7. Submission table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_submission (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '提交ID',
    user_id BIGINT NOT NULL COMMENT '提交用户ID',
    problem_id BIGINT NOT NULL COMMENT '题目ID',
    language VARCHAR(32) NOT NULL COMMENT '提交语言',
    code MEDIUMTEXT NOT NULL COMMENT '提交代码',
    status VARCHAR(64) NOT NULL DEFAULT 'PENDING' COMMENT '判题状态',
    score INT NOT NULL DEFAULT 0 COMMENT '得分',
    time_used_ms INT DEFAULT NULL COMMENT '最大/总运行耗时，毫秒',
    memory_used_kb INT DEFAULT NULL COMMENT '最大内存占用，KB',
    compile_message MEDIUMTEXT DEFAULT NULL COMMENT '编译信息',
    runtime_message MEDIUMTEXT DEFAULT NULL COMMENT '运行错误信息',
    trace_id VARCHAR(64) DEFAULT NULL COMMENT '链路追踪ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    KEY idx_fs_submission_user_id (user_id),
    KEY idx_fs_submission_problem_id (problem_id),
    KEY idx_fs_submission_status (status),
    KEY idx_fs_submission_created_at (created_at),
    KEY idx_fs_submission_user_created (user_id, created_at),
    KEY idx_fs_submission_problem_created (problem_id, created_at),
    KEY idx_fs_submission_trace_id (trace_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='代码提交记录表';

-- =========================================================
-- 8. Judge case result table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_judge_case_result (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '测试点结果ID',
    submission_id BIGINT NOT NULL COMMENT '提交ID',
    testcase_id BIGINT DEFAULT NULL COMMENT '测试用例ID',
    case_index INT NOT NULL COMMENT '测试点序号，从1开始',
    status VARCHAR(64) NOT NULL COMMENT '测试点状态',
    time_used_ms INT DEFAULT NULL COMMENT '耗时，毫秒',
    memory_used_kb INT DEFAULT NULL COMMENT '内存，KB',
    actual_output MEDIUMTEXT DEFAULT NULL COMMENT '实际输出',
    expected_output MEDIUMTEXT DEFAULT NULL COMMENT '期望输出',
    error_message MEDIUMTEXT DEFAULT NULL COMMENT '错误信息',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    UNIQUE KEY uk_fs_judge_case_submission_index (submission_id, case_index),
    KEY idx_fs_judge_case_submission_id (submission_id),
    KEY idx_fs_judge_case_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='单测试点判题结果表';

-- =========================================================
-- 9. Behavior event table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_behavior_event (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '行为事件ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    article_id BIGINT DEFAULT NULL COMMENT '文章ID',
    chapter_id BIGINT DEFAULT NULL COMMENT '章节ID',
    problem_id BIGINT DEFAULT NULL COMMENT '题目ID',
    submission_id BIGINT DEFAULT NULL COMMENT '提交ID',
    event_type VARCHAR(64) NOT NULL COMMENT '事件类型',
    duration_seconds INT DEFAULT NULL COMMENT '停留时长，秒',
    extra_json JSON DEFAULT NULL COMMENT '扩展信息JSON',
    trace_id VARCHAR(64) DEFAULT NULL COMMENT '链路追踪ID',
    occurred_at DATETIME NOT NULL COMMENT '事件发生时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    KEY idx_fs_behavior_user_id (user_id),
    KEY idx_fs_behavior_event_type (event_type),
    KEY idx_fs_behavior_article_chapter (article_id, chapter_id),
    KEY idx_fs_behavior_problem_id (problem_id),
    KEY idx_fs_behavior_submission_id (submission_id),
    KEY idx_fs_behavior_occurred_at (occurred_at),
    KEY idx_fs_behavior_trace_id (trace_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户行为事件表';

-- =========================================================
-- 10. AI conversation table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_ai_conversation (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'AI会话ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    article_id BIGINT DEFAULT NULL COMMENT '关联文章ID',
    chapter_id BIGINT DEFAULT NULL COMMENT '关联章节ID',
    problem_id BIGINT DEFAULT NULL COMMENT '关联题目ID',
    title VARCHAR(255) DEFAULT NULL COMMENT '会话标题',
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE/ARCHIVED',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    KEY idx_fs_ai_conversation_user_id (user_id),
    KEY idx_fs_ai_conversation_context (article_id, chapter_id, problem_id),
    KEY idx_fs_ai_conversation_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI会话表';

-- =========================================================
-- 11. AI message table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_ai_message (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'AI消息ID',
    conversation_id BIGINT NOT NULL COMMENT '会话ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    role VARCHAR(32) NOT NULL COMMENT '角色：user/assistant/system',
    content MEDIUMTEXT NOT NULL COMMENT '消息内容',
    model_name VARCHAR(128) DEFAULT NULL COMMENT '模型名称',
    token_count INT DEFAULT NULL COMMENT 'Token数量',
    trace_id VARCHAR(64) DEFAULT NULL COMMENT '链路追踪ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    KEY idx_fs_ai_message_conversation_id (conversation_id),
    KEY idx_fs_ai_message_user_id (user_id),
    KEY idx_fs_ai_message_created_at (created_at),
    KEY idx_fs_ai_message_trace_id (trace_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI消息表';

-- =========================================================
-- 12. User profile table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_user_profile (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '画像ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    ability_json JSON DEFAULT NULL COMMENT '能力画像JSON',
    weak_points_json JSON DEFAULT NULL COMMENT '易错点JSON',
    coding_style_json JSON DEFAULT NULL COMMENT '代码风格JSON',
    summary_md MEDIUMTEXT DEFAULT NULL COMMENT '画像摘要Markdown',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    UNIQUE KEY uk_fs_user_profile_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户学习画像表';

-- =========================================================
-- 13. Learning note table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_learning_note (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '学习笔记ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    article_id BIGINT DEFAULT NULL COMMENT '文章ID',
    chapter_id BIGINT DEFAULT NULL COMMENT '章节ID',
    title VARCHAR(255) NOT NULL COMMENT '笔记标题',
    content_md MEDIUMTEXT NOT NULL COMMENT 'Markdown笔记内容',
    source VARCHAR(32) NOT NULL DEFAULT 'AI' COMMENT '来源：AI/MANUAL',
    status VARCHAR(32) NOT NULL DEFAULT 'GENERATED' COMMENT '状态：GENERATED/EDITED/ARCHIVED',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0未删除 1已删除',
    KEY idx_fs_learning_note_user_id (user_id),
    KEY idx_fs_learning_note_article_chapter (article_id, chapter_id),
    KEY idx_fs_learning_note_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='学习笔记表';

-- =========================================================
-- 14. MQ message log table
-- =========================================================
CREATE TABLE IF NOT EXISTS fs_mq_message_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'MQ消息日志ID',
    message_id VARCHAR(128) NOT NULL COMMENT '消息唯一ID，用于幂等',
    trace_id VARCHAR(64) DEFAULT NULL COMMENT '链路追踪ID',
    event_type VARCHAR(128) NOT NULL COMMENT '事件类型',
    producer VARCHAR(64) DEFAULT NULL COMMENT '生产者服务',
    consumer VARCHAR(64) DEFAULT NULL COMMENT '消费者服务',
    exchange_name VARCHAR(128) DEFAULT NULL COMMENT '交换机',
    routing_key VARCHAR(128) DEFAULT NULL COMMENT '路由键',
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING' COMMENT '状态：PENDING/PROCESSED/FAILED/IGNORED',
    retry_count INT NOT NULL DEFAULT 0 COMMENT '重试次数',
    error_message MEDIUMTEXT DEFAULT NULL COMMENT '错误信息',
    payload_json JSON DEFAULT NULL COMMENT '消息载荷快照',
    occurred_at DATETIME DEFAULT NULL COMMENT '消息发生时间',
    processed_at DATETIME DEFAULT NULL COMMENT '处理完成时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    UNIQUE KEY uk_fs_mq_message_log_message_id (message_id),
    KEY idx_fs_mq_message_log_trace_id (trace_id),
    KEY idx_fs_mq_message_log_event_type (event_type),
    KEY idx_fs_mq_message_log_status (status),
    KEY idx_fs_mq_message_log_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='MQ消息幂等与消费日志表';

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================================
-- Seed data for local development
-- Note: user seed data is intentionally not inserted because password_hash
-- should be generated by application BCrypt encoder during registration.
-- =========================================================

INSERT INTO fs_article (
    id, title, summary, cover_url, author_id, status, view_count, like_count, sort_order, published_at, deleted
) VALUES (
    1,
    'Java 并发编程入门',
    '从线程、线程池到并发任务调度，配合在线题目练习理解核心概念。',
    NULL,
    NULL,
    'PUBLISHED',
    0,
    0,
    1,
    NOW(),
    0
) ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    summary = VALUES(summary),
    status = VALUES(status),
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO fs_chapter (
    id, article_id, title, content_md, sort_order, estimated_minutes, status, deleted
) VALUES (
    1,
    1,
    '线程池的基本原理',
    '## 线程池的基本原理\n\n线程池用于复用线程、控制并发数量，并减少频繁创建线程带来的开销。\n\n本章节会结合一个简单任务调度题目，帮助你理解线程池的核心思想。',
    1,
    15,
    'PUBLISHED',
    0
) ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    content_md = VALUES(content_md),
    status = VALUES(status),
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO fs_problem (
    id, chapter_id, title, description_md, difficulty, input_description, output_description,
    support_languages, time_limit_ms, memory_limit_mb, status, sort_order, deleted
) VALUES (
    1,
    1,
    '两数之和',
    '## 题目描述\n\n给定一个整数数组 `nums` 和一个目标值 `target`，请你在该数组中找出和为目标值的两个整数下标。\n\n你可以假设每种输入只会对应一个答案，且同一个元素不能使用两次。',
    'EASY',
    '第一行输入整数 n；第二行输入 n 个整数；第三行输入 target。',
    '输出两个下标，使用空格分隔。',
    'java,cpp,go,python',
    1000,
    256,
    'PUBLISHED',
    1,
    0
) ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    description_md = VALUES(description_md),
    difficulty = VALUES(difficulty),
    status = VALUES(status),
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO fs_problem_testcase (
    id, problem_id, input_text, expected_output, is_sample, sort_order, deleted
) VALUES
    (1, 1, '4\n2 7 11 15\n9\n', '0 1\n', 1, 1, 0),
    (2, 1, '3\n3 2 4\n6\n', '1 2\n', 0, 2, 0)
ON DUPLICATE KEY UPDATE
    input_text = VALUES(input_text),
    expected_output = VALUES(expected_output),
    is_sample = VALUES(is_sample),
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO fs_code_template (
    problem_id, language, template_code, deleted
) VALUES
    (1, 'java', 'import java.util.*;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner sc = new Scanner(System.in);\n        // TODO: write your code here\n    }\n}\n', 0),
    (1, 'cpp', '#include <bits/stdc++.h>\nusing namespace std;\n\nint main() {\n    // TODO: write your code here\n    return 0;\n}\n', 0),
    (1, 'go', 'package main\n\nimport "fmt"\n\nfunc main() {\n    // TODO: write your code here\n    fmt.Println("")\n}\n', 0),
    (1, 'python', '# TODO: write your code here\n', 0)
ON DUPLICATE KEY UPDATE
    template_code = VALUES(template_code),
    deleted = VALUES(deleted),
    updated_at = CURRENT_TIMESTAMP;
