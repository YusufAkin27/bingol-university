/**
 * Akademisyen paneli rotaları: site ve yönetim paketlerinden AYRI parça (routes.tsx bunu React.lazy ile yükler). Kendi oturum
 * sağlayıcısı (AcademicianScope), kendi kabuğu (AcadLayout) ve rota koruması (RequireAcademician) vardır; yönetim oturumuyla
 * hiçbir bağı yoktur. Yollar `/akademisyen` altına göre GÖRELİdir. Canlı yoklama sayfası `qrcode-generator`ı yalnız kendi parçasında çeker.
 */
import { lazy } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import AcademicianScope from './pages/academician/AcademicianScope';
import AcadLayout from './pages/academician/AcadLayout';
import { RequireAcademician } from './pages/academician/auth/AcadAuth';
import { acadPaths } from './pages/academician/paths';

const LoginPage = lazy(() => import('./pages/academician/auth/LoginPage'));
const RegisterPage = lazy(() => import('./pages/academician/auth/RegisterPage'));
const PendingPage = lazy(() => import('./pages/academician/auth/PendingPage'));
const DashboardPage = lazy(() => import('./pages/academician/DashboardPage'));
const CoursesPage = lazy(() => import('./pages/academician/CoursesPage'));
const CourseDetailPage = lazy(() => import('./pages/academician/course/CourseDetailPage'));
const EnrollPage = lazy(() => import('./pages/academician/EnrollPage'));
const LivePage = lazy(() => import('./pages/academician/live/LivePage'));
const ProfilePage = lazy(() => import('./pages/academician/ProfilePage'));

export default function AcademicianRoutes() {
  return (
    <Routes>
      <Route element={<AcademicianScope />}>
        <Route path="giris" element={<LoginPage />} />
        <Route path="kayit" element={<RegisterPage />} />
        <Route path="beklemede" element={<PendingPage />} />
        <Route
          element={
            <RequireAcademician>
              <AcadLayout />
            </RequireAcademician>
          }
        >
          <Route index element={<DashboardPage />} />
          <Route path="dersler" element={<CoursesPage />} />
          <Route path="dersler/:id" element={<CourseDetailPage />} />
          <Route path="dersler/:id/ogrenciler/ekle" element={<EnrollPage />} />
          <Route path="yoklama/:sessionId" element={<LivePage />} />
          <Route path="profil" element={<ProfilePage />} />
          <Route path="*" element={<Navigate to={acadPaths.home} replace />} />
        </Route>
      </Route>
    </Routes>
  );
}
