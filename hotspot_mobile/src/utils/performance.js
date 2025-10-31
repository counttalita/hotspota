/**
 * Performance monitoring utilities for tracking app performance metrics.
 * Helps identify bottlenecks and optimize user experience.
 */

class PerformanceMonitor {
  constructor() {
    this.metrics = new Map();
    this.enabled = __DEV__; // Only enable in development by default
  }

  /**
   * Start timing an operation
   */
  startTimer(label) {
    if (!this.enabled) return;
    
    this.metrics.set(label, {
      startTime: Date.now(),
      label,
    });
  }

  /**
   * End timing an operation and log the duration
   */
  endTimer(label) {
    if (!this.enabled) return;

    const metric = this.metrics.get(label);
    if (!metric) {
      console.warn(`No timer found for label: ${label}`);
      return;
    }

    const duration = Date.now() - metric.startTime;
    this.metrics.delete(label);

    // Log slow operations
    if (duration > 1000) {
      console.warn(`⚠️ Slow operation: ${label} took ${duration}ms`);
    } else if (duration > 500) {
      console.log(`⏱️ ${label} took ${duration}ms`);
    }

    return duration;
  }

  /**
   * Measure the execution time of an async function
   */
  async measureAsync(label, fn) {
    if (!this.enabled) {
      return await fn();
    }

    this.startTimer(label);
    try {
      const result = await fn();
      this.endTimer(label);
      return result;
    } catch (error) {
      this.endTimer(label);
      throw error;
    }
  }

  /**
   * Measure the execution time of a sync function
   */
  measure(label, fn) {
    if (!this.enabled) {
      return fn();
    }

    this.startTimer(label);
    try {
      const result = fn();
      this.endTimer(label);
      return result;
    } catch (error) {
      this.endTimer(label);
      throw error;
    }
  }

  /**
   * Log memory usage (React Native specific)
   */
  logMemoryUsage() {
    if (!this.enabled) return;

    if (global.performance && global.performance.memory) {
      const memory = global.performance.memory;
      console.log('Memory Usage:', {
        usedJSHeapSize: `${(memory.usedJSHeapSize / 1048576).toFixed(2)} MB`,
        totalJSHeapSize: `${(memory.totalJSHeapSize / 1048576).toFixed(2)} MB`,
        jsHeapSizeLimit: `${(memory.jsHeapSizeLimit / 1048576).toFixed(2)} MB`,
      });
    }
  }

  /**
   * Enable or disable performance monitoring
   */
  setEnabled(enabled) {
    this.enabled = enabled;
  }

  /**
   * Clear all active timers
   */
  clear() {
    this.metrics.clear();
  }
}

// Singleton instance
const performanceMonitor = new PerformanceMonitor();

/**
 * React hook for measuring component render performance
 */
export const usePerformanceMonitor = (componentName) => {
  const renderCount = React.useRef(0);
  const mountTime = React.useRef(Date.now());

  React.useEffect(() => {
    renderCount.current += 1;

    if (__DEV__ && renderCount.current > 10) {
      const timeSinceMount = Date.now() - mountTime.current;
      console.warn(
        `⚠️ ${componentName} has rendered ${renderCount.current} times in ${timeSinceMount}ms`
      );
    }
  });

  return {
    renderCount: renderCount.current,
    timeSinceMount: Date.now() - mountTime.current,
  };
};

/**
 * Decorator for measuring function performance
 */
export const measurePerformance = (label) => {
  return (target, propertyKey, descriptor) => {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args) {
      return await performanceMonitor.measureAsync(
        `${target.constructor.name}.${propertyKey}`,
        () => originalMethod.apply(this, args)
      );
    };

    return descriptor;
  };
};

/**
 * Track API request performance
 */
export const trackApiRequest = async (endpoint, requestFn) => {
  return await performanceMonitor.measureAsync(`API: ${endpoint}`, requestFn);
};

/**
 * Track database query performance
 */
export const trackDbQuery = async (queryName, queryFn) => {
  return await performanceMonitor.measureAsync(`DB: ${queryName}`, queryFn);
};

/**
 * Track image loading performance
 */
export const trackImageLoad = (imageUri) => {
  const label = `Image Load: ${imageUri.substring(0, 50)}...`;
  performanceMonitor.startTimer(label);
  
  return () => performanceMonitor.endTimer(label);
};

/**
 * Track screen navigation performance
 */
export const trackNavigation = (screenName) => {
  performanceMonitor.startTimer(`Navigate to ${screenName}`);
  
  return () => performanceMonitor.endTimer(`Navigate to ${screenName}`);
};

/**
 * Performance metrics aggregator
 */
class MetricsAggregator {
  constructor() {
    this.metrics = {
      apiCalls: [],
      screenLoads: [],
      imageLoads: [],
      errors: [],
    };
  }

  recordApiCall(endpoint, duration, success) {
    this.metrics.apiCalls.push({
      endpoint,
      duration,
      success,
      timestamp: Date.now(),
    });

    // Keep only last 100 entries
    if (this.metrics.apiCalls.length > 100) {
      this.metrics.apiCalls.shift();
    }
  }

  recordScreenLoad(screenName, duration) {
    this.metrics.screenLoads.push({
      screenName,
      duration,
      timestamp: Date.now(),
    });

    if (this.metrics.screenLoads.length > 50) {
      this.metrics.screenLoads.shift();
    }
  }

  recordImageLoad(uri, duration, success) {
    this.metrics.imageLoads.push({
      uri,
      duration,
      success,
      timestamp: Date.now(),
    });

    if (this.metrics.imageLoads.length > 100) {
      this.metrics.imageLoads.shift();
    }
  }

  recordError(error, context) {
    this.metrics.errors.push({
      message: error.message,
      stack: error.stack,
      context,
      timestamp: Date.now(),
    });

    if (this.metrics.errors.length > 50) {
      this.metrics.errors.shift();
    }
  }

  getMetrics() {
    return {
      ...this.metrics,
      summary: {
        avgApiDuration: this.calculateAverage(this.metrics.apiCalls, 'duration'),
        avgScreenLoadDuration: this.calculateAverage(this.metrics.screenLoads, 'duration'),
        avgImageLoadDuration: this.calculateAverage(this.metrics.imageLoads, 'duration'),
        apiSuccessRate: this.calculateSuccessRate(this.metrics.apiCalls),
        totalErrors: this.metrics.errors.length,
      },
    };
  }

  calculateAverage(items, key) {
    if (items.length === 0) return 0;
    const sum = items.reduce((acc, item) => acc + item[key], 0);
    return Math.round(sum / items.length);
  }

  calculateSuccessRate(items) {
    if (items.length === 0) return 100;
    const successful = items.filter(item => item.success).length;
    return Math.round((successful / items.length) * 100);
  }

  clear() {
    this.metrics = {
      apiCalls: [],
      screenLoads: [],
      imageLoads: [],
      errors: [],
    };
  }
}

export const metricsAggregator = new MetricsAggregator();

export default performanceMonitor;
