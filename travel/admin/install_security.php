<?php
/**
 * Security Features Installation Script
 * 
 * This script creates the necessary database tables for security features:
 * - admin_logs: For logging administrative actions
 * - login_attempts: For brute force protection
 * 
 * Run this script once to set up the security infrastructure.
 */

require_once __DIR__ . '/config/admin_config.php';

echo "=== TravelMap Admin Panel - Security Installation ===\n\n";

try {
    $db = connectToDatabase();
    
    echo "Reading migration file...\n";
    $sql = file_get_contents(__DIR__ . '/migrations/add_security_tables.sql');
    
    if ($sql === false) {
        throw new Exception("Could not read migration file");
    }
    
    echo "Executing migration...\n";
    $db->exec($sql);
    
    echo "\n✓ Security tables created successfully!\n\n";
    
    // Verify tables were created
    echo "Verifying installation...\n";
    
    $tables = ['admin_logs', 'login_attempts'];
    foreach ($tables as $table) {
        $stmt = $db->query("SHOW TABLES LIKE '$table'");
        if ($stmt->rowCount() > 0) {
            echo "  ✓ Table '$table' exists\n";
        } else {
            echo "  ✗ Table '$table' NOT found\n";
        }
    }
    
    echo "\n=== Installation Complete ===\n";
    echo "\nSecurity features are now active:\n";
    echo "  - CSRF Protection\n";
    echo "  - Input Validation\n";
    echo "  - Admin Action Logging\n";
    echo "  - Brute Force Protection\n";
    echo "  - Output Escaping\n";
    echo "\nFor more information, see SECURITY.md\n\n";
    
} catch (PDOException $e) {
    echo "\n✗ Database error: " . $e->getMessage() . "\n";
    echo "\nPlease check your database configuration and try again.\n\n";
    exit(1);
} catch (Exception $e) {
    echo "\n✗ Error: " . $e->getMessage() . "\n\n";
    exit(1);
}
