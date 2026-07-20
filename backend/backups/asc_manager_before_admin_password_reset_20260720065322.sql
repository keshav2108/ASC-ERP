/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19-11.8.6-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: asc_manager
-- ------------------------------------------------------
-- Server version	11.8.6-MariaDB-5ubuntu0.1 from Ubuntu

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;

--
-- Table structure for table `alembic_version`
--

DROP TABLE IF EXISTS `alembic_version`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `alembic_version` (
  `version_num` varchar(32) NOT NULL,
  PRIMARY KEY (`version_num`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `alembic_version`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `alembic_version` WRITE;
/*!40000 ALTER TABLE `alembic_version` DISABLE KEYS */;
INSERT INTO `alembic_version` VALUES
('4a01adcaafb1');
/*!40000 ALTER TABLE `alembic_version` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `customer_products`
--

DROP TABLE IF EXISTS `customer_products`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `customer_products` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `customer_id` int(11) NOT NULL,
  `brand` varchar(100) NOT NULL,
  `product_name` varchar(100) NOT NULL,
  `model_number` varchar(100) DEFAULT NULL,
  `serial_number` varchar(100) DEFAULT NULL,
  `purchase_date` datetime DEFAULT NULL,
  `warranty_status` varchar(20) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ix_customer_products_serial_number` (`serial_number`),
  KEY `ix_customer_products_id` (`id`),
  KEY `ix_customer_products_customer_id` (`customer_id`),
  CONSTRAINT `customer_products_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `customer_products`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `customer_products` WRITE;
/*!40000 ALTER TABLE `customer_products` DISABLE KEYS */;
INSERT INTO `customer_products` VALUES
(1,2,'LG','Washing Machine','LG-WM-2025','LG123456789','2025-06-10 00:00:00','IN','2026-07-18 21:42:19');
/*!40000 ALTER TABLE `customer_products` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `customers`
--

DROP TABLE IF EXISTS `customers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `customers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `customer_code` varchar(20) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `mobile` varchar(15) NOT NULL,
  `alternate_mobile` varchar(15) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `pincode` varchar(10) DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `customer_code` (`customer_code`),
  UNIQUE KEY `mobile` (`mobile`),
  KEY `ix_customers_id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `customers`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `customers` WRITE;
/*!40000 ALTER TABLE `customers` DISABLE KEYS */;
INSERT INTO `customers` VALUES
(2,'CUS20260718001','Rahul Sharma','9876543210','9123456789','rahul@gmail.com','Indore','Indore','452001','ACTIVE','2026-07-18 21:13:19');
/*!40000 ALTER TABLE `customers` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `invoice_items`
--

DROP TABLE IF EXISTS `invoice_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `invoice_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `invoice_id` int(11) NOT NULL,
  `spare_part_id` int(11) DEFAULT NULL,
  `item_type` varchar(30) NOT NULL,
  `description` varchar(255) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(12,2) NOT NULL,
  `total_price` decimal(12,2) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_invoice_items_id` (`id`),
  KEY `ix_invoice_items_invoice_id` (`invoice_id`),
  KEY `ix_invoice_items_spare_part_id` (`spare_part_id`),
  CONSTRAINT `invoice_items_ibfk_1` FOREIGN KEY (`invoice_id`) REFERENCES `invoices` (`id`),
  CONSTRAINT `invoice_items_ibfk_2` FOREIGN KEY (`spare_part_id`) REFERENCES `spare_parts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `invoice_items`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `invoice_items` WRITE;
/*!40000 ALTER TABLE `invoice_items` DISABLE KEYS */;
INSERT INTO `invoice_items` VALUES
(2,2,NULL,'LABOUR','Labour Charge',1,750.00,750.00),
(3,2,1,'SPARE_PART','Drain Pump',3,283.33,850.00);
/*!40000 ALTER TABLE `invoice_items` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `invoices`
--

DROP TABLE IF EXISTS `invoices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `invoices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `invoice_code` varchar(25) NOT NULL,
  `job_card_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `labour_amount` decimal(12,2) NOT NULL,
  `parts_amount` decimal(12,2) NOT NULL,
  `subtotal` decimal(12,2) NOT NULL,
  `discount_amount` decimal(12,2) NOT NULL,
  `taxable_amount` decimal(12,2) NOT NULL,
  `gst_percentage` decimal(5,2) NOT NULL,
  `gst_amount` decimal(12,2) NOT NULL,
  `total_amount` decimal(12,2) NOT NULL,
  `payment_status` varchar(30) NOT NULL,
  `status` varchar(30) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ix_invoices_invoice_code` (`invoice_code`),
  UNIQUE KEY `ix_invoices_job_card_id` (`job_card_id`),
  KEY `ix_invoices_customer_id` (`customer_id`),
  KEY `ix_invoices_id` (`id`),
  CONSTRAINT `invoices_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`),
  CONSTRAINT `invoices_ibfk_2` FOREIGN KEY (`job_card_id`) REFERENCES `job_cards` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `invoices`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `invoices` WRITE;
/*!40000 ALTER TABLE `invoices` DISABLE KEYS */;
INSERT INTO `invoices` VALUES
(2,'INV20260719001',1,2,750.00,850.00,1600.00,0.00,1600.00,18.00,288.00,1888.00,'PAID','GENERATED','2026-07-19 16:20:58');
/*!40000 ALTER TABLE `invoices` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `job_cards`
--

DROP TABLE IF EXISTS `job_cards`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_cards` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job_code` varchar(20) NOT NULL,
  `service_request_id` int(11) NOT NULL,
  `technician_id` int(11) NOT NULL,
  `diagnosis` text DEFAULT NULL,
  `repair_notes` text DEFAULT NULL,
  `labour_charge` decimal(10,2) NOT NULL,
  `status` varchar(30) NOT NULL,
  `assigned_at` datetime NOT NULL,
  `started_at` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `delivered_at` datetime DEFAULT NULL,
  `delivered_to` varchar(100) DEFAULT NULL,
  `delivery_remarks` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ix_job_cards_job_code` (`job_code`),
  UNIQUE KEY `ix_job_cards_service_request_id` (`service_request_id`),
  KEY `ix_job_cards_id` (`id`),
  KEY `ix_job_cards_technician_id` (`technician_id`),
  CONSTRAINT `job_cards_ibfk_1` FOREIGN KEY (`service_request_id`) REFERENCES `service_requests` (`id`),
  CONSTRAINT `job_cards_ibfk_2` FOREIGN KEY (`technician_id`) REFERENCES `technicians` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `job_cards`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `job_cards` WRITE;
/*!40000 ALTER TABLE `job_cards` DISABLE KEYS */;
INSERT INTO `job_cards` VALUES
(1,'JOB20260719001',2,2,'Drain pump failure','Drain pump replacement required',750.00,'READY_FOR_DELIVERY','2026-07-19 12:59:32','2026-07-19 16:05:21','2026-07-19 16:06:37','2026-07-19 12:59:32',NULL,NULL,NULL);
/*!40000 ALTER TABLE `job_cards` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `master_options`
--

DROP TABLE IF EXISTS `master_options`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `master_options` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `option_type` varchar(50) NOT NULL,
  `code` varchar(50) NOT NULL,
  `label` varchar(100) NOT NULL,
  `display_order` int(11) NOT NULL,
  `is_active` tinyint(1) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_master_option_type_code` (`option_type`,`code`),
  KEY `ix_master_options_id` (`id`),
  KEY `ix_master_options_option_type` (`option_type`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `master_options`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `master_options` WRITE;
/*!40000 ALTER TABLE `master_options` DISABLE KEYS */;
INSERT INTO `master_options` VALUES
(1,'COMPLAINT_CATEGORY','ELECTRICAL','Electrical',1,1,'2026-07-19 00:24:33'),
(2,'COMPLAINT_CATEGORY','MECHANICAL','Mechanical',2,1,'2026-07-19 00:24:57'),
(3,'COMPLAINT_CATEGORY','OTHER','Other',3,1,'2026-07-19 00:25:15'),
(4,'PRODUCT_CONDITION','GOOD','Good',1,1,'2026-07-19 00:25:28'),
(5,'PRODUCT_CONDITION','PARTS_MISSING','Parts Missing',2,1,'2026-07-19 00:25:40'),
(6,'PRODUCT_CONDITION','DAMAGED','Damaged',3,1,'2026-07-19 00:25:57'),
(7,'PRIORITY','LOW','Low',1,1,'2026-07-19 00:26:06'),
(8,'PRIORITY','NORMAL','Normal',2,1,'2026-07-19 00:26:24'),
(9,'PRIORITY','HIGH','High',3,1,'2026-07-19 00:26:32'),
(10,'SERVICE_STATUS','OPEN','Open',1,1,'2026-07-19 00:26:41'),
(11,'SERVICE_STATUS','ASSIGNED','Assigned',2,1,'2026-07-19 00:26:50'),
(12,'SERVICE_STATUS','IN_PROGRESS','In Progress',3,1,'2026-07-19 00:27:02'),
(13,'SERVICE_STATUS','COMPLETED','Completed',4,1,'2026-07-19 00:27:14'),
(14,'SERVICE_STATUS','DELIVERED','Delivered',5,1,'2026-07-19 00:27:21'),
(15,'SERVICE_STATUS','CANCELLED','Cancelled',6,1,'2026-07-19 00:41:03'),
(16,'JOB_STATUS','ASSIGNED','Assigned',1,1,'2026-07-19 08:23:52'),
(17,'JOB_STATUS','IN_PROGRESS','In Progress',2,1,'2026-07-19 08:24:07'),
(18,'JOB_STATUS','COMPLETED','Completed',3,1,'2026-07-19 08:24:24'),
(19,'JOB_STATUS','CANCELLED','Cancelled',4,1,'2026-07-19 08:24:36'),
(20,'JOB_STATUS','ACCEPTED','Accepted',2,1,'0000-00-00 00:00:00'),
(21,'JOB_STATUS','DIAGNOSIS','Diagnosis',3,1,'0000-00-00 00:00:00'),
(22,'JOB_STATUS','WAITING_PARTS','Waiting For Parts',4,1,'0000-00-00 00:00:00'),
(23,'JOB_STATUS','REPAIR_IN_PROGRESS','Repair In Progress',5,1,'0000-00-00 00:00:00'),
(24,'JOB_STATUS','TESTING','Testing',6,1,'0000-00-00 00:00:00'),
(25,'JOB_STATUS','READY_FOR_DELIVERY','Ready For Delivery',8,1,'0000-00-00 00:00:00'),
(26,'SERVICE_STATUS','ACCEPTED','Accepted',6,1,'0000-00-00 00:00:00'),
(27,'SERVICE_STATUS','DIAGNOSIS','Diagnosis',7,1,'0000-00-00 00:00:00'),
(28,'SERVICE_STATUS','WAITING_PARTS','Waiting For Parts',8,1,'0000-00-00 00:00:00'),
(29,'SERVICE_STATUS','REPAIR_IN_PROGRESS','Repair In Progress',9,1,'0000-00-00 00:00:00'),
(30,'SERVICE_STATUS','TESTING','Testing',10,1,'0000-00-00 00:00:00'),
(31,'SERVICE_STATUS','READY_FOR_DELIVERY','Ready For Delivery',11,1,'0000-00-00 00:00:00'),
(32,'JOB_STATUS','DELIVERED','Delivered',10,1,'0000-00-00 00:00:00');
/*!40000 ALTER TABLE `master_options` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `payments`
--

DROP TABLE IF EXISTS `payments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `payments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `payment_code` varchar(25) NOT NULL,
  `invoice_id` int(11) NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `payment_method` varchar(30) NOT NULL,
  `transaction_reference` varchar(100) DEFAULT NULL,
  `remarks` varchar(500) DEFAULT NULL,
  `status` varchar(30) NOT NULL,
  `paid_at` datetime NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ix_payments_payment_code` (`payment_code`),
  KEY `ix_payments_id` (`id`),
  KEY `ix_payments_invoice_id` (`invoice_id`),
  CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`invoice_id`) REFERENCES `invoices` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `payments`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `payments` WRITE;
/*!40000 ALTER TABLE `payments` DISABLE KEYS */;
INSERT INTO `payments` VALUES
(1,'PAY20260719001',2,1888.00,'UPI','UPI-FINAL-001','Final payment','SUCCESS','2026-07-19 16:39:59','2026-07-19 16:39:59');
/*!40000 ALTER TABLE `payments` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `service_requests`
--

DROP TABLE IF EXISTS `service_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `service_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `request_code` varchar(20) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `customer_product_id` int(11) NOT NULL,
  `complaint_category` varchar(100) NOT NULL,
  `complaint_description` text NOT NULL,
  `received_accessories` varchar(255) DEFAULT NULL,
  `product_condition` varchar(100) DEFAULT NULL,
  `priority` varchar(20) DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `estimated_delivery` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `request_code` (`request_code`),
  KEY `customer_id` (`customer_id`),
  KEY `customer_product_id` (`customer_product_id`),
  KEY `ix_service_requests_id` (`id`),
  CONSTRAINT `service_requests_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`),
  CONSTRAINT `service_requests_ibfk_2` FOREIGN KEY (`customer_product_id`) REFERENCES `customer_products` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `service_requests`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `service_requests` WRITE;
/*!40000 ALTER TABLE `service_requests` DISABLE KEYS */;
INSERT INTO `service_requests` VALUES
(1,'SR20260719001',2,1,'ELECTRICAL','Washing machine is not starting','Power cable','GOOD','HIGH','CANCELLED','2026-07-25 18:00:00','2026-07-19 00:31:52'),
(2,'SR20260719002',2,1,'ELECTRICAL','Washing machine is not starting','Power cable','GOOD','NORMAL','READY_FOR_DELIVERY','2026-07-25 18:00:00','2026-07-19 00:45:12');
/*!40000 ALTER TABLE `service_requests` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `spare_parts`
--

DROP TABLE IF EXISTS `spare_parts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `spare_parts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `part_code` varchar(20) NOT NULL,
  `part_name` varchar(150) NOT NULL,
  `brand` varchar(100) DEFAULT NULL,
  `product_category` varchar(100) DEFAULT NULL,
  `unit` varchar(30) NOT NULL,
  `purchase_price` decimal(10,2) NOT NULL,
  `selling_price` decimal(10,2) NOT NULL,
  `current_stock` int(11) NOT NULL,
  `minimum_stock` int(11) NOT NULL,
  `is_active` tinyint(1) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ix_spare_parts_part_code` (`part_code`),
  KEY `ix_spare_parts_id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `spare_parts`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `spare_parts` WRITE;
/*!40000 ALTER TABLE `spare_parts` DISABLE KEYS */;
INSERT INTO `spare_parts` VALUES
(1,'PART001','Drain Pump','LG','Washing Machine','PIECE',650.00,850.00,12,2,1,'2026-07-19 12:46:23');
/*!40000 ALTER TABLE `spare_parts` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `stock_transactions`
--

DROP TABLE IF EXISTS `stock_transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `stock_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `spare_part_id` int(11) NOT NULL,
  `job_card_id` int(11) DEFAULT NULL,
  `transaction_type` varchar(30) NOT NULL,
  `quantity` int(11) NOT NULL,
  `reference` varchar(100) DEFAULT NULL,
  `remarks` text DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `unit_price` decimal(12,2) NOT NULL,
  `line_total` decimal(12,2) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_stock_transactions_id` (`id`),
  KEY `ix_stock_transactions_job_card_id` (`job_card_id`),
  KEY `ix_stock_transactions_spare_part_id` (`spare_part_id`),
  CONSTRAINT `stock_transactions_ibfk_1` FOREIGN KEY (`job_card_id`) REFERENCES `job_cards` (`id`),
  CONSTRAINT `stock_transactions_ibfk_2` FOREIGN KEY (`spare_part_id`) REFERENCES `spare_parts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stock_transactions`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `stock_transactions` WRITE;
/*!40000 ALTER TABLE `stock_transactions` DISABLE KEYS */;
INSERT INTO `stock_transactions` VALUES
(1,1,NULL,'STOCK_IN',5,'Purchase Bill 1001','Initial Purchase','2026-07-19 12:48:35',0.00,0.00),
(2,1,1,'ISSUE',2,'JOB20260719001','Drain Pump Replaced','2026-07-19 13:01:48',0.00,0.00),
(3,1,1,'ISSUE',1,'JOB20260719001','Drain pump used for repair','2026-07-19 16:17:13',850.00,850.00);
/*!40000 ALTER TABLE `stock_transactions` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `technicians`
--

DROP TABLE IF EXISTS `technicians`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `technicians` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `technician_code` varchar(20) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `full_name` varchar(100) NOT NULL,
  `mobile` varchar(15) NOT NULL,
  `specialization` varchar(150) DEFAULT NULL,
  `experience_years` int(11) NOT NULL,
  `availability_status` varchar(30) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `mobile` (`mobile`),
  UNIQUE KEY `ix_technicians_technician_code` (`technician_code`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `ix_technicians_id` (`id`),
  CONSTRAINT `technicians_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `technicians`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `technicians` WRITE;
/*!40000 ALTER TABLE `technicians` DISABLE KEYS */;
INSERT INTO `technicians` VALUES
(1,'TECH20260719001',NULL,'Ravi Verma','9988776655','Washing Machine and Refrigerator',4,'UNAVAILABLE','INACTIVE','2026-07-19 01:05:07'),
(2,'TECH002',NULL,'Ravi Verma','9988776345','Washing Machine, Refrigerator and Microwave',5,'AVAILABLE','ACTIVE','2026-07-19 01:19:40');
/*!40000 ALTER TABLE `technicians` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `employee_id` varchar(20) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `username` varchar(50) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `mobile` varchar(15) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` varchar(30) NOT NULL,
  `status` varchar(20) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `employee_id` (`employee_id`),
  UNIQUE KEY `mobile` (`mobile`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `uq_users_username` (`username`),
  KEY `ix_users_id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES
(1,'EMP001','Keshav Kumar','admin','admin@shreesainath.com','9876543210','$2b$12$d7kxlKGOhpG29JbHmR8sxew5ahj4nZm/Otta5dh/CvbHf2/tSQS36','ADMIN','ACTIVE','2026-07-19 13:52:19');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `workflow_transitions`
--

DROP TABLE IF EXISTS `workflow_transitions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `workflow_transitions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `from_status` varchar(50) NOT NULL,
  `to_status` varchar(50) NOT NULL,
  `action` varchar(100) NOT NULL,
  `is_active` tinyint(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_workflow_transitions_from_status` (`from_status`),
  KEY `ix_workflow_transitions_id` (`id`),
  KEY `ix_workflow_transitions_to_status` (`to_status`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `workflow_transitions`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `workflow_transitions` WRITE;
/*!40000 ALTER TABLE `workflow_transitions` DISABLE KEYS */;
INSERT INTO `workflow_transitions` VALUES
(1,'ASSIGNED','ACCEPTED','Accept Job',1),
(2,'ACCEPTED','DIAGNOSIS','Start Diagnosis',1),
(3,'DIAGNOSIS','WAITING_PARTS','Waiting For Parts',1),
(4,'DIAGNOSIS','REPAIR_IN_PROGRESS','Start Repair',1),
(5,'WAITING_PARTS','REPAIR_IN_PROGRESS','Resume Repair',1),
(6,'REPAIR_IN_PROGRESS','TESTING','Start Testing',1),
(7,'TESTING','COMPLETED','Complete Repair',1),
(8,'COMPLETED','READY_FOR_DELIVERY','Ready For Delivery',1),
(9,'ASSIGNED','CANCELLED','Cancel Job',1),
(10,'ACCEPTED','CANCELLED','Cancel Job',1),
(11,'DIAGNOSIS','CANCELLED','Cancel Job',1),
(12,'WAITING_PARTS','CANCELLED','Cancel Job',1),
(13,'READY_FOR_DELIVERY','DELIVERED','Deliver Product',1);
/*!40000 ALTER TABLE `workflow_transitions` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed on 2026-07-20  6:53:25
