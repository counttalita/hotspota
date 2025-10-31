import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  RefreshControl,
  ActivityIndicator,
  Alert,
} from 'react-native';
import * as Location from 'expo-location';
import { communityService } from '../services/communityService';

const CommunitiesScreen = ({ navigation }) => {
  const [myGroups, setMyGroups] = useState([]);
  const [nearbyGroups, setNearbyGroups] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [activeTab, setActiveTab] = useState('my'); // 'my' or 'nearby'

  useEffect(() => {
    loadGroups();
  }, []);

  const loadGroups = async () => {
    try {
      setLoading(true);

      // Load user's groups
      const myGroupsData = await communityService.getMyGroups();
      setMyGroups(myGroupsData);

      // Load nearby groups
      const location = await Location.getCurrentPositionAsync({});
      const nearbyGroupsData = await communityService.getGroups(
        location.coords.latitude,
        location.coords.longitude,
        10000 // 10km radius
      );
      setNearbyGroups(nearbyGroupsData);
    } catch (error) {
      console.error('Error loading groups:', error);
      Alert.alert('Error', 'Failed to load groups');
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadGroups();
    setRefreshing(false);
  };

  const handleJoinGroup = async (groupId) => {
    try {
      await communityService.joinGroup(groupId);
      Alert.alert('Success', 'You have joined the group');
      loadGroups();
    } catch (error) {
      console.error('Error joining group:', error);
      Alert.alert('Error', 'Failed to join group');
    }
  };

  const renderGroupItem = ({ item }) => {
    const isMember = myGroups.some((g) => g.id === item.id);

    return (
      <TouchableOpacity
        style={styles.groupCard}
        onPress={() => navigation.navigate('GroupDetail', { groupId: item.id })}
      >
        <View style={styles.groupHeader}>
          <Text style={styles.groupName}>{item.name}</Text>
          <View style={styles.memberBadge}>
            <Text style={styles.memberCount}>{item.member_count} members</Text>
          </View>
        </View>

        {item.description && (
          <Text style={styles.groupDescription} numberOfLines={2}>
            {item.description}
          </Text>
        )}

        {item.location_name && (
          <Text style={styles.locationName}>📍 {item.location_name}</Text>
        )}

        {!isMember && activeTab === 'nearby' && (
          <TouchableOpacity
            style={styles.joinButton}
            onPress={() => handleJoinGroup(item.id)}
          >
            <Text style={styles.joinButtonText}>Join Group</Text>
          </TouchableOpacity>
        )}
      </TouchableOpacity>
    );
  };

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <Text style={styles.emptyStateText}>
        {activeTab === 'my'
          ? 'You are not a member of any groups yet'
          : 'No nearby groups found'}
      </Text>
      {activeTab === 'my' && (
        <TouchableOpacity
          style={styles.createButton}
          onPress={() => navigation.navigate('CreateGroup')}
        >
          <Text style={styles.createButtonText}>Create a Group</Text>
        </TouchableOpacity>
      )}
    </View>
  );

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#E53E3E" />
      </View>
    );
  }

  const displayGroups = activeTab === 'my' ? myGroups : nearbyGroups;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Community Groups</Text>
        <TouchableOpacity
          style={styles.createIconButton}
          onPress={() => navigation.navigate('CreateGroup')}
        >
          <Text style={styles.createIcon}>+</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.tabContainer}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'my' && styles.activeTab]}
          onPress={() => setActiveTab('my')}
        >
          <Text style={[styles.tabText, activeTab === 'my' && styles.activeTabText]}>
            My Groups
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'nearby' && styles.activeTab]}
          onPress={() => setActiveTab('nearby')}
        >
          <Text style={[styles.tabText, activeTab === 'nearby' && styles.activeTabText]}>
            Nearby
          </Text>
        </TouchableOpacity>
      </View>

      <FlatList
        data={displayGroups}
        renderItem={renderGroupItem}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContent}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
        }
        ListEmptyComponent={renderEmptyState}
      />
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
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1A202C',
  },
  createIconButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#E53E3E',
    justifyContent: 'center',
    alignItems: 'center',
  },
  createIcon: {
    fontSize: 24,
    color: '#FFFFFF',
    fontWeight: 'bold',
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
  listContent: {
    padding: 16,
  },
  groupCard: {
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
  groupHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  groupName: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1A202C',
    flex: 1,
  },
  memberBadge: {
    backgroundColor: '#EDF2F7',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  memberCount: {
    fontSize: 12,
    color: '#4A5568',
  },
  groupDescription: {
    fontSize: 14,
    color: '#718096',
    marginBottom: 8,
  },
  locationName: {
    fontSize: 14,
    color: '#4A5568',
    marginBottom: 8,
  },
  joinButton: {
    backgroundColor: '#E53E3E',
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 8,
    alignSelf: 'flex-start',
    marginTop: 8,
  },
  joinButtonText: {
    color: '#FFFFFF',
    fontWeight: '600',
    fontSize: 14,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
  },
  emptyStateText: {
    fontSize: 16,
    color: '#718096',
    marginBottom: 16,
    textAlign: 'center',
  },
  createButton: {
    backgroundColor: '#E53E3E',
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 8,
  },
  createButtonText: {
    color: '#FFFFFF',
    fontWeight: '600',
    fontSize: 16,
  },
});

export default CommunitiesScreen;
