import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Alert,
  TextInput,
  Modal,
  ActivityIndicator,
  SafeAreaView,
} from 'react-native';
import emergencyService from '../services/emergencyService';

const EmergencyContactsScreen = ({ navigation }) => {
  const [contacts, setContacts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingContact, setEditingContact] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    phone_number: '',
    relationship: '',
    priority: 1,
  });
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadContacts();
  }, []);

  const loadContacts = async () => {
    try {
      setLoading(true);
      const data = await emergencyService.getEmergencyContacts();
      setContacts(data);
    } catch (error) {
      console.error('Error loading contacts:', error);
      Alert.alert('Error', 'Failed to load emergency contacts');
    } finally {
      setLoading(false);
    }
  };

  const handleAddContact = () => {
    if (contacts.length >= 5) {
      Alert.alert('Limit Reached', 'You can only add up to 5 emergency contacts');
      return;
    }
    setFormData({
      name: '',
      phone_number: '',
      relationship: '',
      priority: contacts.length + 1,
    });
    setEditingContact(null);
    setShowAddModal(true);
  };

  const handleEditContact = (contact) => {
    setFormData({
      name: contact.name,
      phone_number: contact.phone_number,
      relationship: contact.relationship || '',
      priority: contact.priority,
    });
    setEditingContact(contact);
    setShowAddModal(true);
  };

  const handleSaveContact = async () => {
    // Validation
    if (!formData.name.trim()) {
      Alert.alert('Validation Error', 'Please enter a name');
      return;
    }
    if (!formData.phone_number.trim()) {
      Alert.alert('Validation Error', 'Please enter a phone number');
      return;
    }

    // Basic phone number validation
    const phoneRegex = /^\+?[1-9]\d{1,14}$/;
    if (!phoneRegex.test(formData.phone_number.replace(/[\s-]/g, ''))) {
      Alert.alert('Validation Error', 'Please enter a valid phone number (e.g., +1234567890)');
      return;
    }

    try {
      setSaving(true);
      if (editingContact) {
        await emergencyService.updateEmergencyContact(editingContact.id, formData);
      } else {
        await emergencyService.addEmergencyContact(formData);
      }
      setShowAddModal(false);
      loadContacts();
    } catch (error) {
      console.error('Error saving contact:', error);
      const errorMessage = error.response?.data?.error || 'Failed to save contact';
      Alert.alert('Error', errorMessage);
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteContact = (contact) => {
    Alert.alert(
      'Delete Contact',
      `Are you sure you want to delete ${contact.name}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await emergencyService.deleteEmergencyContact(contact.id);
              loadContacts();
            } catch (error) {
              console.error('Error deleting contact:', error);
              Alert.alert('Error', 'Failed to delete contact');
            }
          },
        },
      ]
    );
  };

  const renderContact = ({ item }) => (
    <View style={styles.contactCard}>
      <View style={styles.contactInfo}>
        <View style={styles.priorityBadge}>
          <Text style={styles.priorityText}>{item.priority}</Text>
        </View>
        <View style={styles.contactDetails}>
          <Text style={styles.contactName}>{item.name}</Text>
          <Text style={styles.contactPhone}>{item.phone_number}</Text>
          {item.relationship && (
            <Text style={styles.contactRelationship}>{item.relationship}</Text>
          )}
        </View>
      </View>
      <View style={styles.contactActions}>
        <TouchableOpacity
          style={styles.editButton}
          onPress={() => handleEditContact(item)}
        >
          <Text style={styles.editButtonText}>Edit</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.deleteButton}
          onPress={() => handleDeleteContact(item)}
        >
          <Text style={styles.deleteButtonText}>Delete</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#DC3545" />
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Text style={styles.backButton}>← Back</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Emergency Contacts</Text>
        <View style={{ width: 60 }} />
      </View>

      <View style={styles.infoBox}>
        <Text style={styles.infoText}>
          Add up to 5 emergency contacts who will be notified when you press the panic button.
        </Text>
      </View>

      <FlatList
        data={contacts}
        renderItem={renderContact}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContainer}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyText}>No emergency contacts added yet</Text>
            <Text style={styles.emptySubtext}>
              Add contacts who should be notified in case of emergency
            </Text>
          </View>
        }
      />

      <TouchableOpacity
        style={[
          styles.addButton,
          contacts.length >= 5 && styles.addButtonDisabled
        ]}
        onPress={handleAddContact}
        disabled={contacts.length >= 5}
      >
        <Text style={styles.addButtonText}>
          + Add Emergency Contact ({contacts.length}/5)
        </Text>
      </TouchableOpacity>

      {/* Add/Edit Contact Modal */}
      <Modal
        visible={showAddModal}
        transparent
        animationType="slide"
        onRequestClose={() => !saving && setShowAddModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>
              {editingContact ? 'Edit Contact' : 'Add Emergency Contact'}
            </Text>

            <TextInput
              style={styles.input}
              placeholder="Name *"
              value={formData.name}
              onChangeText={(text) => setFormData({ ...formData, name: text })}
              editable={!saving}
            />

            <TextInput
              style={styles.input}
              placeholder="Phone Number * (e.g., +1234567890)"
              value={formData.phone_number}
              onChangeText={(text) => setFormData({ ...formData, phone_number: text })}
              keyboardType="phone-pad"
              editable={!saving}
            />

            <TextInput
              style={styles.input}
              placeholder="Relationship (optional)"
              value={formData.relationship}
              onChangeText={(text) => setFormData({ ...formData, relationship: text })}
              editable={!saving}
            />

            <View style={styles.priorityContainer}>
              <Text style={styles.priorityLabel}>Priority (1-5):</Text>
              <View style={styles.priorityButtons}>
                {[1, 2, 3, 4, 5].map((priority) => (
                  <TouchableOpacity
                    key={priority}
                    style={[
                      styles.priorityButton,
                      formData.priority === priority && styles.priorityButtonActive
                    ]}
                    onPress={() => setFormData({ ...formData, priority })}
                    disabled={saving}
                  >
                    <Text
                      style={[
                        styles.priorityButtonText,
                        formData.priority === priority && styles.priorityButtonTextActive
                      ]}
                    >
                      {priority}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => setShowAddModal(false)}
                disabled={saving}
              >
                <Text style={styles.cancelButtonText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.modalButton, styles.saveButton]}
                onPress={handleSaveContact}
                disabled={saving}
              >
                {saving ? (
                  <ActivityIndicator color="#fff" />
                ) : (
                  <Text style={styles.saveButtonText}>Save</Text>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
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
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#E9ECEF',
  },
  backButton: {
    fontSize: 16,
    color: '#007BFF',
    fontWeight: '600',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1A1A1A',
  },
  infoBox: {
    backgroundColor: '#E7F3FF',
    padding: 16,
    margin: 16,
    borderRadius: 8,
    borderLeftWidth: 4,
    borderLeftColor: '#007BFF',
  },
  infoText: {
    fontSize: 14,
    color: '#495057',
    lineHeight: 20,
  },
  listContainer: {
    padding: 16,
  },
  contactCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  contactInfo: {
    flexDirection: 'row',
    marginBottom: 12,
  },
  priorityBadge: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#DC3545',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  priorityText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  contactDetails: {
    flex: 1,
  },
  contactName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginBottom: 4,
  },
  contactPhone: {
    fontSize: 14,
    color: '#6C757D',
    marginBottom: 2,
  },
  contactRelationship: {
    fontSize: 13,
    color: '#ADB5BD',
    fontStyle: 'italic',
  },
  contactActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  editButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
    backgroundColor: '#007BFF',
    marginRight: 8,
  },
  editButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  deleteButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
    backgroundColor: '#DC3545',
  },
  deleteButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: 48,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#6C757D',
    marginBottom: 8,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#ADB5BD',
    textAlign: 'center',
  },
  addButton: {
    backgroundColor: '#DC3545',
    padding: 16,
    margin: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  addButtonDisabled: {
    backgroundColor: '#ADB5BD',
  },
  addButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: 24,
    maxHeight: '80%',
  },
  modalTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginBottom: 24,
    textAlign: 'center',
  },
  input: {
    borderWidth: 1,
    borderColor: '#DEE2E6',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    marginBottom: 16,
    backgroundColor: '#F8F9FA',
  },
  priorityContainer: {
    marginBottom: 24,
  },
  priorityLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#495057',
    marginBottom: 12,
  },
  priorityButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  priorityButton: {
    width: 50,
    height: 50,
    borderRadius: 25,
    borderWidth: 2,
    borderColor: '#DEE2E6',
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  priorityButtonActive: {
    borderColor: '#DC3545',
    backgroundColor: '#DC3545',
  },
  priorityButtonText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#6C757D',
  },
  priorityButtonTextActive: {
    color: '#fff',
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  modalButton: {
    flex: 1,
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  cancelButton: {
    backgroundColor: '#6C757D',
    marginRight: 8,
  },
  saveButton: {
    backgroundColor: '#DC3545',
    marginLeft: 8,
  },
  cancelButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  saveButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});

export default EmergencyContactsScreen;
