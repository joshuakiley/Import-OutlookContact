import { json, type RequestHandler } from '@sveltejs/kit';
import { spawn } from 'child_process';

// API endpoint for system status
export const GET: RequestHandler = async () => {
	try {
		// Check PowerShell availability
		const powershellVersion = await checkPowerShell();
		
		// Check if Graph module is available
		const graphModuleStatus = await checkGraphModule();
		
		// Check authentication status
		const authStatus = await checkAuthentication();

		const status = {
			webInterface: 'Online',
			powershell: powershellVersion ? 'Available' : 'Not Available',
			powershellVersion: powershellVersion || 'Unknown',
			graphModule: graphModuleStatus ? 'Installed' : 'Not Available',
			authentication: authStatus ? 'Ready' : 'Required',
			backend: 'Connected',
			database: 'Available',
			lastChecked: new Date().toISOString()
		};

		return json(status);

	} catch (error) {
		console.error('Status check error:', error);
		return json({
			webInterface: 'Online',
			powershell: 'Error',
			graphModule: 'Unknown',
			authentication: 'Unknown',
			backend: 'Error',
			database: 'Unknown',
			error: error instanceof Error ? error.message : String(error),
			lastChecked: new Date().toISOString()
		}, { status: 500 });
	}
};

// Check PowerShell availability and version
async function checkPowerShell(): Promise<string | null> {
	try {
		const result = await executePowerShellCommand(['$PSVersionTable.PSVersion.ToString()']);
		return result.trim();
	} catch {
		return null;
	}
}

// Check if Microsoft Graph module is installed
async function checkGraphModule(): Promise<boolean> {
	try {
		const result = await executePowerShellCommand([
			'Get-Module -ListAvailable Microsoft.Graph.Users | Select-Object -First 1 | ForEach-Object { $_.Version.ToString() }'
		]);
		return result.trim().length > 0;
	} catch {
		return false;
	}
}

// Check authentication status
async function checkAuthentication(): Promise<boolean> {
	try {
		const result = await executePowerShellCommand([
			'Get-MgContext | Select-Object -ExpandProperty Account'
		]);
		return result.trim().length > 0;
	} catch {
		return false;
	}
}

// Execute PowerShell command
function executePowerShellCommand(commands: string[]): Promise<string> {
	return new Promise((resolve, reject) => {
		const args = ['-Command', ...commands];
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
