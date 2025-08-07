import { writable, type Writable } from 'svelte/store';
import { getAuthStatus, connectToGraph, disconnectFromGraph, type AuthInfo } from '$lib/utils/api';

interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: AuthInfo | null;
  error: string | null;
}

const initialState: AuthState = {
  isAuthenticated: false,
  isLoading: false,
  user: null,
  error: null
};

function createAuthStore() {
  const { subscribe, set, update }: Writable<AuthState> = writable(initialState);

  return {
    subscribe,
    
    // Initialize authentication state
    async initialize() {
      update(state => ({ ...state, isLoading: true, error: null }));
      
      try {
        const authInfo = await getAuthStatus();
        
        update(state => ({
          ...state,
          isAuthenticated: authInfo.isAuthenticated,
          user: authInfo,
          isLoading: false,
          error: authInfo.error || null
        }));
        
        return authInfo;
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Failed to check authentication';
        
        update(state => ({
          ...state,
          isAuthenticated: false,
          user: null,
          isLoading: false,
          error: errorMessage
        }));
        
        throw error;
      }
    },

    // Connect to Microsoft Graph
    async login(scopes?: string[], tenantId?: string) {
      update(state => ({ ...state, isLoading: true, error: null }));
      
      try {
        const result = await connectToGraph(scopes, tenantId);
        
        if (result.success) {
          // Refresh auth state after successful login
          await this.initialize();
        } else {
          update(state => ({
            ...state,
            isLoading: false,
            error: result.error || 'Login failed'
          }));
        }
        
        return result;
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Login failed';
        
        update(state => ({
          ...state,
          isLoading: false,
          error: errorMessage
        }));
        
        throw error;
      }
    },

    // Disconnect from Microsoft Graph
    async logout() {
      update(state => ({ ...state, isLoading: true, error: null }));
      
      try {
        const result = await disconnectFromGraph();
        
        update(state => ({
          ...state,
          isAuthenticated: false,
          user: null,
          isLoading: false,
          error: null
        }));
        
        return result;
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Logout failed';
        
        update(state => ({
          ...state,
          isLoading: false,
          error: errorMessage
        }));
        
        throw error;
      }
    },

    // Refresh authentication state
    async refresh() {
      return this.initialize();
    },

    // Clear error state
    clearError() {
      update(state => ({ ...state, error: null }));
    },

    // Reset store to initial state
    reset() {
      set(initialState);
    }
  };
}

export const authStore = createAuthStore();

// Export types for use in components
export type { AuthState, AuthInfo };
