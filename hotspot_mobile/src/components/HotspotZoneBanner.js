import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react';

const RISK_LEVEL_COLORS = {
  low: {
    background: '#FEF3C7',
    border: '#FCD34D',
    text: '#92400E',
  },
  medium: {
    background: '#FED7AA',
    border: '#FB923C',
    text: '#9A3412',
  },
  high: {
    background: '#FECACA',
    border: '#F87171',
    text: '#991B1B',
  },
  critical: {
    background: '#FEE2E2',
    border: '#EF4444',
    text: '#7F1D1D',
  },
};

const RISK_LEVEL_ICONS = {
  low: '⚠️',
  medium: '⚠️',
  high: '🚨',
  critical: '🚨',
};

const HotspotZoneBanner = ({ zone, action, onDismiss }) => {
  if (!zone) return null;

  const colors = RISK_LEVEL_COLORS[zone.risk_level] || RISK_LEVEL_COLORS.low;
  const icon = RISK_LEVEL_ICONS[zone.risk_level] || '⚠️';

  const getMessage = () => {
    if (action === 'entered') {
      return `Entering ${zone.risk_level.toUpperCase()} RISK zone - ${zone.incident_count} ${zone.zone_type} reported in this area in the past 7 days. Stay alert.`;
    } else if (action === 'exited') {
      return 'You have left the hotspot zone. Stay safe.';
    } else if (action === 'approaching') {
      return `Approaching ${zone.risk_level.toUpperCase()} RISK zone ahead - ${zone.incident_count} ${zone.zone_type} reported`;
    }
    return zone.message || 'Hotspot zone alert';
  };

  return (
    <View style={[styles.container, { backgroundColor: colors.background, borderColor: colors.border }]}>
      <View style={styles.content}>
        <Text style={styles.icon}>{icon}</Text>
        <Text style={[styles.message, { color: colors.text }]}>
          {getMessage()}
        </Text>
      </View>
      {onDismiss && (
        <TouchableOpacity onPress={onDismiss} style={styles.dismissButton}>
          <Text style={[styles.dismissText, { color: colors.text }]}>✕</Text>
        </TouchableOpacity>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 60,
    left: 20,
    right: 20,
    borderRadius: 12,
    borderWidth: 2,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'flex-start',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
    zIndex: 1000,
  },
  content: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  icon: {
    fontSize: 20,
    marginRight: 12,
  },
  message: {
    flex: 1,
    fontSize: 14,
    fontWeight: '600',
    lineHeight: 20,
  },
  dismissButton: {
    marginLeft: 8,
    padding: 4,
  },
  dismissText: {
    fontSize: 20,
    fontWeight: '600',
  },
});

export default HotspotZoneBanner;
