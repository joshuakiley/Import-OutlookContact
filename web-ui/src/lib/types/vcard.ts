// vCard specific types for the web interface

export interface ContactFolder {
  Id: string;
  DisplayName: string;
  IsDefault: boolean;
}

export interface VCardContact {
  displayName: string;
  givenName?: string;
  surname?: string;
  middleName?: string;
  namePrefix?: string;
  nameSuffix?: string;
  companyName?: string;
  jobTitle?: string;
  department?: string;
  emailAddresses?: Array<{
    address: string;
    type?: string;
    isPrimary?: boolean;
  }>;
  businessPhones?: string[];
  homePhones?: string[];
  mobilePhone?: string;
  faxNumbers?: string[];
  businessAddress?: {
    street?: string;
    city?: string;
    state?: string;
    postalCode?: string;
    country?: string;
  };
  homeAddress?: {
    street?: string;
    city?: string;
    state?: string;
    postalCode?: string;
    country?: string;
  };
  personalNotes?: string;
  birthday?: string;
  anniversary?: string;
  websiteUrls?: string[];
  categories?: string[];
  source?: string;
  vCardVersion?: string;
  customFields?: Record<string, any>;
}

export interface VCardImportRequest {
  file: File;
  userEmail: string;
  contactFolder?: string;
  duplicateAction: 'Skip' | 'Merge' | 'Overwrite' | 'Consolidate';
  validateOnly: boolean;
  enhancedParsing: boolean;
}

export interface VCardImportResponse {
  success: boolean;
  message: string;
  totalContacts: number;
  validContacts: number;
  invalidContacts: number;
  duplicatesFound: number;
  contactsProcessed: number;
  validationErrors?: string[];
  duplicateEmails?: string[];
  parsedContacts?: VCardContact[];
}

export interface VCardApiResponse {
  isValid: boolean;
  vCardVersion?: string;
  contactCount: number;
  statistics: {
    emailsFound: number;
    phonesFound: number;
    addressesFound: number;
    companiesFound: number;
    duplicateEmails: number;
  };
  warnings: string[];
  importedContacts?: number;
  skippedContacts?: number;
  errorContacts?: number;
  error?: string;
  rawOutput?: string;
}

export interface VCardValidationResult {
  isValid: boolean;
  vCardVersion?: string;
  contactCount: number;
  errors?: Array<{
    line?: number;
    field?: string;
    message: string;
    severity: 'error' | 'warning' | 'info';
  }>;
  warnings?: string[];
  statistics?: {
    emailsFound: number;
    phonesFound: number;
    addressesFound: number;
    companiesFound: number;
    duplicateEmails: number;
  };
}
