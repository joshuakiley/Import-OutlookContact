import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { spawn } from 'child_process';

export const GET: RequestHandler = async ({ url }) => {
  try {
    const userEmail = url.searchParams.get('userEmail');
    
    if (!userEmail) {
      return json(
        { 
          success: false, 
          error: 'User email is required' 
        },
        { status: 400 }
      );
    }

    // Call PowerShell script to get user's contact folders
    const ps = spawn('pwsh', [
      '-ExecutionPolicy', 'Bypass',
      '-Command', `
        try {
          Import-Module "${process.cwd()}/../modules/ContactOperations.psm1" -Force
          Import-Module "${process.cwd()}/../modules/Authentication.psm1" -Force
          
          # Initialize authentication
          Initialize-GraphAuthenticationAuto
          
          # Get user's contact folders
          $folders = Get-UserContactFolders -UserEmail "${userEmail}"
          
          # Format for API response
          $folderList = @()
          
          # Add default "Contacts" folder first
          $folderList += @{
            Id = "default"
            DisplayName = "Contacts"
            IsDefault = $true
          }
          
          # Add other folders
          foreach ($folder in $folders) {
            if ($folder.DisplayName -ne "Contacts") {
              $folderList += @{
                Id = $folder.Id
                DisplayName = $folder.DisplayName
                IsDefault = $false
              }
            }
          }
          
          # Return JSON
          $result = @{
            success = $true
            folders = $folderList
            totalCount = $folderList.Count
          }
          
          $result | ConvertTo-Json -Depth 3
        }
        catch {
          @{
            success = $false
            error = $_.Exception.Message
          } | ConvertTo-Json
        }
      `
    ]);

    let stdout = '';
    let stderr = '';

    ps.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    ps.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    await new Promise((resolve, reject) => {
      ps.on('close', (code) => {
        if (code === 0) {
          resolve(code);
        } else {
          reject(new Error(`PowerShell process exited with code ${code}: ${stderr}`));
        }
      });
    });

    // Parse PowerShell output
    const cleanOutput = stdout.trim();
    if (!cleanOutput) {
      throw new Error('No output received from PowerShell script');
    }

    let psResult;
    try {
      psResult = JSON.parse(cleanOutput);
    } catch (parseError) {
      console.error('Failed to parse PowerShell output:', cleanOutput);
      throw new Error(`Invalid JSON response from PowerShell: ${parseError}`);
    }

    if (!psResult.success) {
      throw new Error(psResult.error || 'Unknown error from PowerShell script');
    }

    return json({
      success: true,
      folders: psResult.folders || [],
      totalCount: psResult.totalCount || 0
    });

  } catch (error) {
    console.error('Folders API error:', error);
    return json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to retrieve folders'
      },
      { status: 500 }
    );
  }
};

export const POST: RequestHandler = async ({ request }) => {
  try {
    const { userEmail, folderName } = await request.json();
    
    if (!userEmail || !folderName) {
      return json(
        { 
          success: false, 
          error: 'User email and folder name are required' 
        },
        { status: 400 }
      );
    }

    // Call PowerShell script to create a new contact folder
    const ps = spawn('pwsh', [
      '-ExecutionPolicy', 'Bypass',
      '-Command', `
        try {
          Import-Module "${process.cwd()}/../modules/ContactOperations.psm1" -Force
          Import-Module "${process.cwd()}/../modules/Authentication.psm1" -Force
          
          # Initialize authentication
          Initialize-GraphAuthenticationAuto
          
          # Create new contact folder
          $uri = "https://graph.microsoft.com/v1.0/users/${userEmail}/contactFolders"
          $body = @{
            displayName = "${folderName}"
          } | ConvertTo-Json
          
          $newFolder = Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body -ContentType "application/json"
          
          # Return success result
          @{
            success = $true
            folder = @{
              Id = $newFolder.Id
              DisplayName = $newFolder.DisplayName
              IsDefault = $false
            }
          } | ConvertTo-Json -Depth 2
        }
        catch {
          @{
            success = $false
            error = $_.Exception.Message
          } | ConvertTo-Json
        }
      `
    ]);

    let stdout = '';
    let stderr = '';

    ps.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    ps.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    await new Promise((resolve, reject) => {
      ps.on('close', (code) => {
        if (code === 0) {
          resolve(code);
        } else {
          reject(new Error(`PowerShell process exited with code ${code}: ${stderr}`));
        }
      });
    });

    // Parse PowerShell output
    const cleanOutput = stdout.trim();
    if (!cleanOutput) {
      throw new Error('No output received from PowerShell script');
    }

    let psResult;
    try {
      psResult = JSON.parse(cleanOutput);
    } catch (parseError) {
      console.error('Failed to parse PowerShell output:', cleanOutput);
      throw new Error(`Invalid JSON response from PowerShell: ${parseError}`);
    }

    if (!psResult.success) {
      throw new Error(psResult.error || 'Unknown error from PowerShell script');
    }

    return json({
      success: true,
      folder: psResult.folder
    });

  } catch (error) {
    console.error('Create folder API error:', error);
    return json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to create folder'
      },
      { status: 500 }
    );
  }
};
