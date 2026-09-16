export interface SpeechProvider {
  isSupported(): boolean;
  listen(): Promise<string>;
  cancel(): void;
}

interface RecognitionResultEvent {
  results: ArrayLike<ArrayLike<{ transcript: string }>>;
}

interface RecognitionErrorEvent {
  error: string;
}

interface RecognitionSession {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  maxAlternatives: number;
  onresult: ((event: RecognitionResultEvent) => void) | null;
  onerror: ((event: RecognitionErrorEvent) => void) | null;
  onend: (() => void) | null;
  start(): void;
  abort(): void;
}

type RecognitionConstructor = new () => RecognitionSession;

function constructorForBrowser(): RecognitionConstructor | undefined {
  if (typeof window === 'undefined') return undefined;
  const speechWindow = window as Window & {
    SpeechRecognition?: RecognitionConstructor;
    webkitSpeechRecognition?: RecognitionConstructor;
  };
  return speechWindow.SpeechRecognition ?? speechWindow.webkitSpeechRecognition;
}

export class BrowserSpeechProvider implements SpeechProvider {
  private current: RecognitionSession | null = null;

  isSupported(): boolean {
    return constructorForBrowser() !== undefined;
  }

  listen(): Promise<string> {
    const Recognition = constructorForBrowser();
    if (!Recognition) return Promise.reject(new Error('Tu navegador no admite dictado. Escribe el comando.'));
    if (this.current) return Promise.reject(new Error('El micrófono ya está escuchando.'));

    return new Promise<string>((resolve, reject) => {
      const session = new Recognition();
      this.current = session;
      let settled = false;
      const finish = (transcript?: string, error?: string) => {
        if (settled) return;
        settled = true;
        this.current = null;
        if (transcript) resolve(transcript);
        else reject(new Error(error ?? 'No se reconoció una instrucción.'));
      };

      session.lang = 'es-BO';
      session.continuous = false;
      session.interimResults = false;
      session.maxAlternatives = 1;
      session.onresult = (event) => finish(event.results[0]?.[0]?.transcript.trim());
      session.onerror = (event) => finish(undefined, event.error === 'not-allowed'
        ? 'Permite el acceso al micrófono para dictar comandos.'
        : 'No se pudo reconocer la voz. Intenta escribir el comando.');
      session.onend = () => finish();
      try {
        session.start();
      } catch {
        finish(undefined, 'No se pudo activar el micrófono.');
      }
    });
  }

  cancel(): void {
    this.current?.abort();
  }
}
