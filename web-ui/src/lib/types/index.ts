import { z } from 'zod';

// Security-first validation schemas

export const ContactSchema = z.object({
  id: z.string().uuid().optional(),
  firstName: z.string().min(1).max(50).regex(/^[a-zA-Z\s\-']+$/), // No special chars except hyphen and apostrophe
  lastName: z.string().min(1).max(50).regex(/^[a-zA-Z\s\-']+$/),
  email: z.string().email().max(100),
  phone: z.string().regex(/^[\d\s\-\+\(\)]+$/).max(20).optional(), // Only digits, spaces, and phone chars
  company: z.string().max(100).regex(/^[a-zA-Z0-9\s\-&.,]+$/).optional(), // Alphanumeric + common business chars
  jobTitle: z.string().max(100).regex(/^[a-zA-Z0-9\s\-&.,/]+$/).optional(),
  notes: z.string().max(500).optional(), // Will be further sanitized
  folder: z.string().max(50).regex(/^[a-zA-Z0-9\s\-_]+$/).optional(),
  createdAt: z.string().datetime().optional(),
  updatedAt: z.string().datetime().optional()
});

export const ImportDataSchema = z.object({
  contacts: z.array(ContactSchema).min(1).max(1000), // Limit to prevent DoS
  mapping: z.record(z.string().max(50), z.string().max(50)).optional(),
  sourceType: z.enum(['csv', 'vcard', 'google-csv', 'outlook-csv']),
  fileName: z.string().max(255).regex(/^[a-zA-Z0-9\-_. ]+$/), // Safe filename chars only
  metadata: z.object({
    totalRows: z.number().min(0).max(1000),
    validRows: z.number().min(0),
    errorRows: z.number().min(0),
    duplicates: z.number().min(0)
  }).optional()
});

export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().min(1).max(100),
  role: z.enum(['admin', 'user', 'readonly']),
  permissions: z.array(z.string()).optional(),
  lastLogin: z.string().datetime().optional()
});

export const AuthStateSchema = z.object({
  user: UserSchema.nullable(),
  isAuthenticated: z.boolean(),
  loading: z.boolean(),
  error: z.string().nullable(),
  token: z.string().optional(),
  expiresAt: z.number().optional()
});

export const ApiResponseSchema = z.object({
  success: z.boolean(),
  data: z.unknown().optional(),
  error: z.string().optional(),
  timestamp: z.string().datetime(),
  requestId: z.string().uuid().optional()
});

export const OperationLogSchema = z.object({
  id: z.string().uuid(),
  operation: z.enum(['import', 'backup', 'restore', 'merge', 'delete']),
  user: z.string().email(),
  status: z.enum(['pending', 'success', 'error', 'warning']),
  details: z.string().max(500),
  timestamp: z.string().datetime(),
  duration: z.number().min(0).optional(),
  affectedContacts: z.number().min(0).optional()
});

// Type exports
export type Contact = z.infer<typeof ContactSchema>;
export type ImportData = z.infer<typeof ImportDataSchema>;
export type User = z.infer<typeof UserSchema>;
export type AuthState = z.infer<typeof AuthStateSchema>;
export type ApiResponse<T = unknown> = z.infer<typeof ApiResponseSchema> & { data?: T };
export type OperationLog = z.infer<typeof OperationLogSchema>;

// Additional utility types
export type ImportStep = 'upload' | 'mapping' | 'preview' | 'confirm' | 'complete';
export type ImportSource = 'csv' | 'vcard' | 'google-csv' | 'outlook-csv';
export type UserRole = 'admin' | 'user' | 'readonly';
export type OperationType = 'import' | 'backup' | 'restore' | 'merge' | 'delete';
export type OperationStatus = 'pending' | 'success' | 'error' | 'warning';
