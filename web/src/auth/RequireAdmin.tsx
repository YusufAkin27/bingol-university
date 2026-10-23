import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from './AuthProvider';
import { ForbiddenScreen } from './ForbiddenScreen';
import { Spinner } from '../components/ui/Feedback';

/** /admin altındaki rotaları korur. Giriş yoksa /admin/login'e, ADMIN değilse "yetkiniz yok" ekranına. */
export function RequireAdmin({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  const location = useLocation();

  if (status === 'loading') {
    return (
      <div style={{ display: 'grid', placeItems: 'center', minHeight: '60vh' }}>
        <Spinner size="lg" />
      </div>
    );
  }
  if (status === 'anonymous') {
    return <Navigate to="/admin/login" replace state={{ from: location.pathname + location.search }} />;
  }
  if (status === 'forbidden') return <ForbiddenScreen />;
  return <>{children}</>;
}
