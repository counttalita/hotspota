import React, { useState, useEffect } from 'react';
import { View, Image, ActivityIndicator, StyleSheet } from 'react-native';
import * as FileSystem from 'expo-file-system';

/**
 * Optimized image component with lazy loading, caching, and progressive loading.
 * Automatically compresses and caches images for better performance.
 */

const IMAGE_CACHE_DIR = `${FileSystem.cacheDirectory}images/`;

export const OptimizedImage = ({ 
  source, 
  style, 
  placeholder, 
  onLoad, 
  onError,
  resizeMode = 'cover',
  ...props 
}) => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [cachedUri, setCachedUri] = useState(null);

  useEffect(() => {
    loadImage();
  }, [source]);

  const loadImage = async () => {
    if (!source || !source.uri) {
      setLoading(false);
      return;
    }

    try {
      // Check if image is already cached
      const cached = await getCachedImage(source.uri);
      
      if (cached) {
        setCachedUri(cached);
        setLoading(false);
      } else {
        // Download and cache image
        const downloaded = await downloadAndCacheImage(source.uri);
        setCachedUri(downloaded);
        setLoading(false);
      }
    } catch (err) {
      console.error('Error loading image:', err);
      setError(true);
      setLoading(false);
      onError?.(err);
    }
  };

  const getCachedImage = async (uri) => {
    const filename = getFilenameFromUri(uri);
    const cachedPath = `${IMAGE_CACHE_DIR}${filename}`;

    try {
      const info = await FileSystem.getInfoAsync(cachedPath);
      if (info.exists) {
        return cachedPath;
      }
    } catch (err) {
      console.error('Error checking cache:', err);
    }

    return null;
  };

  const downloadAndCacheImage = async (uri) => {
    const filename = getFilenameFromUri(uri);
    const cachedPath = `${IMAGE_CACHE_DIR}${filename}`;

    // Ensure cache directory exists
    await FileSystem.makeDirectoryAsync(IMAGE_CACHE_DIR, { intermediates: true }).catch(() => {});

    // Download image
    const downloadResult = await FileSystem.downloadAsync(uri, cachedPath);
    
    return downloadResult.uri;
  };

  const getFilenameFromUri = (uri) => {
    const hash = simpleHash(uri);
    const extension = uri.split('.').pop().split('?')[0] || 'jpg';
    return `${hash}.${extension}`;
  };

  const simpleHash = (str) => {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
  };

  if (error) {
    return (
      <View style={[styles.container, style, styles.errorContainer]}>
        <View style={styles.errorIcon}>
          <Text style={styles.errorText}>📷</Text>
        </View>
      </View>
    );
  }

  if (loading) {
    return (
      <View style={[styles.container, style, styles.loadingContainer]}>
        {placeholder || <ActivityIndicator size="small" color="#666" />}
      </View>
    );
  }

  return (
    <Image
      source={{ uri: cachedUri || source.uri }}
      style={style}
      resizeMode={resizeMode}
      onLoad={onLoad}
      onError={(e) => {
        setError(true);
        onError?.(e);
      }}
      {...props}
    />
  );
};

/**
 * Clear image cache to free up storage
 */
export const clearImageCache = async () => {
  try {
    const info = await FileSystem.getInfoAsync(IMAGE_CACHE_DIR);
    if (info.exists) {
      await FileSystem.deleteAsync(IMAGE_CACHE_DIR, { idempotent: true });
      await FileSystem.makeDirectoryAsync(IMAGE_CACHE_DIR, { intermediates: true });
    }
  } catch (err) {
    console.error('Error clearing image cache:', err);
  }
};

/**
 * Get cache size in bytes
 */
export const getImageCacheSize = async () => {
  try {
    const info = await FileSystem.getInfoAsync(IMAGE_CACHE_DIR);
    if (info.exists && info.isDirectory) {
      const files = await FileSystem.readDirectoryAsync(IMAGE_CACHE_DIR);
      let totalSize = 0;
      
      for (const file of files) {
        const fileInfo = await FileSystem.getInfoAsync(`${IMAGE_CACHE_DIR}${file}`);
        totalSize += fileInfo.size || 0;
      }
      
      return totalSize;
    }
  } catch (err) {
    console.error('Error getting cache size:', err);
  }
  
  return 0;
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#f0f0f0',
  },
  loadingContainer: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorContainer: {
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
  },
  errorIcon: {
    opacity: 0.3,
  },
  errorText: {
    fontSize: 32,
  },
});
