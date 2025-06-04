-- XNL-Trains Database Schema
-- Metro Tickets Persistence System
-- Compatible with QBCore Framework

-- Create metro_tickets table for ticket persistence
CREATE TABLE IF NOT EXISTS `metro_tickets` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `ticket_id` VARCHAR(100) UNIQUE NOT NULL,
    `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NOT NULL,
    `used_at` TIMESTAMP NULL,
    `is_used` BOOLEAN DEFAULT FALSE,
    `price_paid` INT NOT NULL DEFAULT 0,
    `station_purchased` VARCHAR(100) DEFAULT 'Unknown',
    `notes` TEXT DEFAULT NULL,
    
    -- Indexes for performance
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_ticket_id` (`ticket_id`),
    INDEX `idx_expires_at` (`expires_at`),
    INDEX `idx_is_used` (`is_used`),
    INDEX `idx_purchased_at` (`purchased_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create metro_statistics table for analytics (optional)
CREATE TABLE IF NOT EXISTS `metro_statistics` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `date` DATE NOT NULL,
    `tickets_sold` INT DEFAULT 0,
    `total_revenue` INT DEFAULT 0,
    `unique_customers` INT DEFAULT 0,
    `peak_hour` VARCHAR(10) DEFAULT NULL,
    `most_popular_station` VARCHAR(100) DEFAULT NULL,
    
    -- Indexes
    INDEX `idx_date` (`date`),
    UNIQUE KEY `unique_date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create metro_fare_evasions table for tracking violations (optional)
CREATE TABLE IF NOT EXISTS `metro_fare_evasions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `incident_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `station_id` INT DEFAULT NULL,
    `coordinates` VARCHAR(100) DEFAULT NULL,
    `warned` BOOLEAN DEFAULT FALSE,
    `police_called` BOOLEAN DEFAULT FALSE,
    `notes` TEXT DEFAULT NULL,
    
    -- Indexes
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_incident_time` (`incident_time`),
    INDEX `idx_police_called` (`police_called`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample data for testing (optional - remove in production)
-- INSERT INTO `metro_statistics` (`date`, `tickets_sold`, `total_revenue`) 
-- VALUES (CURDATE(), 0, 0);

-- Stored procedure to clean up expired tickets (optional)
DELIMITER $
CREATE PROCEDURE CleanupExpiredTickets()
BEGIN
    DECLARE cleaned_count INT DEFAULT 0;
    
    -- Delete expired tickets that weren't used
    DELETE FROM metro_tickets 
    WHERE expires_at < NOW() 
    AND is_used = FALSE;
    
    SET cleaned_count = ROW_COUNT();
    
    -- Log the cleanup if tickets were removed
    IF cleaned_count > 0 THEN
        INSERT INTO metro_statistics (date, tickets_sold, total_revenue) 
        VALUES (CURDATE(), 0, 0)
        ON DUPLICATE KEY UPDATE 
        date = VALUES(date);
    END IF;
    
    SELECT CONCAT(cleaned_count, ' expired tickets cleaned up') AS result;
END$
DELIMITER ;

-- Event to automatically run cleanup daily at 3 AM (optional)
-- SET GLOBAL event_scheduler = ON;
-- CREATE EVENT IF NOT EXISTS cleanup_expired_tickets
-- ON SCHEDULE EVERY 1 DAY STARTS '2024-01-01 03:00:00'
-- DO CALL CleanupExpiredTickets();

-- Views for easy data access (optional)
CREATE OR REPLACE VIEW `active_tickets` AS
SELECT 
    t.citizenid,
    t.ticket_id,
    t.purchased_at,
    t.expires_at,
    t.price_paid,
    t.station_purchased,
    TIMESTAMPDIFF(HOUR, NOW(), t.expires_at) as hours_remaining
FROM metro_tickets t
WHERE t.expires_at > NOW() 
AND t.is_used = FALSE;

CREATE OR REPLACE VIEW `daily_sales` AS
SELECT 
    DATE(purchased_at) as sale_date,
    COUNT(*) as tickets_sold,
    SUM(price_paid) as total_revenue,
    COUNT(DISTINCT citizenid) as unique_customers,
    AVG(price_paid) as avg_ticket_price
FROM metro_tickets
GROUP BY DATE(purchased_at)
ORDER BY sale_date DESC;

-- Sample queries for administration:

-- Get all active tickets for a player:
-- SELECT * FROM active_tickets WHERE citizenid = 'ABC12345';

-- Get daily sales report:
-- SELECT * FROM daily_sales WHERE sale_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);

-- Get fare evasion statistics:
-- SELECT citizenid, COUNT(*) as violations FROM metro_fare_evasions GROUP BY citizenid ORDER BY violations DESC;

-- Get busiest times:
-- SELECT HOUR(purchased_at) as hour, COUNT(*) as tickets FROM metro_tickets GROUP BY HOUR(purchased_at) ORDER BY tickets DESC;