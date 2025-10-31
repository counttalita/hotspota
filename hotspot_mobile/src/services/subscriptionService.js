import apiClient from './apiClient';

class SubscriptionService {
  /**
   * Get available subscription plans
   */
  async getPlans() {
    try {
      const response = await apiClient.get('/subscriptions/plans');
      return response.data.data;
    } catch (error) {
      console.error('Get plans error:', error);
      throw new Error(error.response?.data?.error || 'Failed to load subscription plans');
    }
  }

  /**
   * Get current subscription status
   */
  async getStatus() {
    try {
      const response = await apiClient.get('/subscriptions/status');
      return response.data.data;
    } catch (error) {
      console.error('Get status error:', error);
      throw new Error(error.response?.data?.error || 'Failed to load subscription status');
    }
  }

  /**
   * Initialize a new subscription
   * @param {string} planType - 'monthly' or 'annual'
   */
  async initialize(planType) {
    try {
      const response = await apiClient.post('/subscriptions/initialize', {
        plan_type: planType,
      });
      return response.data.data;
    } catch (error) {
      console.error('Initialize subscription error:', error);
      throw new Error(error.response?.data?.error || 'Failed to initialize subscription');
    }
  }

  /**
   * Cancel current subscription
   * @param {string} reason - Optional cancellation reason
   */
  async cancel(reason = null) {
    try {
      const response = await apiClient.post('/subscriptions/cancel', {
        reason,
      });
      return response.data;
    } catch (error) {
      console.error('Cancel subscription error:', error);
      throw new Error(error.response?.data?.error || 'Failed to cancel subscription');
    }
  }
}

export const subscriptionService = new SubscriptionService();
