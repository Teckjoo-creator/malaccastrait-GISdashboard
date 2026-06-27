-- ============================================================
--  MALACCA MARITIME INTELLIGENCE — DATABASE SCHEMA
--  Compatible: MySQL 5.7+ / MariaDB 10.3+
--  PHPMyAdmin: Import this file directly
-- ============================================================

-- 1. CREATE THE NEW DATABASE
CREATE DATABASE IF NOT EXISTS `malacca_db`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `malacca_db`;

-- 2. CREATE THE TABLE STRUCTURE
CREATE TABLE IF NOT EXISTS `vessels` (
  `id`           INT          UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `mmsi`         CHAR(9)      NOT NULL UNIQUE COMMENT 'Maritime Mobile Service Identity',
  `imo`          CHAR(10)     DEFAULT NULL,
  `vessel_name`  VARCHAR(100) NOT NULL,
  `vessel_type`  ENUM('VLCC','Suezmax','Aframax','LNG','LPG','Chemical','Other') NOT NULL,
  `flag_state`   VARCHAR(60)  NOT NULL,
  `gross_tonnage` INT         UNSIGNED DEFAULT NULL,
  `dwt`          INT         UNSIGNED DEFAULT NULL COMMENT 'Deadweight Tonnage',
  `year_built`   YEAR        DEFAULT NULL,
  `owner`        VARCHAR(120) DEFAULT NULL,
  `call_sign`    VARCHAR(20)  DEFAULT NULL,
  `created_at`   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_vessel_type` (`vessel_type`),
  INDEX `idx_flag_state`  (`flag_state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `vessel_positions` (
  `id`           BIGINT       UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `vessel_id`    INT          UNSIGNED NOT NULL,
  `latitude`     DECIMAL(9,6) NOT NULL,
  `longitude`    DECIMAL(9,6) NOT NULL,
  `speed_kts`    DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  `heading_deg`  SMALLINT     UNSIGNED DEFAULT NULL COMMENT '0-359 degrees',
  `course_deg`   SMALLINT     UNSIGNED DEFAULT NULL,
  `nav_status`   ENUM('underway','anchored','moored','alert','restricted','unknown') DEFAULT 'unknown',
  `timestamp`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_vessel_id`  (`vessel_id`),
  INDEX `idx_timestamp`  (`timestamp`),
  INDEX `idx_nav_status` (`nav_status`),
  CONSTRAINT `fk_pos_vessel` FOREIGN KEY (`vessel_id`) REFERENCES `vessels`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `voyages` (
  `id`            INT         UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `vessel_id`     INT         UNSIGNED NOT NULL,
  `voyage_no`     VARCHAR(30) DEFAULT NULL,
  `cargo_type`    ENUM('Crude','LNG','LPG','Clean Petroleum','Dirty Petroleum','Chemical','Other') NOT NULL,
  `cargo_volume`  DECIMAL(10,2) DEFAULT NULL COMMENT 'in barrels or CBM',
  `origin_port`   VARCHAR(80) DEFAULT NULL,
  `dest_port`     VARCHAR(80) DEFAULT NULL,
  `eta`           DATETIME    DEFAULT NULL,
  `direction`     ENUM('inbound','outbound','transiting','anchored') NOT NULL DEFAULT 'transiting',
  `started_at`    DATETIME    DEFAULT NULL,
  `ended_at`      DATETIME    DEFAULT NULL,
  `is_active`     TINYINT(1)  NOT NULL DEFAULT 1,
  `created_at`    TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_voyage_vessel`  (`vessel_id`),
  INDEX `idx_voyage_active`  (`is_active`),
  CONSTRAINT `fk_voy_vessel` FOREIGN KEY (`vessel_id`) REFERENCES `vessels`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `incidents` (
  `id`            INT          UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `vessel_id`     INT          UNSIGNED DEFAULT NULL,
  `incident_type` ENUM('Detention','AIS Loss','Speed Deviation','Piracy','Boarding','Suspicious Activity','Mechanical','Other') NOT NULL,
  `severity`      ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
  `latitude`      DECIMAL(9,6) DEFAULT NULL,
  `longitude`     DECIMAL(9,6) DEFAULT NULL,
  `description`   TEXT         DEFAULT NULL,
  `reported_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at`   TIMESTAMP    NULL DEFAULT NULL,
  `is_active`     TINYINT(1)   NOT NULL DEFAULT 1,
  INDEX `idx_inc_vessel`   (`vessel_id`),
  INDEX `idx_inc_severity` (`severity`),
  INDEX `idx_inc_active`   (`is_active`),
  CONSTRAINT `fk_inc_vessel` FOREIGN KEY (`vessel_id`) REFERENCES `vessels`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `traffic_stats` (
  `id`              INT          UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `stat_date`       DATE         NOT NULL,
  `stat_hour`       TINYINT      UNSIGNED NOT NULL COMMENT '0-23',
  `vessel_count`    SMALLINT     UNSIGNED NOT NULL DEFAULT 0,
  `outbound_count`  SMALLINT     UNSIGNED NOT NULL DEFAULT 0,
  `inbound_count`   SMALLINT     UNSIGNED NOT NULL DEFAULT 0,
  `avg_speed_kts`   DECIMAL(5,2) DEFAULT NULL,
  `oil_volume_kbd`  DECIMAL(8,2) DEFAULT NULL COMMENT 'thousand barrels/day',
  `created_at`      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_stat_hour` (`stat_date`, `stat_hour`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `monthly_transits` (
  `id`             INT      UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `transit_year`   YEAR     NOT NULL,
  `transit_month`  TINYINT  UNSIGNED NOT NULL COMMENT '1-12',
  `total_transits` INT      UNSIGNED NOT NULL DEFAULT 0,
  `total_vlcc`     INT      UNSIGNED DEFAULT 0,
  `total_suezmax`  INT      UNSIGNED DEFAULT 0,
  `total_aframax`  INT      UNSIGNED DEFAULT 0,
  `total_lng`      INT      UNSIGNED DEFAULT 0,
  `total_lpg`      INT      UNSIGNED DEFAULT 0,
  `avg_daily_kbd`  DECIMAL(8,2) DEFAULT NULL,
  UNIQUE KEY `uk_month` (`transit_year`, `transit_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. SEED REGIONAL VESSELS
INSERT IGNORE INTO `vessels` (`id`, `mmsi`,`imo`,`vessel_name`,`vessel_type`,`flag_state`,`dwt`,`year_built`,`owner`,`call_sign`) VALUES
(1, '538001001','IMO9800001','MALACCA TRADER', 'VLCC',    'Singapore',    302000,2018,'Straits Tankers Pte Ltd','9VLT1'),
(2, '538002002','IMO9700022','MARE NOSTRUM',    'Suezmax', 'Greece',       155000,2015,'Aegean Maritime SA',    'SVMN2'),
(3, '352003003','IMO9800033','PACIFIC CROWN',   'VLCC',    'Panama',       318000,2019,'Pacific Energy Inc',    'HPPC3'),
(4, '538004004','IMO9650044','LANGKAWI EAGLE',  'Aframax', 'Malaysia',     108000,2014,'MISC Berhad',           '9MLE4'),
(5, '311005005','IMO9750055','PERSIAN STAR',    'LNG',     'Bahamas',       90000,2017,'Bahamas Gas Lines',     'C6PS5'),
(6, '636006006','IMO9820066','STRAIT PIONEER',  'VLCC',    'Liberia',      278000,2020,'Liberia Ocean LLC',     'A8SP6'),
(7, '470007007','IMO9600077','AL MARJAN',       'LPG',     'UAE',           44000,2013,'UAE Energy Transport',  'A6AM7'),
(8, '538008008','IMO9700088','NANYANG STAR',    'Suezmax', 'Marshall Is.', 162000,2016,'Marshall Shipping Co',  'V7GS8'),
(9, '257009009','IMO9650099','CALEDONIAN',      'Aframax', 'Norway',       115000,2015,'Nordic Maritime AS',    'LNCA9'),
(10,'352010010','IMO9810100','ORIENT QUEEN',    'VLCC',    'Panama',       299000,2021,'Pan-Orient Tankers',    'HPOQ10'),
(11,'466011011','IMO9780111','NOOR TANKER I',   'LNG',     'Qatar',         95000,2019,'Qatargas Transport',    'A7NT11'),
(12,'239012012','IMO9720122','BUENA VISTA',     'Suezmax', 'Greece',       148000,2016,'Aegean Maritime SA',    'SVBV12'),
(13,'311013013','IMO9690133','ATLAS MARINER',   'Aframax', 'Bahamas',      101000,2014,'Bahamas Marine LLC',    'C6AT13'),
(14,'470014014','IMO9600144','TEMASEK FALCON',  'LPG',     'Singapore',     52000,2015,'Singa Port Marine',     '9VDF14'),
(15,'636015015','IMO9830155','NORDLICHT',       'VLCC',    'Liberia',      265000,2022,'Liberia Ocean LLC',     'A8NL15'),
(16,'352016016','IMO9740166','ANDAMAN SEA',     'Suezmax', 'Panama',       170000,2017,'Andaman Tankers Ltd',   'HPAS16');

-- 4. SEED POSITION COORDINATES
INSERT IGNORE INTO `vessel_positions` (`vessel_id`,`latitude`,`longitude`,`speed_kts`,`heading_deg`,`nav_status`) VALUES
(1,  1.320000, 103.650000, 12.4, 110, 'underway'),
(2,  1.750000, 102.950000, 10.8, 115, 'underway'),
(3,  2.250000, 102.100000,  0.0,   0, 'alert'),
(4,  2.850000, 101.150000,  9.1, 290, 'underway'),
(5,  3.400000, 100.600000, 15.2, 120, 'underway'),
(6,  4.100000,  99.950000, 11.6,  95, 'underway'),
(7,  4.800000,  99.100000, 13.0, 105, 'underway'),
(8,  5.300000,  98.200000,  0.0, 180, 'alert'),
(9,  2.600000, 101.450000, 10.3, 280, 'underway'),
(10, 1.450000, 103.400000, 12.9, 108, 'underway'),
(11, 2.100000, 102.350000, 14.8, 116, 'underway'),
(12, 3.150000, 100.900000, 11.1, 285, 'underway'),
(13, 3.850000, 100.200000,  9.8, 100, 'underway'),
(14, 2.950000, 101.050000, 12.5, 290, 'underway'),
(15, 1.600000, 103.150000, 13.2, 112, 'underway'),
(16, 1.220000, 103.850000, 10.5, 120, 'anchored');

-- 5. SEED SOUTHEAST ASIAN VOYAGES
INSERT IGNORE INTO `voyages` (`vessel_id`,`cargo_type`,`origin_port`,`dest_port`,`direction`,`is_active`) VALUES
(1,  'Crude',             'Ras Tanura, SA',   'Singapore, SG', 'outbound',   1),
(2,  'Crude',             'Bintulu, MY',      'Rotterdam, NL', 'outbound',   1),
(3,  'Crude',             'Port Klang, MY',   'Unknown',       'anchored',   1),
(4,  'Dirty Petroleum',   'Singapore, SG',    'Port Klang, MY', 'inbound',    1),
(5,  'LNG',               'Bintulu, MY',      'Yokohama, JP',  'outbound',   1),
(6,  'Crude',             'Miri, MY',         'Qingdao, CN',   'outbound',   1),
(7,  'LPG',               'Ruwais, UAE',      'Tanjung Pelepas','outbound',   1),
(8,  'Crude',             'Dumai, ID',        'Unknown',       'transiting', 1),
(9,  'Crude',             'Oman',             'Penang, MY',    'outbound',   1),
(10, 'Crude',             'Singapore, SG',    'Ulsan, KR',     'outbound',   1),
(11, 'LNG',               'Ras Laffan, QA',   'Tsingtao, CN',  'outbound',   1),
(12, 'Dirty Petroleum',   'Port Klang, MY',   'Galveston, TX', 'outbound',   1),
(13, 'Crude',             'Kuwait City',      'Singapore, SG', 'outbound',   1),
(14, 'LPG',               'Singapore, SG',    'Karachi, PK',   'outbound',   1),
(15, 'Crude',             'Kharg Island, IR', 'Shanghai, CN',  'outbound',   1),
(16, 'Crude',             'Ras Tanura, SA',   'Singapore, SG', 'anchored',   1);

-- 6. SEED REGIONAL INCIDENTS
INSERT IGNORE INTO `incidents` (`vessel_id`,`incident_type`,`severity`,`latitude`,`longitude`,`description`,`is_active`) VALUES
(3,  'Detention',       'critical',  2.250000, 102.100000, 'Vessel detained near Malacca coastal bounds for verification of registry documentation.', 1),
(8,  'AIS Loss',        'high',      5.300000,  98.200000, 'AIS transponder dropped signal completely near northern entrance. Littoral patrol unit notified.', 1),
(4,  'Speed Deviation', 'medium',    2.850000, 101.150000, 'Vessel speed tracking 3.2 kts below average TSS shipping corridor velocity.', 1);

-- 7. SEED TRAFFIC & MONTHLY STATS
INSERT IGNORE INTO `traffic_stats` (`stat_date`,`stat_hour`,`vessel_count`,`outbound_count`,`inbound_count`,`avg_speed_kts`,`oil_volume_kbd`) VALUES
(CURDATE(), 0,  4,  3,  1, 11.2, 820.0),
(CURDATE(), 1,  3,  2,  1, 10.8, 640.0),
(CURDATE(), 2,  5,  3,  2, 11.5, 920.0),
(CURDATE(), 3,  4,  3,  1, 11.0, 820.0),
(CURDATE(), 4,  6,  4,  2, 11.8, 1100.0),
(CURDATE(), 5,  8,  5,  3, 12.0, 1400.0),
(CURDATE(), 6, 10,  7,  3, 12.3, 1750.0),
(CURDATE(), 7, 13,  9,  4, 12.5, 2100.0),
(CURDATE(), 8, 15, 10,  5, 12.4, 2400.0),
(CURDATE(), 9, 14,  9,  5, 12.2, 2300.0),
(CURDATE(),10, 12,  8,  4, 12.1, 2000.0),
(CURDATE(),11, 11,  7,  4, 12.0, 1850.0),
(CURDATE(),12, 10,  7,  3, 11.9, 1700.0),
(CURDATE(),13, 12,  8,  4, 12.2, 2050.0),
(CURDATE(),14, 14,  9,  5, 12.4, 2350.0),
(CURDATE(),15, 16, 11,  5, 12.6, 2600.0),
(CURDATE(),16, 15, 10,  5, 12.5, 2450.0),
(CURDATE(),17, 13,  9,  4, 12.3, 2150.0),
(CURDATE(),18, 11,  7,  4, 12.0, 1850.0),
(CURDATE(),19, 10,  7,  3, 11.8, 1700.0),
(CURDATE(),20,  9,  6,  3, 11.6, 1550.0),
(CURDATE(),21,  8,  5,  3, 11.4, 1400.0),
(CURDATE(),22,  7,  5,  2, 11.2, 1250.0),
(CURDATE(),23,  5,  4,  1, 11.0,  900.0);

INSERT IGNORE INTO `monthly_transits` (`transit_year`,`transit_month`,`total_transits`,`total_vlcc`,`total_suezmax`,`total_aframax`,`total_lng`,`total_lpg`,`avg_daily_kbd`) VALUES
(2025, 1,  1820, 620, 480, 380, 210, 130, 20800.0),
(2025, 2,  1650, 560, 440, 340, 190, 120, 19200.0),
(2025, 3,  1890, 640, 500, 390, 220, 140, 21400.0),
(2025, 4,  1940, 660, 510, 400, 230, 140, 21900.0),
(2025, 5,  2010, 690, 530, 410, 240, 140, 22500.0),
(2025, 6,  1980, 670, 520, 400, 240, 150, 22100.0),
(2025, 7,  2050, 700, 540, 420, 245, 145, 22900.0),
(2025, 8,  2120, 720, 560, 430, 260, 150, 23600.0),
(2025, 9,  2090, 710, 550, 420, 255, 155, 23200.0),
(2025,10,  2140, 730, 560, 440, 260, 150, 23800.0);