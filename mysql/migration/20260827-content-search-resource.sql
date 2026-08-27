USE flowstudy;

CREATE TABLE IF NOT EXISTS fs_resource_metadata (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    business_type VARCHAR(32) NOT NULL DEFAULT 'general',
    business_id BIGINT DEFAULT NULL,
    object_key VARCHAR(512) NOT NULL,
    original_name VARCHAR(255) DEFAULT NULL,
    content_type VARCHAR(128) DEFAULT NULL,
    size BIGINT NOT NULL DEFAULT 0,
    sha256 CHAR(64) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_fs_resource_object_key (object_key),
    KEY idx_fs_resource_owner (user_id, status),
    KEY idx_fs_resource_business (business_type, business_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
