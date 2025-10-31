import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  FlatList,
  Switch,
} from 'react-native';
import { communityService } from '../services/communityService';

const GroupDetailScreen = ({ route, navigation }) => {
  const { groupId } = route.params;
  const [group, setGroup] = useState(null);
  const [members, setMembers] = useState([]);
  const [incidents, setIncidents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('incidents'); // 'incidents' or 'members'
  const [notificationsEnabled, setNotificationsEnabled] = useState(true);

  useEffect(() => {
    loadGroupData();
  }, [groupId]);

  const loadGroupData = async () => {
    try {
      setLoading(true);
      const [groupData, membersData, incidentsData] = await Promise.all([
        communityService.getGroup(groupId),
        communityService.getGroupMembers(groupId),
        communityService.getGroupIncidents(groupId),
      ]);

      setGroup(groupData);
      setMembers(membersData);
      setIncidents(incidentsData.data);

      // Find current user's member record to get notification preference
      const currentMember = membersData.find((m) => m.user_id === groupData.created_by_id);
      if (currentMember) {
        setNotificationsEnabled(currentMember.notifications_enabled);
      }
    } catch (error) {
      console.error('Error loading group data:', error);
      Alert.alert('Error', 'Failed to load group details');
    } finally {
      setLoading(false);
    }
  };

  const handleLeaveGroup = () => {
    Alert.alert(
      'Leave Group',
      'Are you sure you want to leave this group?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Leave',
          style: 'destructive',
          onPress: async () => {
            try {
              await communityService.leaveGroup(groupId);
              navigation.goBack();
            } catch (error) {
              Alert.alert('Error', 'Failed to leave group');
            }
          },
        },
      ]
    );
  };

  const handleToggleNotifications = async (value) => {
    try {
      await communityService.updateNotificationPreferences(groupId, value);
      setNotificationsEnabled(value);
    } catch (error) {
      Alert.alert('Error', 'Failed to update notification preferences');
    }
  };

  const renderIncidentItem = ({ item }) => (
    <TouchableOpacity style={styles.incidentCard}>
      <View style={styles.incidentHeader}>
        <View style={[styles.incidentTypeBadge, { backgroundColor: getIncidentColor(item.type) }]}>
          <Text style={styles.incidentTypeText}>{item.type}</Text>
        </View>
        <Text style={styles.incidentTime}>{formatTime(item.inserted_at)}</Text>
      </View>
      {item.description && (
        <Text style={styles.incidentDescription} numberOfLines={2}>
          {item.description}
        </Text>
      )}
      <View style={styles.incidentFooter}>
        <Text style={styles.verificationText}>
          ✓ {item.verification_count} verifications
        </Text>
        {item.is_verified && (
          <View style={styles.verifiedBadge}>
            <Text style={styles.verifiedText}>Verified</Text>
          </View>
        )}
      </View>
    </TouchableOpacity>
  );

  const renderMemberItem = ({ item }) => (
    <View style={styles.memberCard}>
      <View style={styles.memberInfo}>
        <View style={styles.memberAvatar}>
          <Text style={styles.memberInitial}>
            {item.user?.phone_number?.charAt(0) || 'U'}
          </Text>
        </View>
        <View style={styles.memberDetails}>
          <Text style={styles.memberPhone}>{item.user?.phone_number || 'Unknown'}</Text>
          <Text style={styles.memberRole}>{item.role}</Text>
        </View>
      </View>
      {item.user?.is_premium && (
        <View style={styles.premiumBadge}>
          <Text style={styles.premiumText}>Premium</Text>
        </View>
      )}
    </View>
  );

  const getIncidentColor = (type) => {
    switch (type) {
      case 'hijacking':
        return '#E53E3E';
      case 'mugging':
        return '#ED8936';
      case 'accident':
        return '#3182CE';
      default:
        return '#718096';
    }
  };

  const formatTime = (timestamp) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    return `${diffDays}d ago`;
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#E53E3E" />
      </View>
    );
  }

  if (!group) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorText}>Group not found</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView>
        <View style={styles.groupHeader}>
          <Text style={styles.groupName}>{group.name}</Text>
          {group.description && (
            <Text style={styles.groupDescription}>{group.description}</Text>
          )}
          {group.location_name && (
            <Text style={styles.locationName}>📍 {group.location_name}</Text>
          )}
          <View style={styles.statsRow}>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{group.member_count}</Text>
              <Text style={styles.statLabel}>Members</Text>
            </View>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{incidents.length}</Text>
              <Text style={styles.statLabel}>Incidents</Text>
            </View>
          </View>

          <View style={styles.notificationRow}>
            <Text style={styles.notificationLabel}>Group Notifications</Text>
            <Switch
              value={notificationsEnabled}
              onValueChange={handleToggleNotifications}
              trackColor={{ false: '#CBD5E0', true: '#FC8181' }}
              thumbColor={notificationsEnabled ? '#E53E3E' : '#F7FAFC'}
            />
          </View>

          <TouchableOpacity style={styles.leaveButton} onPress={handleLeaveGroup}>
            <Text style={styles.leaveButtonText}>Leave Group</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.tabContainer}>
          <TouchableOpacity
            style={[styles.tab, activeTab === 'incidents' && styles.activeTab]}
            onPress={() => setActiveTab('incidents')}
          >
            <Text style={[styles.tabText, activeTab === 'incidents' && styles.activeTabText]}>
              Incidents
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.tab, activeTab === 'members' && styles.activeTab]}
            onPress={() => setActiveTab('members')}
          >
            <Text style={[styles.tabText, activeTab === 'members' && styles.activeTabText]}>
              Members
            </Text>
          </TouchableOpacity>
        </View>

        <View style={styles.contentContainer}>
          {activeTab === 'incidents' ? (
            <FlatList
              data={incidents}
              renderItem={renderIncidentItem}
              keyExtractor={(item) => item.id}
              scrollEnabled={false}
              ListEmptyComponent={
                <Text style={styles.emptyText}>No incidents in this group yet</Text>
              }
            />
          ) : (
            <FlatList
              data={members}
              renderItem={renderMemberItem}
              keyExtractor={(item) => item.id}
              scrollEnabled={false}
              ListEmptyComponent={
                <Text style={styles.emptyText}>No members found</Text>
              }
            />
          )}
        </View>
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F7FAFC',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorText: {
    fontSize: 16,
    color: '#718096',
  },
  groupHeader: {
    backgroundColor: '#FFFFFF',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
  },
  groupName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1A202C',
    marginBottom: 8,
  },
  groupDescription: {
    fontSize: 16,
    color: '#718096',
    marginBottom: 8,
  },
  locationName: {
    fontSize: 14,
    color: '#4A5568',
    marginBottom: 16,
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 16,
    paddingVertical: 12,
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: '#E2E8F0',
  },
  statItem: {
    alignItems: 'center',
  },
  statValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#E53E3E',
  },
  statLabel: {
    fontSize: 14,
    color: '#718096',
    marginTop: 4,
  },
  notificationRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  notificationLabel: {
    fontSize: 16,
    color: '#1A202C',
  },
  leaveButton: {
    backgroundColor: '#FFF5F5',
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E53E3E',
  },
  leaveButtonText: {
    color: '#E53E3E',
    fontWeight: '600',
    fontSize: 16,
  },
  tabContainer: {
    flexDirection: 'row',
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
  },
  tab: {
    flex: 1,
    paddingVertical: 12,
    alignItems: 'center',
  },
  activeTab: {
    borderBottomWidth: 2,
    borderBottomColor: '#E53E3E',
  },
  tabText: {
    fontSize: 16,
    color: '#718096',
  },
  activeTabText: {
    color: '#E53E3E',
    fontWeight: '600',
  },
  contentContainer: {
    padding: 16,
  },
  incidentCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  incidentHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  incidentTypeBadge: {
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
  },
  incidentTypeText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'capitalize',
  },
  incidentTime: {
    fontSize: 12,
    color: '#718096',
  },
  incidentDescription: {
    fontSize: 14,
    color: '#4A5568',
    marginBottom: 8,
  },
  incidentFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  verificationText: {
    fontSize: 12,
    color: '#718096',
  },
  verifiedBadge: {
    backgroundColor: '#C6F6D5',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  verifiedText: {
    color: '#22543D',
    fontSize: 12,
    fontWeight: '600',
  },
  memberCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  memberInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  memberAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#E53E3E',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  memberInitial: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
  },
  memberDetails: {
    flex: 1,
  },
  memberPhone: {
    fontSize: 16,
    color: '#1A202C',
    fontWeight: '500',
  },
  memberRole: {
    fontSize: 14,
    color: '#718096',
    textTransform: 'capitalize',
  },
  premiumBadge: {
    backgroundColor: '#FEF5E7',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  premiumText: {
    color: '#D97706',
    fontSize: 12,
    fontWeight: '600',
  },
  emptyText: {
    textAlign: 'center',
    color: '#718096',
    fontSize: 16,
    marginTop: 32,
  },
});

export default GroupDetailScreen;
