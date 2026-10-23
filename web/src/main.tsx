import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { applyDocumentLang, getCurrentLang } from './i18n/lang';
import './styles/tokens.css';
import './styles/global.css';

applyDocumentLang(getCurrentLang());

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
