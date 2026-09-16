import { useEffect, useMemo, useState, type FormEvent } from 'react';
import {
  CommandExecutor,
  CommandValidationError,
  LocalLLMCommandParser,
  RuleBasedCommandParser,
  type Command,
  type LocalLLMProvider,
  type NaturalLanguageCommandParser,
  type ProjectModel,
} from '../../../domain';
import { BrowserSpeechProvider, type SpeechProvider } from '../voice/BrowserSpeechProvider';

export interface TextCommandBarProps {
  project: ProjectModel;
  onExecute: (command: Command) => boolean;
  parser?: NaturalLanguageCommandParser;
  speechProvider?: SpeechProvider;
  aiProvider?: LocalLLMProvider;
  aiRemote?: boolean;
}

interface Feedback {
  kind: 'error' | 'success';
  message: string;
}

interface Proposal {
  command: Command;
  description: string;
  baseRevision: number;
  explanation?: string;
  assumptions?: string[];
}

function describe(command: Command, project: ProjectModel): string {
  switch (command.type) {
    case 'ADD_CLASS': return `Crear la clase «${command.payload.name}».`;
    case 'RENAME_CLASS': return `Renombrar «${project.classes.find((item) => item.id === command.targetId)?.name ?? 'clase'}» a «${command.payload.name}».`;
    case 'DELETE_CLASS': {
      const target = project.classes.find((item) => item.id === command.targetId);
      const related = project.relationships.filter((item) => item.sourceClassId === command.targetId || item.targetClassId === command.targetId).length;
      return `Eliminar «${target?.name ?? 'clase'}», sus ${target?.attributes.length ?? 0} atributos y ${related} relaciones.`;
    }
    case 'ADD_ATTRIBUTE': return `Agregar el atributo «${command.payload.name}: ${command.payload.dataType}» a «${project.classes.find((item) => item.id === command.targetId)?.name ?? 'clase'}».`;
    case 'UPDATE_ATTRIBUTE': return `Actualizar el atributo «${project.classes.flatMap((item) => item.attributes).find((item) => item.id === command.targetId)?.name ?? 'atributo'}» con ${JSON.stringify(command.payload)}.`;
    case 'DELETE_ATTRIBUTE': return `Eliminar el atributo «${project.classes.flatMap((item) => item.attributes).find((item) => item.id === command.targetId)?.name ?? 'atributo'}».`;
    case 'ADD_RELATIONSHIP': return `Crear relación entre «${project.classes.find((item) => item.id === command.payload.sourceClassId)?.name}» y «${project.classes.find((item) => item.id === command.payload.targetClassId)?.name}» (${command.payload.sourceMultiplicity} → ${command.payload.targetMultiplicity}).`;
    case 'UPDATE_RELATIONSHIP': return `Actualizar la relación indicada con ${JSON.stringify(command.payload)}.`;
    case 'DELETE_RELATIONSHIP': return 'Eliminar la relación indicada.';
    case 'MOVE_CLASS': return 'Mover la clase indicada.';
  }
}

export function TextCommandBar({ project, onExecute, parser, speechProvider, aiProvider, aiRemote = false }: TextCommandBarProps) {
  const [mode, setMode] = useState<'rules' | 'ai'>('rules');
  const commandParser = useMemo(
    () => parser ?? (mode === 'ai' && aiProvider
      ? new LocalLLMCommandParser(aiProvider) : new RuleBasedCommandParser()),
    [parser, mode, aiProvider],
  );
  const voice = useMemo(() => speechProvider ?? new BrowserSpeechProvider(), [speechProvider]);
  const [input, setInput] = useState('');
  const [feedback, setFeedback] = useState<Feedback | null>(null);
  const [proposal, setProposal] = useState<Proposal | null>(null);
  const [isParsing, setIsParsing] = useState(false);
  const [isListening, setIsListening] = useState(false);

  useEffect(() => () => voice.cancel(), [voice]);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (isParsing || isListening) return;

    setIsParsing(true);
    setProposal(null);
    try {
      const result = await commandParser.parse(input, project);
      if (!result.ok) {
        setFeedback({ kind: 'error', message: result.error.message });
        return;
      }
      new CommandExecutor().execute(project, result.command);
      setProposal({ command: result.command, description: describe(result.command, project), baseRevision: project.revision,
        ...(result.explanation ? { explanation: result.explanation } : {}),
        ...(result.assumptions ? { assumptions: result.assumptions } : {}) });
      setFeedback(null);
    } catch (error) {
      setFeedback({
        kind: 'error',
        message: error instanceof CommandValidationError
          ? error.issues.map((item) => item.message).join(' ')
          : 'No se pudo interpretar el comando.',
      });
    } finally {
      setIsParsing(false);
    }
  };

  const confirm = () => {
    if (!proposal) return;
    if (project.revision !== proposal.baseRevision) {
      setProposal(null);
      setFeedback({ kind: 'error', message: 'El proyecto cambió. Revisa el comando otra vez.' });
      return;
    }
    if (!onExecute(proposal.command)) return;
    setInput('');
    setProposal(null);
    setFeedback({ kind: 'success', message: 'Comando aplicado al modelo.' });
  };

  const dictate = async () => {
    if (isListening || isParsing) return;
    setIsListening(true);
    setFeedback(null);
    setProposal(null);
    try {
      setInput(await voice.listen());
    } catch (error) {
      setFeedback({ kind: 'error', message: error instanceof Error ? error.message : 'No se pudo reconocer la voz.' });
    } finally {
      setIsListening(false);
    }
  };

  return (
    <section className="text-command-panel" aria-label="Comandos de texto y voz">
      <form className="text-command-form" onSubmit={submit}>
        <label htmlFor="text-command">Comando</label>
        <input
          id="text-command"
          value={input}
          onChange={(event) => { setInput(event.target.value); setFeedback(null); setProposal(null); }}
          placeholder="Ej.: crea clase Factura"
          autoComplete="off"
          disabled={isParsing || isListening}
        />
        <button type="button" className="button button--secondary" onClick={dictate} disabled={!voice.isSupported() || isParsing || isListening}>
          {isListening ? 'Escuchando…' : '🎤 Dictar'}
        </button>
        <button type="submit" className="button button--secondary" disabled={isParsing || isListening}>
          {isParsing ? 'Interpretando…' : 'Revisar propuesta'}
        </button>
      </form>
      {aiProvider && !parser && (
        <div className="command-mode" role="group" aria-label="Modo de interpretación">
          <button type="button" className="button button--small" aria-pressed={mode === 'rules'} onClick={() => { setMode('rules'); setProposal(null); }}>Reglas</button>
          <button type="button" className="button button--small" aria-pressed={mode === 'ai'} onClick={() => { setMode('ai'); setProposal(null); }}>IA asistida</button>
          {mode === 'ai' && <span>El contexto UML se enviará al proveedor {aiRemote ? 'remoto' : 'configurado'} al revisar la propuesta.</span>}
        </div>
      )}
      <p className="text-command-help">La voz puede ser procesada por un servicio del navegador. Revisa la transcripción antes de aplicar cambios. {!voice.isSupported() && 'Tu navegador no admite dictado; puedes escribir el comando.'}</p>
      {proposal && (
        <div className="command-proposal" role="region" aria-label="Propuesta de cambio">
          <p><strong>Propuesta:</strong> {proposal.description}</p>
          {proposal.explanation && <p><strong>Motivo:</strong> {proposal.explanation}</p>}
          {proposal.assumptions?.length ? <p><strong>Suposiciones:</strong> {proposal.assumptions.join('; ')}</p> : null}
          <div className="inline-actions">
            <button type="button" className="button button--primary" onClick={confirm}>Confirmar cambio</button>
            <button type="button" className="button" onClick={() => setProposal(null)}>Cancelar</button>
          </div>
        </div>
      )}
      {feedback && <p className={`text-command-feedback text-command-feedback--${feedback.kind}`} role={feedback.kind === 'error' ? 'alert' : 'status'}>{feedback.message}</p>}
    </section>
  );
}
