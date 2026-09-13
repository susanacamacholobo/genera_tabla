import { useMemo, useState, type FormEvent } from 'react';
import {
  RuleBasedCommandParser,
  type Command,
  type NaturalLanguageCommandParser,
  type ProjectModel,
} from '../../../domain';

export interface TextCommandBarProps {
  project: ProjectModel;
  onExecute: (command: Command) => boolean;
  parser?: NaturalLanguageCommandParser;
}

interface Feedback {
  kind: 'error' | 'success';
  message: string;
}

export function TextCommandBar({ project, onExecute, parser }: TextCommandBarProps) {
  const commandParser = useMemo(() => parser ?? new RuleBasedCommandParser(), [parser]);
  const [input, setInput] = useState('');
  const [feedback, setFeedback] = useState<Feedback | null>(null);

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const result = commandParser.parse(input, project);
    if (!result.ok) {
      setFeedback({ kind: 'error', message: result.error.message });
      return;
    }

    if (!onExecute(result.command)) {
      setFeedback(null);
      return;
    }

    setInput('');
    setFeedback({ kind: 'success', message: 'Comando aplicado al modelo.' });
  };

  return (
    <section className="text-command-panel" aria-label="Comandos de texto">
      <form className="text-command-form" onSubmit={submit}>
        <label htmlFor="text-command">Comando</label>
        <input
          id="text-command"
          value={input}
          onChange={(event) => {
            setInput(event.target.value);
            setFeedback(null);
          }}
          placeholder="Ej.: crea clase Factura"
          autoComplete="off"
        />
        <button type="submit" className="button button--secondary">Ejecutar</button>
      </form>
      {feedback && (
        <p
          className={`text-command-feedback text-command-feedback--${feedback.kind}`}
          role={feedback.kind === 'error' ? 'alert' : 'status'}
        >
          {feedback.message}
        </p>
      )}
      <p className="text-command-help">
        Prueba: «crea clase Cliente», «agrega nombre String a Cliente» o «elimina Cliente».
      </p>
    </section>
  );
}
