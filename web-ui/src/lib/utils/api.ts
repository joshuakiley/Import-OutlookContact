// API utility functions for the web UI

export interface SystemStatus {
	webInterface: string;
	powershell: string;
	powershellVersion?: string;
	graphModule: string;
	authentication: string;
	backend: string;
	database: string;
	lastChecked: string;
	error?: string;
}

export interface AuthInfo {
	isAuthenticated: boolean;
	account?: string;
	tenantId?: string;
	environment?: string;
	scopes?: string;
	authType?: string;
	error?: string;
}

export interface VCardImportRequest {
	file: File;
	userEmail?: string;
	contactFolder?: string;
	duplicateAction?: 'Skip' | 'Merge' | 'Overwrite' | 'Consolidate';
	validateOnly?: boolean;
	enhancedParsing?: boolean;
}

export interface ContactFolder {
	Id: string;
	DisplayName: string;
	IsDefault: boolean;
}

export interface FoldersResponse {
	success: boolean;
	folders: ContactFolder[];
	totalCount: number;
	error?: string;
}

export interface CreateFolderRequest {
	userEmail: string;
	folderName: string;
}

export interface CreateFolderResponse {
	success: boolean;
	folder?: ContactFolder;
	error?: string;
}

export interface VCardImportResponse {
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

// Fetch system status
export async function getSystemStatus(): Promise<SystemStatus> {
	try {
		const response = await fetch('/api/status');
		if (!response.ok) {
			throw new Error(`HTTP ${response.status}: ${response.statusText}`);
		}
		return await response.json();
	} catch (error) {
		console.error('Failed to fetch system status:', error);
		throw error;
	}
}

// Fetch authentication status
export async function getAuthStatus(): Promise<AuthInfo> {
	try {
		const response = await fetch('/api/auth');
		if (!response.ok) {
			throw new Error(`HTTP ${response.status}: ${response.statusText}`);
		}
		return await response.json();
	} catch (error) {
		console.error('Failed to fetch auth status:', error);
		throw error;
	}
}

// Initiate authentication
export async function connectToGraph(scopes?: string[], tenantId?: string): Promise<any> {
	try {
		const response = await fetch('/api/auth', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({
				action: 'connect',
				scopes,
				tenantId
			})
		});

		if (!response.ok) {
			throw new Error(`HTTP ${response.status}: ${response.statusText}`);
		}
		return await response.json();
	} catch (error) {
		console.error('Failed to connect to Graph:', error);
		throw error;
	}
}

// Disconnect authentication
export async function disconnectFromGraph(): Promise<any> {
	try {
		const response = await fetch('/api/auth', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({
				action: 'disconnect'
			})
		});

		if (!response.ok) {
			throw new Error(`HTTP ${response.status}: ${response.statusText}`);
		}
		return await response.json();
	} catch (error) {
		console.error('Failed to disconnect from Graph:', error);
		throw error;
	}
}

// Import vCard file
export async function importVCard(request: VCardImportRequest): Promise<VCardImportResponse> {
	try {
		const formData = new FormData();
		formData.append('file', request.file);
		
		if (request.userEmail) formData.append('userEmail', request.userEmail);
		if (request.contactFolder) formData.append('contactFolder', request.contactFolder);
		if (request.duplicateAction) formData.append('duplicateAction', request.duplicateAction);
		formData.append('validateOnly', String(request.validateOnly ?? true));
		formData.append('enhancedParsing', String(request.enhancedParsing ?? true));

		const response = await fetch('/api/vcard', {
			method: 'POST',
			body: formData
		});

		if (!response.ok) {
			const errorData = await response.json().catch(() => ({ error: 'Unknown error' }));
			throw new Error(errorData.error || `HTTP ${response.status}: ${response.statusText}`);
		}

		return await response.json();
	} catch (error) {
		console.error('Failed to import vCard:', error);
		throw error;
	}
}

// Utility function to format file size
export function formatFileSize(bytes: number): string {
	if (bytes === 0) return '0 Bytes';
	const k = 1024;
	const sizes = ['Bytes', 'KB', 'MB', 'GB'];
	const i = Math.floor(Math.log(bytes) / Math.log(k));
	return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Utility function to format date
export function formatDate(dateString: string): string {
	try {
		const date = new Date(dateString);
		return date.toLocaleString();
	} catch {
		return 'Unknown';
	}
}

// Folder management functions
export async function getUserFolders(userEmail: string): Promise<FoldersResponse> {
	try {
		const response = await fetch(`/api/folders?userEmail=${encodeURIComponent(userEmail)}`);
		
		if (!response.ok) {
			const errorData = await response.json().catch(() => ({ error: 'Unknown error' }));
			throw new Error(errorData.error || `HTTP ${response.status}: ${response.statusText}`);
		}

		return await response.json();
	} catch (error) {
		console.error('Failed to get user folders:', error);
		throw error;
	}
}

export async function createContactFolder(request: CreateFolderRequest): Promise<CreateFolderResponse> {
	try {
		const response = await fetch('/api/folders', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify(request)
		});
		
		if (!response.ok) {
			const errorData = await response.json().catch(() => ({ error: 'Unknown error' }));
			throw new Error(errorData.error || `HTTP ${response.status}: ${response.statusText}`);
		}

		return await response.json();
	} catch (error) {
		console.error('Failed to create contact folder:', error);
		throw error;
	}
}
