// API Configuration
export const API_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:4000/api';
export const WS_URL = API_URL.replace('http://', 'ws://').replace('https://', 'wss://').replace('/api', '');
