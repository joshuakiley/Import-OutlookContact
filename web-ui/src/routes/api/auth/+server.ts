import { json, type RequestHandler } from '@sveltejs/kit';
import { spawn } from 'child_process';

// GET: Check authentication status
export const GET: RequestHandler = async () => {
	try {
		const authInfo = await checkAuthenticationDetails();
		return json(authInfo);
	} catch (error) {
		console.error('Auth status error:', error);
		return json({
			isAuthenticated: false,
			error: error instanceof Error ? error.message : String(error)
		}, { status: 500 });
	}
};

// POST: Initiate authentication
export const POST: RequestHandler = async ({ request }) => {
	try {
		const { action, scopes, tenantId } = await request.json();

		if (action === 'connect') {
			const result = await initiateAuthentication(scopes, tenantId);
			return json(result);
		}

		if (action === 'disconnect') {
			const result = await disconnectAuthentication();
			return json(result);
		}

		return json({ error: 'Invalid action' }, { status: 400 });

	} catch (error) {
		console.error('Auth action error:', error);
		return json({
			success: false,
			error: error instanceof Error ? error.message : String(error)
		}, { status: 500 });
	}
};

// Check detailed authentication information
async function checkAuthenticationDetails() {
	try {
		const commands = [
			'$context = Get-MgContext',
			'if ($context) {',
			'  @{',
			'    IsAuthenticated = $true',
			'    Account = $context.Account',
			'    TenantId = $context.TenantId',
			'    Environment = $context.Environment',
			'    Scopes = $context.Scopes -join ", "',
			'    AuthType = $context.AuthType',
			'  } | ConvertTo-Json',
			'} else {',
			'  @{ IsAuthenticated = $false } | ConvertTo-Json',
			'}'
		];

		const result = await executePowerShellCommand(commands);
		return JSON.parse(result.trim());

	} catch (error) {
		return {
			isAuthenticated: false,
			error: error instanceof Error ? error.message : String(error)
		};
	}
}

// Initiate Microsoft Graph authentication
async function initiateAuthentication(scopes?: string[], tenantId?: string) {
	try {
		const scopeList = scopes || [
			'User.Read',
			'Contacts.ReadWrite',
			'Directory.Read.All'
		];

		const commands = [
			'Import-Module Microsoft.Graph.Authentication -Force',
			`Connect-MgGraph -Scopes "${scopeList.join('", "')}"${tenantId ? ` -TenantId "${tenantId}"` : ''}`,
			'$context = Get-MgContext',
			'@{',
			'  Success = $true',
			'  Account = $context.Account',
			'  TenantId = $context.TenantId',
			'  Scopes = $context.Scopes -join ", "',
			'} | ConvertTo-Json'
		];

		const result = await executePowerShellCommand(commands);
		return JSON.parse(result.trim());

	} catch (error) {
		return {
			success: false,
			error: error instanceof Error ? error.message : String(error)
		};
	}
}

// Disconnect Microsoft Graph authentication
async function disconnectAuthentication() {
	try {
		const commands = [
			'Disconnect-MgGraph',
			'@{ Success = $true; Message = "Successfully disconnected" } | ConvertTo-Json'
		];

		const result = await executePowerShellCommand(commands);
		return JSON.parse(result.trim());

	} catch (error) {
		return {
			success: false,
			error: error instanceof Error ? error.message : String(error)
		};
	}
}

// Execute PowerShell command
function executePowerShellCommand(commands: string[]): Promise<string> {
	return new Promise((resolve, reject) => {
		const script = commands.join('\n');
		const args = ['-Command', script];
		
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
