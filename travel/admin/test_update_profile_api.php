<!DOCTYPE html>
<html>
<head>
    <title>Тест API обновления профиля</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .test-section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; }
        .success { color: green; }
        .error { color: red; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }
        button { padding: 10px 20px; margin: 5px; cursor: pointer; }
    </style>
</head>
<body>
    <h1>Тест API обновления профиля</h1>
    
    <div class="test-section">
        <h2>1. Тест с датой в формате YYYY-MM-DD</h2>
        <button onclick="testUpdate('2024-01-15', 'YYYY-MM-DD')">Тест</button>
        <div id="result1"></div>
    </div>
    
    <div class="test-section">
        <h2>2. Тест с датой в формате ISO 8601</h2>
        <button onclick="testUpdate('2024-01-15T00:00:00.000Z', 'ISO 8601')">Тест</button>
        <div id="result2"></div>
    </div>
    
    <div class="test-section">
        <h2>3. Тест с датой в формате MM/DD/YYYY</h2>
        <button onclick="testUpdate('01/15/2024', 'MM/DD/YYYY')">Тест</button>
        <div id="result3"></div>
    </div>
    
    <div class="test-section">
        <h2>4. Тест с полем dateOfBirth</h2>
        <button onclick="testUpdateWithDifferentField('2024-01-15', 'dateOfBirth')">Тест</button>
        <div id="result4"></div>
    </div>

    <script>
        async function testUpdate(dateValue, format) {
            const resultDiv = document.getElementById('result' + (format === 'YYYY-MM-DD' ? '1' : format === 'ISO 8601' ? '2' : '3'));
            resultDiv.innerHTML = '<p>Отправка запроса...</p>';
            
            try {
                const response = await fetch('../user/update_profile.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        firstName: 'Test',
                        lastName: 'User',
                        birthday: dateValue
                    })
                });
                
                const data = await response.json();
                
                resultDiv.innerHTML = `
                    <p class="${data.success ? 'success' : 'error'}">
                        ${data.success ? '✓ Успешно' : '✗ Ошибка'}
                    </p>
                    <pre>${JSON.stringify(data, null, 2)}</pre>
                `;
            } catch (error) {
                resultDiv.innerHTML = `<p class="error">Ошибка: ${error.message}</p>`;
            }
        }
        
        async function testUpdateWithDifferentField(dateValue, fieldName) {
            const resultDiv = document.getElementById('result4');
            resultDiv.innerHTML = '<p>Отправка запроса...</p>';
            
            try {
                const body = {
                    firstName: 'Test',
                    lastName: 'User'
                };
                body[fieldName] = dateValue;
                
                const response = await fetch('../user/update_profile.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(body)
                });
                
                const data = await response.json();
                
                resultDiv.innerHTML = `
                    <p class="${data.success ? 'success' : 'error'}">
                        ${data.success ? '✓ Успешно' : '✗ Ошибка'}
                    </p>
                    <pre>${JSON.stringify(data, null, 2)}</pre>
                `;
            } catch (error) {
                resultDiv.innerHTML = `<p class="error">Ошибка: ${error.message}</p>`;
            }
        }
    </script>
</body>
</html>
