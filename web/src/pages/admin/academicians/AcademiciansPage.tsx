// /admin/academicians ve /admin/academicians/:id tek tembel parçadır: :id varsa ayrıntı, yoksa başvuru listesi.
import { useParams } from 'react-router-dom';
import AcademicianDetail from './AcademicianDetail';
import AcademiciansList from './AcademiciansList';

export default function AcademiciansPage() {
  const { id } = useParams();
  return id === undefined ? <AcademiciansList /> : <AcademicianDetail />;
}
