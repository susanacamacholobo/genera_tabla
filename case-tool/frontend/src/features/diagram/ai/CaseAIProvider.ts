import type { LocalLLMProvider } from '../../../domain';

export interface CaseAIStatus {
  configured: boolean;
  remote: boolean;
}

export class CaseAIProvider implements LocalLLMProvider {
  async generate(prompt: string): Promise<string> {
    const response = await fetch('/ai/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt }),
    });
    if (!response.ok) throw new Error('El proveedor de IA no está disponible.');
    const data: unknown = await response.json();
    if (typeof data !== 'object' || data === null || !('response' in data)
      || typeof data.response !== 'string') {
      throw new Error('La IA no devolvió texto válido.');
    }
    return data.response;
  }
}

export async function getCaseAIStatus(): Promise<CaseAIStatus> {
  const response = await fetch('/ai/status');
  if (!response.ok) return { configured: false, remote: false };
  const data: unknown = await response.json();
  if (typeof data !== 'object' || data === null || !('configured' in data)
    || !('remote' in data) || typeof data.configured !== 'boolean'
    || typeof data.remote !== 'boolean') return { configured: false, remote: false };
  return { configured: data.configured, remote: data.remote };
}
