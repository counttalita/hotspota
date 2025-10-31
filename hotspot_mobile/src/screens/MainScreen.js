import React from 'react';
import { StyleSheet, Text } from 'react-native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import MapScreen from './MapScreen';
import IncidentFeedScreen from './IncidentFeedScreen';
import AnalyticsScreen from './AnalyticsScreen';

const Tab = createBottomTabNavigator();

export default function MainScreen() {
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: '#007AFF',
        tabBarInactiveTintColor: '#999',
        tabBarStyle: styles.tabBar,
        tabBarLabelStyle: styles.tabBarLabel,
      }}
    >
      <Tab.Screen
        name="Map"
        component={MapScreen}
        options={{
          tabBarIcon: ({ color }) => <TabIcon icon="🗺️" color={color} />,
          tabBarLabel: 'Map',
        }}
      />
      <Tab.Screen
        name="Feed"
        component={IncidentFeedScreen}
        options={{
          tabBarIcon: ({ color }) => <TabIcon icon="📋" color={color} />,
          tabBarLabel: 'Feed',
        }}
      />
      <Tab.Screen
        name="Analytics"
        component={AnalyticsScreen}
        options={{
          tabBarIcon: ({ color }) => <TabIcon icon="📊" color={color} />,
          tabBarLabel: 'Analytics',
        }}
      />
    </Tab.Navigator>
  );
}

// Simple icon component using emoji
const TabIcon = ({ icon, color }) => (
  <Text style={{ fontSize: 24, opacity: color === '#007AFF' ? 1 : 0.5 }}>
    {icon}
  </Text>
);

const styles = StyleSheet.create({
  tabBar: {
    backgroundColor: '#FFF',
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
    height: 60,
    paddingBottom: 8,
    paddingTop: 8,
  },
  tabBarLabel: {
    fontSize: 12,
    fontWeight: '600',
  },
});
