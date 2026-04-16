<?php
/**
 * Cache Configuration for Admin Panel
 * Simple file-based caching system for dashboard statistics
 */

class AdminCache {
    private $cacheDir;
    private $defaultTTL = 300; // 5 minutes default cache time
    
    public function __construct() {
        $this->cacheDir = __DIR__ . '/../cache/';
        
        // Create cache directory if it doesn't exist
        if (!file_exists($this->cacheDir)) {
            mkdir($this->cacheDir, 0755, true);
        }
    }
    
    /**
     * Get cached data
     * @param string $key Cache key
     * @return mixed|null Returns cached data or null if not found/expired
     */
    public function get($key) {
        $filename = $this->getCacheFilename($key);
        
        if (!file_exists($filename)) {
            return null;
        }
        
        $data = file_get_contents($filename);
        $cache = json_decode($data, true);
        
        if (!$cache || !isset($cache['expires_at']) || !isset($cache['data'])) {
            return null;
        }
        
        // Check if cache has expired
        if (time() > $cache['expires_at']) {
            unlink($filename);
            return null;
        }
        
        return $cache['data'];
    }
    
    /**
     * Set cached data
     * @param string $key Cache key
     * @param mixed $data Data to cache
     * @param int $ttl Time to live in seconds (default: 300)
     * @return bool Success status
     */
    public function set($key, $data, $ttl = null) {
        if ($ttl === null) {
            $ttl = $this->defaultTTL;
        }
        
        $filename = $this->getCacheFilename($key);
        
        $cache = [
            'data' => $data,
            'expires_at' => time() + $ttl,
            'created_at' => time()
        ];
        
        return file_put_contents($filename, json_encode($cache)) !== false;
    }
    
    /**
     * Delete cached data
     * @param string $key Cache key
     * @return bool Success status
     */
    public function delete($key) {
        $filename = $this->getCacheFilename($key);
        
        if (file_exists($filename)) {
            return unlink($filename);
        }
        
        return true;
    }
    
    /**
     * Clear all cache
     * @return bool Success status
     */
    public function clear() {
        $files = glob($this->cacheDir . '*.cache');
        
        foreach ($files as $file) {
            if (is_file($file)) {
                unlink($file);
            }
        }
        
        return true;
    }
    
    /**
     * Get cache filename for a key
     * @param string $key Cache key
     * @return string Full path to cache file
     */
    private function getCacheFilename($key) {
        $hash = md5($key);
        return $this->cacheDir . $hash . '.cache';
    }
    
    /**
     * Clean expired cache files
     * @return int Number of files deleted
     */
    public function cleanExpired() {
        $files = glob($this->cacheDir . '*.cache');
        $deleted = 0;
        
        foreach ($files as $file) {
            if (is_file($file)) {
                $data = file_get_contents($file);
                $cache = json_decode($data, true);
                
                if (!$cache || !isset($cache['expires_at']) || time() > $cache['expires_at']) {
                    unlink($file);
                    $deleted++;
                }
            }
        }
        
        return $deleted;
    }
}

// Create global cache instance
$adminCache = new AdminCache();
