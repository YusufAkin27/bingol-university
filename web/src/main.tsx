import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { applyDocumentLang, getCurrentLang, setCurrentLang } from './i18n/lang';
import { splitLangPath } from './i18n/langPath';
import './styles/tokens.css';
import './styles/global.css';

// Dil önekli adres (/en/...) kayıtlı tercihten önce gelir: ilk boyamadan önce eşitlenir (bu.lang da güncellenir)
const urlLang = splitLangPath(window.location.pathname).lang;
if (urlLang && urlLang !== getCurrentLang()) setCurrentLang(urlLang);
applyDocumentLang(getCurrentLang());

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
