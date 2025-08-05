import DOMPurify from 'dompurify';
import { ContactSchema, type Contact } from '$types';

/**
 * Sanitizes user input to prevent XSS attacks
 * @param input - The input string to sanitize
 * @returns Sanitized string safe for display
 */
export function sanitizeInput(input: string): string {
  if (!input || typeof input !== 'string') return '';
  
  // Use DOMPurify to remove any malicious HTML/JS
  const sanitized = DOMPurify.sanitize(input, { 
    ALLOWED_TAGS: [], // No HTML tags allowed
    ALLOWED_ATTR: [],
    KEEP_CONTENT: true
  });
  
  // Additional CSV injection prevention
  if (sanitized.match(/^[=@+\-]/)) {
    return `'${sanitized}`; // Prefix with single quote to neutralize
  }
  
  return sanitized.trim();
}

/**
 * Sanitizes contact data before processing or display
 * @param contact - Raw contact data
 * @returns Sanitized contact object
 */
export function sanitizeContactData(contact: Record<string, unknown>): Contact {
  const sanitized = {
    firstName: sanitizeInput(String(contact.firstName || '')),
    lastName: sanitizeInput(String(contact.lastName || '')),
    email: sanitizeEmail(String(contact.email || '')),
    phone: sanitizePhone(String(contact.phone || '')),
    company: sanitizeInput(String(contact.company || '')),
    jobTitle: sanitizeInput(String(contact.jobTitle || '')),
    notes: sanitizeInput(String(contact.notes || '')),
    folder: sanitizeInput(String(contact.folder || ''))
  };
  
  // Validate against schema
  const result = ContactSchema.safeParse(sanitized);
  
  if (!result.success) {
    throw new Error(`Invalid contact data: ${result.error.message}`);
  }
  
  return result.data;
}

/**
 * Sanitizes email addresses
 * @param email - Raw email string
 * @returns Sanitized email or empty string if invalid
 */
export function sanitizeEmail(email: string): string {
  if (!email || typeof email !== 'string') return '';
  
  const sanitized = sanitizeInput(email.toLowerCase());
  
  // Basic email validation
  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  
  return emailRegex.test(sanitized) ? sanitized : '';
}

/**
 * Sanitizes phone numbers
 * @param phone - Raw phone string
 * @returns Sanitized phone number
 */
export function sanitizePhone(phone: string): string {
  if (!phone || typeof phone !== 'string') return '';
  
  // Remove any non-phone characters except digits, spaces, hyphens, plus, parentheses
  const cleaned = phone.replace(/[^\d\s\-\+\(\)]/g, '');
  
  return sanitizeInput(cleaned);
}

/**
 * Prevents CSV injection attacks
 * @param value - Input value to check
 * @returns Safe value for CSV export
 */
export function preventCSVInjection(value: string): string {
  if (!value || typeof value !== 'string') return '';
  
  // Check for dangerous starting characters
  if (value.match(/^[=@+\-]/)) {
    return `'${value}`; // Prefix with single quote
  }
  
  return value;
}

/**
 * Validates file upload security
 * @param file - File object to validate
 * @returns True if file is safe to process
 */
export function validateFileUpload(file: File): boolean {
  // Check file size (max 10MB)
  const maxSize = 10 * 1024 * 1024;
  if (file.size > maxSize) {
    return false;
  }
  
  // Check allowed file types
  const allowedTypes = [
    'text/csv',
    'application/csv',
    'text/vcard',
    'text/x-vcard',
    'text/plain'
  ];
  
  if (!allowedTypes.includes(file.type)) {
    return false;
  }
  
  // Check file extension
  const allowedExtensions = ['.csv', '.vcf', '.txt'];
  const fileExt = file.name.toLowerCase().substring(file.name.lastIndexOf('.'));
  
  if (!allowedExtensions.includes(fileExt)) {
    return false;
  }
  
  // Additional filename validation
  const safeNameRegex = /^[a-zA-Z0-9\-_. ]+$/;
  if (!safeNameRegex.test(file.name)) {
    return false;
  }
  
  return true;
}

/**
 * Sanitizes error messages before displaying to user
 * @param error - Error object or message
 * @returns Safe error message
 */
export function sanitizeError(error: unknown): string {
  if (!error) return 'An unknown error occurred';
  
  let message: string;
  
  if (error instanceof Error) {
    message = error.message;
  } else if (typeof error === 'string') {
    message = error;
  } else {
    message = 'An unexpected error occurred';
  }
  
  // Remove any potentially sensitive information
  const sanitized = sanitizeInput(message);
  
  // Remove file paths, stack traces, and other sensitive data
  return sanitized
    .replace(/\/[^\s]+/g, '[path]') // Remove file paths
    .replace(/at\s+[^\n]+/g, '') // Remove stack trace lines
    .replace(/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/g, '[ip]') // Remove IP addresses
    .trim();
}

/**
 * Validates and sanitizes import mapping configuration
 * @param mapping - Field mapping object
 * @returns Sanitized mapping
 */
export function sanitizeMapping(mapping: Record<string, string>): Record<string, string> {
  const sanitized: Record<string, string> = {};
  
  const allowedFields = [
    'firstName', 'lastName', 'email', 'phone', 'company', 
    'jobTitle', 'notes', 'folder'
  ];
  
  for (const [key, value] of Object.entries(mapping)) {
    const sanitizedKey = sanitizeInput(key);
    const sanitizedValue = sanitizeInput(value);
    
    // Only allow known field mappings
    if (allowedFields.includes(sanitizedValue) && sanitizedKey.length > 0) {
      sanitized[sanitizedKey] = sanitizedValue;
    }
  }
  
  return sanitized;
}
