<?php
require_once 'config/admin_config.php';

adminRequireAuth();
?>
<!DOCTYPE html>
<html>
<head>
    <title>Check Posts API</title>
    <style>
        body { font-family: monospace; padding: 20px; }
        .success { color: green; }
        .error { color: red; }
        pre { background: #f5f5f5; padding: 10px; overflow: auto; }
    </style>
</head>
<body>
    <h1>Testing Posts API</h1>
    
    <h2>Test 1: get_all_posts.php</h2>
    <div id="test1"></div>
    
    <h2>Test 2: get_all_commercial_posts.php</h2>
    <div id="test2"></div>
    
    <script>
        // Test 1
        fetch('../api/posts/get_all_posts.php?page=1&per_page=2')
            .then(response => {
                console.log('Posts API Response status:', response.status);
                console.log('Posts API Response headers:', response.headers);
                return response.text();
            })
            .then(text => {
                console.log('Posts API Raw response:', text);
                document.getElementById('test1').innerHTML = '<pre>' + text + '</pre>';
                
                try {
                    const json = JSON.parse(text);
                    document.getElementById('test1').innerHTML += '<p class="success">✅ Valid JSON</p>';
                } catch (e) {
                    document.getElementById('test1').innerHTML += '<p class="error">❌ Invalid JSON: ' + e.message + '</p>';
                }
            })
            .catch(error => {
                document.getElementById('test1').innerHTML = '<p class="error">❌ Error: ' + error + '</p>';
            });
        
        // Test 2
        fetch('../api/posts/get_all_commercial_posts.php?page=1&per_page=2')
            .then(response => {
                console.log('Commercial API Response status:', response.status);
                return response.text();
            })
            .then(text => {
                console.log('Commercial API Raw response:', text);
                document.getElementById('test2').innerHTML = '<pre>' + text + '</pre>';
                
                try {
                    const json = JSON.parse(text);
                    document.getElementById('test2').innerHTML += '<p class="success">✅ Valid JSON</p>';
                } catch (e) {
                    document.getElementById('test2').innerHTML += '<p class="error">❌ Invalid JSON: ' + e.message + '</p>';
                }
            })
            .catch(error => {
                document.getElementById('test2').innerHTML = '<p class="error">❌ Error: ' + error + '</p>';
            });
    </script>
</body>
</html>
