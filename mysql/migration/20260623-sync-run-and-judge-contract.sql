-- FlowStudy migration: sync run/submission judge contract
-- MySQL version: 5.7.24+
--
-- Purpose:
--   Bring an existing local database in line with the current V1 contract:
--   - fs_code_template.judge_wrapper_code
--   - fs_submission.judge_code / submit_mode
--   - fs_judge_case_result.input_text
--   - fs_code_run
--   - fs_code_run_case_result
--
-- Run after backing up the database:
--   mysqldump -uroot -p flowstudy > flowstudy_backup_before_run_contract.sql
--   mysql -uroot -p flowstudy < mysql/migration/20260623-sync-run-and-judge-contract.sql

SET @OLD_CHARACTER_SET_CLIENT = @@CHARACTER_SET_CLIENT;
SET @OLD_CHARACTER_SET_RESULTS = @@CHARACTER_SET_RESULTS;
SET @OLD_COLLATION_CONNECTION = @@COLLATION_CONNECTION;
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET @OLD_SQL_MODE = @@SQL_MODE;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET FOREIGN_KEY_CHECKS = 0;
SET SESSION SQL_MODE = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE DATABASE IF NOT EXISTS flowstudy
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE flowstudy;

-- ---------------------------------------------------------
-- fs_code_template: add judge wrapper for LeetCode-style tasks
-- ---------------------------------------------------------
SET @sql = IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'fs_code_template'
     AND COLUMN_NAME = 'judge_wrapper_code') = 0,
  'ALTER TABLE fs_code_template ADD COLUMN judge_wrapper_code MEDIUMTEXT DEFAULT NULL COMMENT ''Judge wrapper with {{USER_CODE}} placeholder'' AFTER template_code',
  'SELECT ''fs_code_template.judge_wrapper_code already exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------
-- fs_submission: persist final judge source and submit mode
-- ---------------------------------------------------------
SET @sql = IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'fs_submission'
     AND COLUMN_NAME = 'judge_code') = 0,
  'ALTER TABLE fs_submission ADD COLUMN judge_code MEDIUMTEXT DEFAULT NULL COMMENT ''Complete source sent to judge worker'' AFTER code',
  'SELECT ''fs_submission.judge_code already exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'fs_submission'
     AND COLUMN_NAME = 'submit_mode') = 0,
  'ALTER TABLE fs_submission ADD COLUMN submit_mode VARCHAR(32) NOT NULL DEFAULT ''FULL_PROGRAM'' COMMENT ''FULL_PROGRAM or TEMPLATE_WRAPPED'' AFTER judge_code',
  'SELECT ''fs_submission.submit_mode already exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------
-- fs_judge_case_result: store the failed testcase input
-- ---------------------------------------------------------
SET @sql = IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'fs_judge_case_result'
     AND COLUMN_NAME = 'input_text') = 0,
  'ALTER TABLE fs_judge_case_result ADD COLUMN input_text MEDIUMTEXT DEFAULT NULL COMMENT ''判题输入'' AFTER memory_used_kb',
  'SELECT ''fs_judge_case_result.input_text already exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------
-- fs_code_run: run-button task table
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS fs_code_run (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '代码运行ID',
    user_id BIGINT NOT NULL COMMENT '运行用户ID',
    problem_id BIGINT NOT NULL COMMENT '题目ID',
    language VARCHAR(32) NOT NULL COMMENT '运行语言',
    code MEDIUMTEXT NOT NULL COMMENT '用户原始代码',
    judge_code MEDIUMTEXT DEFAULT NULL COMMENT '发送给 judge 的完整代码',
    submit_mode VARCHAR(32) NOT NULL DEFAULT 'FULL_PROGRAM' COMMENT 'FULL_PROGRAM or TEMPLATE_WRAPPED',
    status VARCHAR(64) NOT NULL DEFAULT 'PENDING' COMMENT '运行状态',
    time_used_ms INT DEFAULT NULL COMMENT '最大耗时，毫秒',
    memory_used_kb INT DEFAULT NULL COMMENT '最大内存，KB',
    compile_message MEDIUMTEXT DEFAULT NULL COMMENT '编译信息',
    runtime_message MEDIUMTEXT DEFAULT NULL COMMENT '运行错误信息',
    trace_id VARCHAR(64) DEFAULT NULL COMMENT '链路追踪ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    KEY idx_fs_code_run_user_id (user_id),
    KEY idx_fs_code_run_problem_id (problem_id),
    KEY idx_fs_code_run_status (status),
    KEY idx_fs_code_run_created_at (created_at),
    KEY idx_fs_code_run_user_created (user_id, created_at),
    KEY idx_fs_code_run_trace_id (trace_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='代码运行记录表';

-- ---------------------------------------------------------
-- fs_code_run_case_result: run-button testcase results
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS fs_code_run_case_result (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '运行测试点结果ID',
    run_id BIGINT NOT NULL COMMENT '代码运行ID',
    testcase_id BIGINT DEFAULT NULL COMMENT '数据库测试用例ID，自定义运行用例为空',
    case_index INT NOT NULL COMMENT '测试点序号，从1开始',
    status VARCHAR(64) NOT NULL COMMENT '测试点状态',
    time_used_ms INT DEFAULT NULL COMMENT '耗时，毫秒',
    memory_used_kb INT DEFAULT NULL COMMENT '内存，KB',
    input_text MEDIUMTEXT DEFAULT NULL COMMENT '运行输入',
    actual_output MEDIUMTEXT DEFAULT NULL COMMENT '实际输出',
    expected_output MEDIUMTEXT DEFAULT NULL COMMENT '期望输出',
    error_message MEDIUMTEXT DEFAULT NULL COMMENT '错误信息',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    UNIQUE KEY uk_fs_code_run_case_run_index (run_id, case_index),
    KEY idx_fs_code_run_case_run_id (run_id),
    KEY idx_fs_code_run_case_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='代码运行测试点结果表';

SET SESSION SQL_MODE = @OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;
SET CHARACTER_SET_CLIENT = @OLD_CHARACTER_SET_CLIENT;
SET CHARACTER_SET_RESULTS = @OLD_CHARACTER_SET_RESULTS;
SET COLLATION_CONNECTION = @OLD_COLLATION_CONNECTION;
