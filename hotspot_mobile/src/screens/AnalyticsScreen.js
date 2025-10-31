import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Dimensions,
  Alert,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { analyticsService } from '../services/analyticsService';

const { width } = Dimensions.get('window');

export default function AnalyticsScreen() {
  const [activeTab, setActiveTab] = useState('hotspots');
  const [loading, setLoading] = useState(true);
  const [isPremium, setIsPremium] = useState(false);
  
  // Data states
  const [hotspots, setHotspots] = useState([]);
  const [timePatterns, setTimePatterns] = useState([]);
  const [trends, setTrends] = useState([]);
  const [summary, setSummary] = useState(null);
  
  // Error states
  const [error, setError] = useState(null);

  useEffect(() => {
    loadUserStatus();
    loadAnalytics();
  }, [activeTab]);

  const loadUserStatus = async () => {
    try {
      const userStr = await AsyncStorage.getItem('user');
      if (userStr) {
        const user = JSON.parse(userStr);
        setIsPremium(user.is_premium || false);
      }
    } catch (err) {
      console.error('Error loading user status:', err);
    }
  };

  const loadAnalytics = async () => {
    setLoading(true);
    setError(null);
    
    try {
      // Load summary for all tabs
      const summaryData = await analyticsService.getSummary();
      setSummary(summaryData);

      // Load tab-specific data
      switch (activeTab) {
        case 'hotspots':
          try {
            const hotspotsData = await analyticsService.getTopHotspots();
            setHotspots(hotspotsData);
          } catch (err) {
            if (err.response?.status === 403) {
              setError('premium_required');
            } else {
              throw err;
            }
          }
          break;
        case 'patterns':
          const patternsData = await analyticsService.getTimePatterns();
          setTimePatterns(patternsData);
          break;
        case 'trends':
          const trendsData = await analyticsService.getWeeklyTrends(4);
          setTrends(trendsData);
          break;
      }
    } catch (err) {
      console.error('Error loading analytics:', err);
      setError('general');
      Alert.alert('Error', 'Failed to load analytics data. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const renderSummaryCards = () => {
    if (!summary) return null;

    return (
      <View style={styles.summaryContainer}>
        <View style={styles.summaryCard}>
          <Text style={styles.summaryValue}>{summary.active_incidents}</Text>
          <Text style={styles.summaryLabel}>Active Incidents</Text>
        </View>
        <View style={styles.summaryCard}>
          <Text style={styles.summaryValue}>{summary.incidents_today}</Text>
          <Text style={styles.summaryLabel}>Today</Text>
        </View>
        <View style={styles.summaryCard}>
          <Text style={styles.summaryValue}>
            {Math.round(summary.verification_rate * 100)}%
          </Text>
          <Text style={styles.summaryLabel}>Verified</Text>
        </View>
      </View>
    );
  };

  const renderHotspots = () => {
    if (error === 'premium_required') {
      return (
        <View style={styles.premiumUpsell}>
          <Text style={styles.premiumIcon}>👑</Text>
          <Text style={styles.premiumTitle}>Premium Feature</Text>
          <Text style={styles.premiumText}>
            Upgrade to Premium to access city-wide hotspot analytics and identify the most dangerous areas.
          </Text>
          <TouchableOpacity style={styles.upgradeButton}>
            <Text style={styles.upgradeButtonText}>Upgrade to Premium</Text>
          </TouchableOpacity>
        </View>
      );
    }

    if (hotspots.length === 0) {
      return (
        <View style={styles.emptyState}>
          <Text style={styles.emptyIcon}>📊</Text>
          <Text style={styles.emptyText}>No hotspot data available yet</Text>
        </View>
      );
    }

    return (
      <View style={styles.contentContainer}>
        <Text style={styles.sectionTitle}>Top 5 Hotspot Areas</Text>
        {hotspots.map((hotspot, index) => (
          <View key={index} style={styles.hotspotCard}>
            <View style={styles.hotspotRank}>
              <Text style={styles.rankNumber}>#{index + 1}</Text>
            </View>
            <View style={styles.hotspotInfo}>
              <Text style={styles.hotspotArea}>{hotspot.area_name}</Text>
              <Text style={styles.hotspotDetails}>
                {hotspot.incident_count} incidents • {hotspot.dominant_type}
              </Text>
              <Text style={styles.hotspotCoords}>
                {hotspot.center.latitude.toFixed(4)}, {hotspot.center.longitude.toFixed(4)}
              </Text>
            </View>
            <View style={[styles.typeIndicator, getTypeColor(hotspot.dominant_type)]} />
          </View>
        ))}
      </View>
    );
  };

  const renderTimePatterns = () => {
    if (timePatterns.length === 0) {
      return (
        <View style={styles.emptyState}>
          <Text style={styles.emptyIcon}>⏰</Text>
          <Text style={styles.emptyText}>No time pattern data available yet</Text>
        </View>
      );
    }

    // Find peak hours for each type
    const peakHijacking = timePatterns.reduce((max, p) => 
      p.hijacking_count > max.hijacking_count ? p : max, timePatterns[0]);
    const peakMugging = timePatterns.reduce((max, p) => 
      p.mugging_count > max.mugging_count ? p : max, timePatterns[0]);
    const peakAccident = timePatterns.reduce((max, p) => 
      p.accident_count > max.accident_count ? p : max, timePatterns[0]);

    // Get max count for scaling
    const maxCount = Math.max(...timePatterns.map(p => p.total_count));

    return (
      <View style={styles.contentContainer}>
        <Text style={styles.sectionTitle}>Peak Hours by Type</Text>
        
        <View style={styles.peakHoursContainer}>
          <View style={styles.peakHourCard}>
            <View style={[styles.peakHourIcon, styles.hijackingBg]}>
              <Text style={styles.peakHourEmoji}>🚗</Text>
            </View>
            <Text style={styles.peakHourType}>Hijacking</Text>
            <Text style={styles.peakHourTime}>{formatHour(peakHijacking.hour)}</Text>
            <Text style={styles.peakHourCount}>{peakHijacking.hijacking_count} incidents</Text>
          </View>

          <View style={styles.peakHourCard}>
            <View style={[styles.peakHourIcon, styles.muggingBg]}>
              <Text style={styles.peakHourEmoji}>👤</Text>
            </View>
            <Text style={styles.peakHourType}>Mugging</Text>
            <Text style={styles.peakHourTime}>{formatHour(peakMugging.hour)}</Text>
            <Text style={styles.peakHourCount}>{peakMugging.mugging_count} incidents</Text>
          </View>

          <View style={styles.peakHourCard}>
            <View style={[styles.peakHourIcon, styles.accidentBg]}>
              <Text style={styles.peakHourEmoji}>🚑</Text>
            </View>
            <Text style={styles.peakHourType}>Accident</Text>
            <Text style={styles.peakHourTime}>{formatHour(peakAccident.hour)}</Text>
            <Text style={styles.peakHourCount}>{peakAccident.accident_count} incidents</Text>
          </View>
        </View>

        <Text style={styles.sectionTitle}>24-Hour Pattern</Text>
        <View style={styles.chartContainer}>
          {timePatterns.map((pattern) => {
            const height = (pattern.total_count / maxCount) * 100;
            return (
              <View key={pattern.hour} style={styles.barContainer}>
                <View style={[styles.bar, { height: `${height}%` }]} />
                <Text style={styles.barLabel}>
                  {pattern.hour === 0 ? '12a' : pattern.hour < 12 ? `${pattern.hour}a` : pattern.hour === 12 ? '12p' : `${pattern.hour - 12}p`}
                </Text>
              </View>
            );
          })}
        </View>
      </View>
    );
  };

  const renderTrends = () => {
    if (trends.length === 0) {
      return (
        <View style={styles.emptyState}>
          <Text style={styles.emptyIcon}>📈</Text>
          <Text style={styles.emptyText}>No trend data available yet</Text>
        </View>
      );
    }

    const maxCount = Math.max(...trends.map(t => t.total_count));

    return (
      <View style={styles.contentContainer}>
        <Text style={styles.sectionTitle}>Weekly Trends (Past 4 Weeks)</Text>
        
        <View style={styles.trendChartContainer}>
          {trends.map((week, index) => {
            const height = (week.total_count / maxCount) * 150;
            return (
              <View key={index} style={styles.trendBarContainer}>
                <Text style={styles.trendCount}>{week.total_count}</Text>
                <View style={styles.stackedBar}>
                  <View 
                    style={[
                      styles.stackedBarSegment, 
                      styles.hijackingBg,
                      { height: (week.hijacking_count / week.total_count) * height }
                    ]} 
                  />
                  <View 
                    style={[
                      styles.stackedBarSegment, 
                      styles.muggingBg,
                      { height: (week.mugging_count / week.total_count) * height }
                    ]} 
                  />
                  <View 
                    style={[
                      styles.stackedBarSegment, 
                      styles.accidentBg,
                      { height: (week.accident_count / week.total_count) * height }
                    ]} 
                  />
                </View>
                <Text style={styles.trendLabel}>{week.week_label}</Text>
              </View>
            );
          })}
        </View>

        <View style={styles.legendContainer}>
          <View style={styles.legendItem}>
            <View style={[styles.legendDot, styles.hijackingBg]} />
            <Text style={styles.legendText}>Hijacking</Text>
          </View>
          <View style={styles.legendItem}>
            <View style={[styles.legendDot, styles.muggingBg]} />
            <Text style={styles.legendText}>Mugging</Text>
          </View>
          <View style={styles.legendItem}>
            <View style={[styles.legendDot, styles.accidentBg]} />
            <Text style={styles.legendText}>Accident</Text>
          </View>
        </View>
      </View>
    );
  };

  const formatHour = (hour) => {
    if (hour === 0) return '12:00 AM';
    if (hour < 12) return `${hour}:00 AM`;
    if (hour === 12) return '12:00 PM';
    return `${hour - 12}:00 PM`;
  };

  const getTypeColor = (type) => {
    switch (type) {
      case 'hijacking':
        return styles.hijackingBg;
      case 'mugging':
        return styles.muggingBg;
      case 'accident':
        return styles.accidentBg;
      default:
        return styles.defaultBg;
    }
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Analytics</Text>
        <Text style={styles.headerSubtitle}>Incident patterns and trends</Text>
      </View>

      {/* Summary Cards */}
      {renderSummaryCards()}

      {/* Tab Navigation */}
      <View style={styles.tabContainer}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'hotspots' && styles.activeTab]}
          onPress={() => setActiveTab('hotspots')}
        >
          <Text style={[styles.tabText, activeTab === 'hotspots' && styles.activeTabText]}>
            Hotspots
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'patterns' && styles.activeTab]}
          onPress={() => setActiveTab('patterns')}
        >
          <Text style={[styles.tabText, activeTab === 'patterns' && styles.activeTabText]}>
            Time Patterns
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'trends' && styles.activeTab]}
          onPress={() => setActiveTab('trends')}
        >
          <Text style={[styles.tabText, activeTab === 'trends' && styles.activeTabText]}>
            Trends
          </Text>
        </TouchableOpacity>
      </View>

      {/* Content */}
      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        {loading ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color="#007AFF" />
            <Text style={styles.loadingText}>Loading analytics...</Text>
          </View>
        ) : (
          <>
            {activeTab === 'hotspots' && renderHotspots()}
            {activeTab === 'patterns' && renderTimePatterns()}
            {activeTab === 'trends' && renderTrends()}
          </>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  header: {
    backgroundColor: '#FFF',
    paddingTop: 60,
    paddingBottom: 20,
    paddingHorizontal: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#000',
  },
  headerSubtitle: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  summaryContainer: {
    flexDirection: 'row',
    backgroundColor: '#FFF',
    paddingVertical: 16,
    paddingHorizontal: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  summaryCard: {
    flex: 1,
    alignItems: 'center',
  },
  summaryValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#007AFF',
  },
  summaryLabel: {
    fontSize: 12,
    color: '#666',
    marginTop: 4,
  },
  tabContainer: {
    flexDirection: 'row',
    backgroundColor: '#FFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  tab: {
    flex: 1,
    paddingVertical: 16,
    alignItems: 'center',
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  activeTab: {
    borderBottomColor: '#007AFF',
  },
  tabText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
  },
  activeTabText: {
    color: '#007AFF',
  },
  scrollView: {
    flex: 1,
  },
  contentContainer: {
    padding: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#000',
    marginBottom: 16,
    marginTop: 8,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 60,
  },
  loadingText: {
    marginTop: 12,
    fontSize: 14,
    color: '#666',
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyIcon: {
    fontSize: 48,
    marginBottom: 16,
  },
  emptyText: {
    fontSize: 16,
    color: '#666',
  },
  premiumUpsell: {
    backgroundColor: '#FFF',
    margin: 16,
    padding: 24,
    borderRadius: 12,
    alignItems: 'center',
  },
  premiumIcon: {
    fontSize: 48,
    marginBottom: 16,
  },
  premiumTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#000',
    marginBottom: 8,
  },
  premiumText: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    marginBottom: 20,
    lineHeight: 20,
  },
  upgradeButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  upgradeButtonText: {
    color: '#FFF',
    fontSize: 16,
    fontWeight: '600',
  },
  hotspotCard: {
    flexDirection: 'row',
    backgroundColor: '#FFF',
    padding: 16,
    borderRadius: 12,
    marginBottom: 12,
    alignItems: 'center',
  },
  hotspotRank: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#F0F0F0',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  rankNumber: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#007AFF',
  },
  hotspotInfo: {
    flex: 1,
  },
  hotspotArea: {
    fontSize: 16,
    fontWeight: '600',
    color: '#000',
    marginBottom: 4,
  },
  hotspotDetails: {
    fontSize: 14,
    color: '#666',
    marginBottom: 2,
  },
  hotspotCoords: {
    fontSize: 12,
    color: '#999',
  },
  typeIndicator: {
    width: 8,
    height: 40,
    borderRadius: 4,
  },
  peakHoursContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 24,
  },
  peakHourCard: {
    flex: 1,
    backgroundColor: '#FFF',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    marginHorizontal: 4,
  },
  peakHourIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 8,
  },
  peakHourEmoji: {
    fontSize: 24,
  },
  peakHourType: {
    fontSize: 12,
    fontWeight: '600',
    color: '#666',
    marginBottom: 4,
  },
  peakHourTime: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#000',
    marginBottom: 2,
  },
  peakHourCount: {
    fontSize: 11,
    color: '#999',
  },
  chartContainer: {
    flexDirection: 'row',
    height: 120,
    backgroundColor: '#FFF',
    borderRadius: 12,
    padding: 16,
    alignItems: 'flex-end',
    justifyContent: 'space-between',
  },
  barContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'flex-end',
    height: '100%',
  },
  bar: {
    width: '60%',
    backgroundColor: '#007AFF',
    borderTopLeftRadius: 4,
    borderTopRightRadius: 4,
    minHeight: 4,
  },
  barLabel: {
    fontSize: 8,
    color: '#999',
    marginTop: 4,
  },
  trendChartContainer: {
    flexDirection: 'row',
    height: 200,
    backgroundColor: '#FFF',
    borderRadius: 12,
    padding: 16,
    alignItems: 'flex-end',
    justifyContent: 'space-around',
    marginBottom: 16,
  },
  trendBarContainer: {
    alignItems: 'center',
    flex: 1,
  },
  trendCount: {
    fontSize: 12,
    fontWeight: '600',
    color: '#000',
    marginBottom: 4,
  },
  stackedBar: {
    width: 40,
    flexDirection: 'column-reverse',
    borderRadius: 4,
    overflow: 'hidden',
  },
  stackedBarSegment: {
    width: '100%',
  },
  trendLabel: {
    fontSize: 11,
    color: '#666',
    marginTop: 8,
  },
  legendContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    backgroundColor: '#FFF',
    padding: 12,
    borderRadius: 8,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 12,
  },
  legendDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 6,
  },
  legendText: {
    fontSize: 12,
    color: '#666',
  },
  hijackingBg: {
    backgroundColor: '#FF3B30',
  },
  muggingBg: {
    backgroundColor: '#FF9500',
  },
  accidentBg: {
    backgroundColor: '#007AFF',
  },
  defaultBg: {
    backgroundColor: '#999',
  },
});
