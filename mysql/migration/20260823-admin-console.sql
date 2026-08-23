-- FlowStudy admin console schema migration
-- Compatible with MySQL 5.7; safe to run repeatedly on a fresh migration set.
USE flowstudy;

CREATE TABLE IF NOT EXISTS fs_admin_audit_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    admin_id BIGINT NOT NULL,
    module VARCHAR(32) NOT NULL,
    action VARCHAR(64) NOT NULL,
    target_type VARCHAR(32) DEFAULT NULL,
    target_id BIGINT DEFAULT NULL,
    request_summary VARCHAR(1024) DEFAULT NULL,
    result VARCHAR(16) NOT NULL DEFAULT 'SUCCESS',
    trace_id VARCHAR(64) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_fs_admin_audit_admin (admin_id, created_at),
    KEY idx_fs_admin_audit_target (target_type, target_id),
    KEY idx_fs_admin_audit_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='FlowStudy admin audit log';

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'sys_user' AND index_name = 'idx_sys_user_role_status'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE sys_user ADD INDEX idx_sys_user_role_status (role, status)',
    'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
