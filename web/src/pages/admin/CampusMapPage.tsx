// SAYFA: Kampüs haritası (/admin/campus)
// API: GET/POST /api/admin/campus/places, PUT/DELETE /api/admin/campus/places/{id} (silme gerekçeli),
//      GET/PUT /api/admin/campus/config (kaydetmek gerekçeli)  -> api/adminCampus.ts.
// İzinler: campus.read (sayfa) / campus.write (ekle, düzenle, aç-kapat, sil, ayar kaydı). Yazma düğmeleri izinsizlere GİZLİDİR.
// Gerçek harita kütüphanesi yok: konum doğrulaması şematik önizleme + OpenStreetMap bağlantısıyla yapılır.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { campusKeys, getCampusConfig, listAllCampusPlaces, type CampusPlace } from '../../api/adminCampus';
import { Button, Icon, PageHeader, Tabs } from '../../components/ui';
import { usePermissions } from '../../auth/permissions';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { useSearchReveal } from '../../search/anchor';
import { useUrlTab } from '../../search/useUrlTab';
import { ConfigPanel } from './campus/ConfigPanel';
import { CampusSummary } from './campus/CampusSummary';
import { gt } from './campus/dict';
import { PlaceForm } from './campus/PlaceForm';
import { PlacesPanel } from './campus/PlacesPanel';
import styles from './campus/campus.module.css';

const TABS = ['places', 'settings'] as const;
type TabId = (typeof TABS)[number];

export default function CampusMapPage() {
  const i18n = useI18n();
  const t = gt(i18n);
  usePageTitle(t('admin.campus.title'));
  const perms = usePermissions();
  // Yüklenirken yazma düğmeleri çizilmez (görünüp kaybolmasın); bilgi alınamazsa serbest (sunucu denetler)
  const canWrite = perms.status !== 'loading' && perms.can('campus.write');
  const [tab, setTab] = useUrlTab<TabId>(TABS, 'places');
  const [editing, setEditing] = useState<CampusPlace | 'new' | null>(null);

  const places = useQuery({ queryKey: campusKeys.places, queryFn: ({ signal }) => listAllCampusPlaces(signal) });
  const config = useQuery({ queryKey: campusKeys.config, queryFn: getCampusConfig });

  // Arama derin bağlantıları: form alanları yalnız panel açıkken, ayar alanları yalnız kendi sekmesinde çizilir
  useSearchReveal((anchor) => {
    if (anchor.startsWith('cfg-')) setTab('settings');
    else if (anchor.startsWith('campus-') && /^campus-(name|category|sortkey|coords|paste|check|summary|units|footprint)$/.test(anchor)) {
      if (canWrite && editing === null) {
        setTab('places');
        setEditing('new');
      }
    }
  });

  return (
    <>
      <PageHeader
        title={t('admin.campus.title')}
        description={t('admin.campus.subtitle')}
        actions={
          canWrite ? (
            <Button
              data-search-anchor="campus-add"
              leftIcon={<Icon name="plus" size={16} aria-hidden="true" />}
              onClick={() => {
                setTab('places');
                setEditing('new');
              }}
            >
              {t('admin.campus.add')}
            </Button>
          ) : undefined
        }
      />
      <div className={styles.stack}>
        <CampusSummary
          places={places.data}
          configUpdatedAt={config.data?.updatedAt}
          loading={places.isLoading}
          error={places.isError}
          onRetry={() => void places.refetch()}
        />
        <Tabs
          label={t('admin.campus.tabs')}
          value={tab}
          onChange={(id) => setTab(id as TabId)}
          tabs={[
            { id: 'places', label: t('admin.campus.tab.places') },
            { id: 'settings', label: t('admin.campus.tab.settings') },
          ]}
        />
        {tab === 'places' ? (
          <PlacesPanel query={places} canWrite={canWrite} onEdit={setEditing} onAdd={() => setEditing('new')} />
        ) : (
          <ConfigPanel query={config} canWrite={canWrite} />
        )}
      </div>
      {editing !== null && canWrite && (
        <PlaceForm
          key={editing === 'new' ? 'new' : editing.id}
          place={editing === 'new' ? null : editing}
          boundary={config.data?.boundary ?? []}
          onClose={() => setEditing(null)}
        />
      )}
    </>
  );
}
