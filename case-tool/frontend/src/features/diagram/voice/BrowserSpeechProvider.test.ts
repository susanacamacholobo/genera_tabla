// @vitest-environment jsdom

import { afterEach, describe, expect, it, vi } from 'vitest';
import { BrowserSpeechProvider } from './BrowserSpeechProvider';

type FakeSession = {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  maxAlternatives: number;
  onresult: ((event: { results: ArrayLike<ArrayLike<{ transcript: string }>> }) => void) | null;
  onerror: ((event: { error: string }) => void) | null;
  onend: (() => void) | null;
  start: ReturnType<typeof vi.fn>;
  abort: ReturnType<typeof vi.fn>;
};

const speechWindow = window as Window & { webkitSpeechRecognition?: new () => FakeSession };

afterEach(() => { delete speechWindow.webkitSpeechRecognition; });

describe('BrowserSpeechProvider', () => {
  it('reports unsupported browsers without attempting audio capture', async () => {
    const provider = new BrowserSpeechProvider();
    expect(provider.isSupported()).toBe(false);
    await expect(provider.listen()).rejects.toThrow('no admite dictado');
  });

  it('returns one Spanish transcript and never executes a command', async () => {
    let session: FakeSession | undefined;
    speechWindow.webkitSpeechRecognition = class {
      lang = '';
      continuous = true;
      interimResults = true;
      maxAlternatives = 0;
      onresult = null;
      onerror = null;
      onend = null;
      start = vi.fn();
      abort = vi.fn();
      constructor() { session = this as FakeSession; }
    } as new () => FakeSession;
    const provider = new BrowserSpeechProvider();

    const transcript = provider.listen();
    expect(session?.lang).toBe('es-BO');
    expect(session?.continuous).toBe(false);
    expect(session?.start).toHaveBeenCalledOnce();
    session?.onresult?.({ results: [[{ transcript: ' crea clase Factura ' }]] });

    await expect(transcript).resolves.toBe('crea clase Factura');
    provider.cancel();
    expect(session?.abort).not.toHaveBeenCalled();
  });

  it('maps denied microphone access to a safe message', async () => {
    let session: FakeSession | undefined;
    speechWindow.webkitSpeechRecognition = class {
      lang = '';
      continuous = false;
      interimResults = false;
      maxAlternatives = 1;
      onresult = null;
      onerror = null;
      onend = null;
      start = vi.fn();
      abort = vi.fn();
      constructor() { session = this as FakeSession; }
    } as new () => FakeSession;
    const provider = new BrowserSpeechProvider();
    const result = provider.listen();
    session?.onerror?.({ error: 'not-allowed' });
    await expect(result).rejects.toThrow('Permite el acceso al micrófono');
  });
});
