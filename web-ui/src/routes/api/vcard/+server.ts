import { json, type RequestHandler } from '@sveltejs/kit';
import { spawn } from 'child_process';
import { writeFile, unlink } from 'fs/promises';
import path from 'path';
import { randomUUID } from 'crypto';

// API endpoint for vCard validation and import
export const POST: RequestHandler = async ({ request }) => {
	try {
		const formData = await request.formData();
		const file = formData.get('file') as File;
		const userEmail = formData.get('userEmail') as string;
		const contactFolder = formData.get('contactFolder') as string;
		const duplicateAction = formData.get('duplicateAction') as string;
		const validateOnly = formData.get('validateOnly') === 'true';
		const enhancedParsing = formData.get('enhancedParsing') === 'true';

		if (!file) {
			return json({ error: 'No file provided' }, { status: 400 });
		}

		// Validate file type
		if (!file.name.toLowerCase().endsWith('.vcf') && !file.name.toLowerCase().endsWith('.vcard')) {
			return json({ error: 'Invalid file type. Only .vcf and .vcard files are supported.' }, { status: 400 });
		}

		// Create temporary file
		const tempId = randomUUID();
		const tempFileName = `temp_vcard_${tempId}.vcf`;
		const tempFilePath = path.join('/tmp', tempFileName);

		// Save uploaded file to temp location
		const fileBuffer = await file.arrayBuffer();
		await writeFile(tempFilePath, Buffer.from(fileBuffer));

		// Build PowerShell command
		const scriptPath = path.resolve('../../scripts/Import-VCardContacts.ps1');
		const powershellArgs = [
			'-File', scriptPath,
			'-VCardPath', tempFilePath,
			'-UserEmail', userEmail || 'default@example.com',
			'-DuplicateHandling', duplicateAction || 'Merge'
		];

		if (contactFolder) {
			powershellArgs.push('-ContactFolder', contactFolder);
		}

		if (validateOnly) {
			powershellArgs.push('-ValidateOnly');
		}

		if (enhancedParsing) {
			powershellArgs.push('-EnhancedParsing');
		}

		// Execute PowerShell script
		const result = await executePowerShell(powershellArgs);

		// Clean up temp file
		try {
			await unlink(tempFilePath);
		} catch (error) {
			console.warn('Failed to clean up temp file:', error);
		}

		// Parse PowerShell output
		const response = parseVCardResult(result);
		return json(response);

	} catch (error) {
		console.error('vCard API error:', error);
		return json({ 
			error: 'Internal server error', 
			details: error instanceof Error ? error.message : String(error) 
		}, { status: 500 });
	}
};

// Execute PowerShell script and return result
function executePowerShell(args: string[]): Promise<string> {
	return new Promise((resolve, reject) => {
		const powershell = spawn('pwsh', args, {
			stdio: ['pipe', 'pipe', 'pipe']
		});

		let stdout = '';
		let stderr = '';

		powershell.stdout.on('data', (data) => {
			stdout += data.toString();
		});

		powershell.stderr.on('data', (data) => {
			stderr += data.toString();
		});

		powershell.on('close', (code) => {
			if (code !== 0) {
				reject(new Error(`PowerShell exited with code ${code}: ${stderr}`));
			} else {
				resolve(stdout);
			}
		});

		powershell.on('error', (error) => {
			reject(error);
		});
	});
}

// Parse PowerShell output into structured response
function parseVCardResult(output: string) {
	try {
		// Try to parse as JSON first (if PowerShell returns JSON)
		const jsonMatch = output.match(/\{[\s\S]*\}/);
		if (jsonMatch) {
			return JSON.parse(jsonMatch[0]);
		}

		// Fallback: parse text output
		const lines = output.split('\n').map(line => line.trim()).filter(line => line);
		
		// Extract key information from PowerShell output
		const result = {
			isValid: true,
			vCardVersion: '3.0',
			contactCount: 0,
			statistics: {
				emailsFound: 0,
				phonesFound: 0,
				addressesFound: 0,
				companiesFound: 0,
				duplicateEmails: 0
			},
			warnings: [] as string[],
			importedContacts: 0,
			skippedContacts: 0,
			errorContacts: 0
		};

		// Parse statistics from output
		for (const line of lines) {
			if (line.includes('Total contacts:')) {
				result.contactCount = parseInt(line.match(/\d+/)?.[0] || '0');
			}
			if (line.includes('Emails found:')) {
				result.statistics.emailsFound = parseInt(line.match(/\d+/)?.[0] || '0');
			}
			if (line.includes('Phones found:')) {
				result.statistics.phonesFound = parseInt(line.match(/\d+/)?.[0] || '0');
			}
			if (line.includes('Companies found:')) {
				result.statistics.companiesFound = parseInt(line.match(/\d+/)?.[0] || '0');
			}
			if (line.includes('Successfully imported:')) {
				result.importedContacts = parseInt(line.match(/\d+/)?.[0] || '0');
			}
			if (line.includes('Skipped:')) {
				result.skippedContacts = parseInt(line.match(/\d+/)?.[0] || '0');
			}
			if (line.includes('Errors:')) {
				result.errorContacts = parseInt(line.match(/\d+/)?.[0] || '0');
			}
			if (line.includes('WARNING:') || line.includes('Warning:')) {
				result.warnings.push(line);
			}
		}

		return result;

	} catch (error) {
		console.error('Failed to parse PowerShell output:', error);
		return {
			error: 'Failed to parse PowerShell output',
			rawOutput: output
		};
	}
}
