// Yetkili (Bearer) ön izleme uçlarını <img>/<video> için geçici nesne adresine çevirir.
import { useEffect, useState } from 'react';
import { apiBlob } from '../../../api/client';
import { previewApiPath } from './chatLogic';

export interface BlobState {
  src: string | null;
  failed: boolean;
}

export function useBlobUrl(apiUrl: string | null | undefined): BlobState {
  const [state, setState] = useState<BlobState>({ src: null, failed: false });
  useEffect(() => {
    if (!apiUrl) {
      setState({ src: null, failed: false });
      return;
    }
    let cancelled = false;
    let url: string | null = null;
    setState({ src: null, failed: false });
    apiBlob(previewApiPath(apiUrl))
      .then((b) => {
        if (cancelled) return;
        url = URL.createObjectURL(b);
        setState({ src: url, failed: false });
      })
      .catch(() => {
        if (!cancelled) setState({ src: null, failed: true });
      });
    return () => {
      cancelled = true;
      if (url) URL.revokeObjectURL(url);
    };
  }, [apiUrl]);
  return state;
}
