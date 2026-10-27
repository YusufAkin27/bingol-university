// /admin/users/:id/message (tekil) -> /admin/users/:id/messages (sorgu parametreleri korunur).
import { Navigate, useLocation, useParams } from 'react-router-dom';
import { paths } from '../../../paths';

export default function LegacyMessageRedirect() {
  const { id } = useParams();
  const { search } = useLocation();
  return <Navigate to={{ pathname: paths.admin.userMessages(id ?? ''), search }} replace />;
}
