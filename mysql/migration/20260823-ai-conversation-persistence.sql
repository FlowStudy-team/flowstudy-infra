-- Existing installations may have been created before the AI conversation
-- tables were added to init/01-init.sql. Keep this migration idempotent.
CREATE TABLE IF NOT EXISTS fs_ai_conversation (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    tutorial_id BIGINT DEFAULT NULL,
    blog_id BIGINT DEFAULT NULL,
    problem_id BIGINT DEFAULT NULL,
    title VARCHAR(255) DEFAULT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted TINYINT NOT NULL DEFAULT 0,
    KEY idx_fs_ai_conversation_user_id (user_id),
    KEY idx_fs_ai_conversation_updated_at (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fs_ai_message (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    conversation_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role VARCHAR(32) NOT NULL,
    content MEDIUMTEXT NOT NULL,
    model_name VARCHAR(128) DEFAULT NULL,
    token_count INT DEFAULT NULL,
    trace_id VARCHAR(64) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_fs_ai_message_conversation_id (conversation_id),
    KEY idx_fs_ai_message_user_id (user_id),
    KEY idx_fs_ai_message_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
