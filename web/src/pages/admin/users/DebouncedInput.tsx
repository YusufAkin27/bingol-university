import { useEffect, useRef, useState } from 'react';
import { Input } from '../../../components/ui';
import { useDebouncedValue } from '../../../lib/hooks';

interface Props {
  value: string;
  onCommit: (value: string) => void;
  label: string;
  placeholder?: string;
  delay?: number;
}

/** Yazdıkça değil, yazım durunca değer bildiren metin alanı; dış değer değişirse (filtre temizleme) kendini eşitler. */
export function DebouncedInput({ value, onCommit, label, placeholder, delay = 400 }: Props) {
  const [text, setText] = useState(value);
  const debounced = useDebouncedValue(text, delay);
  const committed = useRef(value);
  const cb = useRef(onCommit);
  cb.current = onCommit;

  useEffect(() => {
    if (value !== committed.current) {
      committed.current = value;
      setText(value);
    }
  }, [value]);

  useEffect(() => {
    const next = debounced.trim();
    if (next !== committed.current) {
      committed.current = next;
      cb.current(next);
    }
  }, [debounced]);

  return (
    <Input
      type="text"
      value={text}
      aria-label={label}
      placeholder={placeholder ?? label}
      onChange={(e) => setText(e.target.value)}
    />
  );
}
