<?php
if (function_exists('opcache_reset')) {
    opcache_reset();
    echo "OpCache cleared successfully!";
} else {
    echo "OpCache is not enabled";
}

if (function_exists('apcu_clear_cache')) {
    apcu_clear_cache();
    echo "<br>APCu cache cleared!";
}

echo "<br><br>Please refresh the admin pages now.";
