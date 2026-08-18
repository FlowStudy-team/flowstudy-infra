-- FlowStudy learning profile and AI learning summary support.
-- MySQL 5.7.24+

SET @has_resource_type := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'fs_behavior_event'
      AND COLUMN_NAME = 'resource_type'
);
SET @sql := IF(
    @has_resource_type = 0,
    'ALTER TABLE fs_behavior_event ADD COLUMN resource_type VARCHAR(64) DEFAULT NULL COMMENT ''通用资源类型'' AFTER event_type',
    'SELECT ''fs_behavior_event.resource_type already exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_resource_id := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'fs_behavior_event'
      AND COLUMN_NAME = 'resource_id'
);
SET @sql := IF(
    @has_resource_id = 0,
    'ALTER TABLE fs_behavior_event ADD COLUMN resource_id BIGINT DEFAULT NULL COMMENT ''通用资源ID'' AFTER resource_type',
    'SELECT ''fs_behavior_event.resource_id already exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_resource_index := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'fs_behavior_event'
      AND INDEX_NAME = 'idx_fs_behavior_resource'
);
SET @sql := IF(
    @has_resource_index = 0,
    'ALTER TABLE fs_behavior_event ADD KEY idx_fs_behavior_resource (resource_type, resource_id)',
    'SELECT ''idx_fs_behavior_resource already exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
