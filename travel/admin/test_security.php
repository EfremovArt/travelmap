<?php
/**
 * Security Features Test Script
 * 
 * This script tests the security features implemented in the admin panel.
 * Run this from the command line: php test_security.php
 */

require_once __DIR__ . '/config/admin_config.php';

echo "=== TravelMap Admin Panel - Security Tests ===\n\n";

$passed = 0;
$failed = 0;

// Test 1: CSRF Token Generation
echo "Test 1: CSRF Token Generation\n";
try {
    if (session_status() == PHP_SESSION_NONE) {
        session_start();
    }
    $token1 = generateCsrfToken();
    $token2 = generateCsrfToken();
    
    if (strlen($token1) === 64 && $token1 === $token2) {
        echo "  ✓ CSRF token generated correctly\n";
        $passed++;
    } else {
        echo "  ✗ CSRF token generation failed\n";
        $failed++;
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Test 2: CSRF Token Verification
echo "\nTest 2: CSRF Token Verification\n";
try {
    $token = generateCsrfToken();
    
    if (verifyCsrfToken($token)) {
        echo "  ✓ Valid token verified correctly\n";
        $passed++;
    } else {
        echo "  ✗ Valid token verification failed\n";
        $failed++;
    }
    
    if (!verifyCsrfToken('invalid_token')) {
        echo "  ✓ Invalid token rejected correctly\n";
        $passed++;
    } else {
        echo "  ✗ Invalid token not rejected\n";
        $failed++;
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Test 3: Input Validation - Integers
echo "\nTest 3: Input Validation - Integers\n";
try {
    $tests = [
        ['value' => '123', 'min' => 1, 'max' => 200, 'expected' => 123],
        ['value' => '0', 'min' => 1, 'max' => 200, 'expected' => false],
        ['value' => '300', 'min' => 1, 'max' => 200, 'expected' => false],
        ['value' => 'abc', 'min' => 1, 'max' => 200, 'expected' => false],
    ];
    
    $allPassed = true;
    foreach ($tests as $test) {
        $result = validateInt($test['value'], $test['min'], $test['max']);
        if ($result !== $test['expected']) {
            echo "  ✗ Failed for value: {$test['value']}\n";
            $allPassed = false;
        }
    }
    
    if ($allPassed) {
        echo "  ✓ Integer validation working correctly\n";
        $passed++;
    } else {
        $failed++;
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Test 4: Input Validation - Strings
echo "\nTest 4: Input Validation - Strings\n";
try {
    $tests = [
        ['value' => 'hello', 'min' => 1, 'max' => 10, 'expected' => 'hello'],
        ['value' => '', 'min' => 1, 'max' => 10, 'expected' => false],
        ['value' => 'this is a very long string', 'min' => 1, 'max' => 10, 'expected' => false],
        ['value' => '  test  ', 'min' => 1, 'max' => 10, 'expected' => 'test'],
    ];
    
    $allPassed = true;
    foreach ($tests as $test) {
        $result = validateString($test['value'], $test['min'], $test['max']);
        if ($result !== $test['expected']) {
            echo "  ✗ Failed for value: '{$test['value']}'\n";
            $allPassed = false;
        }
    }
    
    if ($allPassed) {
        echo "  ✓ String validation working correctly\n";
        $passed++;
    } else {
        $failed++;
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Test 5: Input Validation - Email
echo "\nTest 5: Input Validation - Email\n";
try {
    $tests = [
        ['value' => 'test@example.com', 'expected' => 'test@example.com'],
        ['value' => 'invalid-email', 'expected' => false],
        ['value' => 'test@', 'expected' => false],
        ['value' => '@example.com', 'expected' => false],
    ];
    
    $allPassed = true;
    foreach ($tests as $test) {
        $result = validateEmail($test['value']);
        if ($result !== $test['expected']) {
            echo "  ✗ Failed for value: {$test['value']}\n";
            $allPassed = false;
        }
    }
    
    if ($allPassed) {
        echo "  ✓ Email validation working correctly\n";
        $passed++;
    } else {
        $failed++;
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Test 6: Output Escaping
echo "\nTest 6: Output Escaping\n";
try {
    $tests = [
        ['input' => '<script>alert("xss")</script>', 'expected' => '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;'],
        ['input' => 'Hello & goodbye', 'expected' => 'Hello &amp; goodbye'],
        ['input' => "It's a test", 'expected' => 'It&#039;s a test'],
    ];
    
    $allPassed = true;
    foreach ($tests as $test) {
        $result = escapeHtml($test['input']);
        if ($result !== $test['expected']) {
            echo "  ✗ Failed for input: {$test['input']}\n";
            echo "    Expected: {$test['expected']}\n";
            echo "    Got: $result\n";
            $allPassed = false;
        }
    }
    
    if ($allPassed) {
        echo "  ✓ HTML escaping working correctly\n";
        $passed++;
    } else {
        $failed++;
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Test 7: Database Tables Exist
echo "\nTest 7: Security Database Tables\n";
try {
    $db = connectToDatabase();
    
    $tables = ['admin_logs', 'login_attempts'];
    $allExist = true;
    
    foreach ($tables as $table) {
        $stmt = $db->query("SHOW TABLES LIKE '$table'");
        if ($stmt->rowCount() > 0) {
            echo "  ✓ Table '$table' exists\n";
        } else {
            echo "  ✗ Table '$table' NOT found\n";
            $allExist = false;
        }
    }
    
    if ($allExist) {
        $passed++;
    } else {
        $failed++;
        echo "  → Run install_security.php to create missing tables\n";
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Test 8: Admin Logging Function
echo "\nTest 8: Admin Action Logging\n";
try {
    // Set a test admin ID in session
    $_SESSION['admin_id'] = 1;
    
    $result = logAdminAction('test_action', ['test' => 'data'], 'test', 123);
    
    if ($result) {
        echo "  ✓ Admin action logged successfully\n";
        $passed++;
        
        // Clean up test log
        $db = connectToDatabase();
        $stmt = $db->prepare("DELETE FROM admin_logs WHERE action = 'test_action' AND admin_id = 1");
        $stmt->execute();
    } else {
        echo "  ✗ Admin action logging failed\n";
        $failed++;
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Test 9: Login Attempt Recording
echo "\nTest 9: Login Attempt Recording\n";
try {
    $result = recordLoginAttempt('test_user', false, '127.0.0.1');
    
    if ($result) {
        echo "  ✓ Login attempt recorded successfully\n";
        $passed++;
        
        // Clean up test attempt
        $db = connectToDatabase();
        $stmt = $db->prepare("DELETE FROM login_attempts WHERE username = 'test_user'");
        $stmt->execute();
    } else {
        echo "  ✗ Login attempt recording failed\n";
        $failed++;
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Test 10: Brute Force Check
echo "\nTest 10: Brute Force Protection Check\n";
try {
    $result = checkLoginAttempts('nonexistent_user');
    
    if (isset($result['allowed']) && $result['allowed'] === true) {
        echo "  ✓ Brute force check working correctly\n";
        $passed++;
    } else {
        echo "  ✗ Brute force check failed\n";
        $failed++;
    }
} catch (Exception $e) {
    echo "  ✗ Error: " . $e->getMessage() . "\n";
    $failed++;
}

// Summary
echo "\n=== Test Summary ===\n";
echo "Passed: $passed\n";
echo "Failed: $failed\n";
echo "Total:  " . ($passed + $failed) . "\n\n";

if ($failed === 0) {
    echo "✓ All tests passed! Security features are working correctly.\n\n";
    exit(0);
} else {
    echo "✗ Some tests failed. Please review the errors above.\n\n";
    exit(1);
}
