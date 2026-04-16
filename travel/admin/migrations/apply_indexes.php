<?php
/**
 * Apply Performance Indexes Migration
 * Run this script to add database indexes for better query performance
 */

require_once '../../config.php';

echo "Starting database index migration...\n\n";

try {
    $conn = connectToDatabase();
    
    // Read the SQL file
    $sqlFile = __DIR__ . '/add_performance_indexes.sql';
    
    if (!file_exists($sqlFile)) {
        throw new Exception("SQL file not found: $sqlFile");
    }
    
    $sql = file_get_contents($sqlFile);
    
    // Split by semicolons and execute each statement
    $statements = array_filter(
        array_map('trim', explode(';', $sql)),
        function($stmt) {
            return !empty($stmt) && strpos($stmt, '--') !== 0;
        }
    );
    
    $successCount = 0;
    $errorCount = 0;
    $skippedCount = 0;
    
    foreach ($statements as $statement) {
        // Skip comments and empty lines
        if (empty($statement) || strpos(trim($statement), '--') === 0) {
            continue;
        }
        
        try {
            $conn->exec($statement);
            
            // Extract index name from statement
            if (preg_match('/ADD INDEX\s+(\w+)/i', $statement, $matches)) {
                $indexName = $matches[1];
                echo "✓ Created index: $indexName\n";
            } else {
                echo "✓ Executed statement\n";
            }
            
            $successCount++;
        } catch (PDOException $e) {
            // Check if error is because index already exists
            if (strpos($e->getMessage(), 'Duplicate key name') !== false || 
                strpos($e->getMessage(), 'already exists') !== false ||
                strpos($e->getMessage(), 'duplicate') !== false) {
                if (preg_match('/ADD INDEX\s+(\w+)/i', $statement, $matches)) {
                    $indexName = $matches[1];
                    echo "- Index already exists: $indexName\n";
                    $skippedCount++;
                } else {
                    echo "- Statement already applied\n";
                    $skippedCount++;
                }
            } else {
                echo "✗ Error: " . $e->getMessage() . "\n";
                $errorCount++;
            }
        }
    }
    
    echo "\n";
    echo "Migration completed!\n";
    echo "Successfully created: $successCount indexes\n";
    echo "Already existed: $skippedCount indexes\n";
    
    if ($errorCount > 0) {
        echo "Errors encountered: $errorCount\n";
    }
    
    echo "\nVerifying indexes...\n";
    
    // Verify some key indexes
    $tablesToCheck = ['likes', 'comments', 'follows', 'favorites', 'photos', 'albums', 'commercial_posts'];
    
    foreach ($tablesToCheck as $table) {
        $stmt = $conn->prepare("SHOW INDEX FROM $table");
        $stmt->execute();
        $indexes = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $indexCount = count(array_unique(array_column($indexes, 'Key_name')));
        echo "✓ Table '$table' has $indexCount indexes\n";
    }
    
    echo "\nIndex migration completed successfully!\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}
