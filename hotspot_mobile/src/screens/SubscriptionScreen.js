import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  Linking,
} from 'react-native';
import { subscriptionService } from '../services/subscriptionService';

const SubscriptionScreen = ({ navigation }) => {
  const [plans, setPlans] = useState([]);
  const [currentSubscription, setCurrentSubscription] = useState(null);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const [plansData, statusData] = await Promise.all([
        subscriptionService.getPlans(),
        subscriptionService.getStatus(),
      ]);
      setPlans(plansData);
      setCurrentSubscription(statusData);
    } catch (error) {
      console.error('Failed to load subscription data:', error);
      Alert.alert('Error', 'Failed to load subscription information');
    } finally {
      setLoading(false);
    }
  };

  const handleSubscribe = async (planType) => {
    try {
      setProcessing(true);
      const result = await subscriptionService.initialize(planType);
      
      // Open Paystack payment page
      const supported = await Linking.canOpenURL(result.authorization_url);
      if (supported) {
        await Linking.openURL(result.authorization_url);
        
        // Show message to user
        Alert.alert(
          'Payment Initiated',
          'Complete your payment in the browser. Your subscription will be activated once payment is confirmed.',
          [
            {
              text: 'OK',
              onPress: () => {
                // Refresh status after a delay
                setTimeout(() => loadData(), 3000);
              },
            },
          ]
        );
      } else {
        Alert.alert('Error', 'Cannot open payment page');
      }
    } catch (error) {
      console.error('Failed to initialize subscription:', error);
      Alert.alert('Error', error.message || 'Failed to start subscription process');
    } finally {
      setProcessing(false);
    }
  };

  const handleCancelSubscription = () => {
    Alert.alert(
      'Cancel Subscription',
      'Are you sure you want to cancel your premium subscription? You will lose access to premium features.',
      [
        { text: 'No', style: 'cancel' },
        {
          text: 'Yes, Cancel',
          style: 'destructive',
          onPress: async () => {
            try {
              setProcessing(true);
              await subscriptionService.cancel();
              Alert.alert('Success', 'Your subscription has been cancelled');
              loadData();
            } catch (error) {
              console.error('Failed to cancel subscription:', error);
              Alert.alert('Error', 'Failed to cancel subscription');
            } finally {
              setProcessing(false);
            }
          },
        },
      ]
    );
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-ZA', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  };

  const formatCurrency = (amount, currency = 'ZAR') => {
    return new Intl.NumberFormat('en-ZA', {
      style: 'currency',
      currency: currency,
    }).format(amount);
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#E63946" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      {/* Current Subscription Status */}
      {currentSubscription?.has_subscription && (
        <View style={styles.statusCard}>
          <Text style={styles.statusTitle}>Current Subscription</Text>
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Plan:</Text>
            <Text style={styles.statusValue}>
              {currentSubscription.plan_type === 'monthly' ? 'Monthly Premium' : 'Annual Premium'}
            </Text>
          </View>
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Status:</Text>
            <Text style={[
              styles.statusValue,
              currentSubscription.status === 'active' ? styles.activeStatus : styles.inactiveStatus
            ]}>
              {currentSubscription.status.toUpperCase()}
            </Text>
          </View>
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Expires:</Text>
            <Text style={styles.statusValue}>
              {formatDate(currentSubscription.expires_at)}
            </Text>
          </View>
          {currentSubscription.next_payment_date && (
            <View style={styles.statusRow}>
              <Text style={styles.statusLabel}>Next Payment:</Text>
              <Text style={styles.statusValue}>
                {formatDate(currentSubscription.next_payment_date)}
              </Text>
            </View>
          )}
          
          {currentSubscription.status === 'active' && (
            <TouchableOpacity
              style={styles.cancelButton}
              onPress={handleCancelSubscription}
              disabled={processing}
            >
              <Text style={styles.cancelButtonText}>Cancel Subscription</Text>
            </TouchableOpacity>
          )}
        </View>
      )}

      {/* Subscription Plans */}
      <Text style={styles.sectionTitle}>
        {currentSubscription?.has_subscription ? 'Upgrade Plan' : 'Choose Your Plan'}
      </Text>

      {plans.map((plan) => (
        <View key={plan.id} style={styles.planCard}>
          <View style={styles.planHeader}>
            <Text style={styles.planName}>{plan.name}</Text>
            <View style={styles.priceContainer}>
              <Text style={styles.price}>{formatCurrency(plan.price)}</Text>
              <Text style={styles.interval}>/{plan.interval}</Text>
            </View>
          </View>

          {plan.savings && (
            <View style={styles.savingsBadge}>
              <Text style={styles.savingsText}>{plan.savings}</Text>
            </View>
          )}

          <View style={styles.featuresContainer}>
            {plan.features.map((feature, index) => (
              <View key={index} style={styles.featureRow}>
                <Text style={styles.checkmark}>✓</Text>
                <Text style={styles.featureText}>{feature}</Text>
              </View>
            ))}
          </View>

          <TouchableOpacity
            style={[
              styles.subscribeButton,
              plan.id === 'annual' && styles.subscribeButtonAnnual,
            ]}
            onPress={() => handleSubscribe(plan.id)}
            disabled={processing || currentSubscription?.plan_type === plan.id}
          >
            {processing ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.subscribeButtonText}>
                {currentSubscription?.plan_type === plan.id
                  ? 'Current Plan'
                  : 'Subscribe Now'}
              </Text>
            )}
          </TouchableOpacity>
        </View>
      ))}

      {/* Premium Features Info */}
      <View style={styles.infoCard}>
        <Text style={styles.infoTitle}>Why Go Premium?</Text>
        <Text style={styles.infoText}>
          Premium members get access to advanced safety features including extended alert radius,
          city-wide analytics, Travel Mode for route planning, and priority support.
        </Text>
        <Text style={styles.infoText}>
          Cancel anytime. No hidden fees.
        </Text>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8F9FA',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F8F9FA',
  },
  statusCard: {
    backgroundColor: '#fff',
    margin: 16,
    padding: 20,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  statusTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginBottom: 16,
  },
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  statusLabel: {
    fontSize: 16,
    color: '#6C757D',
  },
  statusValue: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1A1A1A',
  },
  activeStatus: {
    color: '#28A745',
  },
  inactiveStatus: {
    color: '#DC3545',
  },
  cancelButton: {
    marginTop: 16,
    padding: 12,
    backgroundColor: '#DC3545',
    borderRadius: 8,
    alignItems: 'center',
  },
  cancelButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginHorizontal: 16,
    marginTop: 8,
    marginBottom: 16,
  },
  planCard: {
    backgroundColor: '#fff',
    marginHorizontal: 16,
    marginBottom: 16,
    padding: 20,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  planHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  planName: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1A1A1A',
  },
  priceContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
  },
  price: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#E63946',
  },
  interval: {
    fontSize: 16,
    color: '#6C757D',
    marginLeft: 4,
  },
  savingsBadge: {
    backgroundColor: '#28A745',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    alignSelf: 'flex-start',
    marginBottom: 16,
  },
  savingsText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  featuresContainer: {
    marginBottom: 20,
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  checkmark: {
    fontSize: 18,
    color: '#28A745',
    marginRight: 12,
    fontWeight: 'bold',
  },
  featureText: {
    fontSize: 16,
    color: '#495057',
    flex: 1,
  },
  subscribeButton: {
    backgroundColor: '#E63946',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  subscribeButtonAnnual: {
    backgroundColor: '#FFC107',
  },
  subscribeButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  infoCard: {
    backgroundColor: '#E7F3FF',
    margin: 16,
    padding: 20,
    borderRadius: 12,
    marginBottom: 32,
  },
  infoTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginBottom: 12,
  },
  infoText: {
    fontSize: 14,
    color: '#495057',
    lineHeight: 20,
    marginBottom: 8,
  },
});

export default SubscriptionScreen;
