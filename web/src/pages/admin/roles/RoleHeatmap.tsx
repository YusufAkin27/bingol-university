// Roller ve izinler: ısı haritası. Satır = alan (kullanıcılar, moderasyon...), sütun = yönetici profili,
// hücre = "o profil bu alandaki izinlerin kaçına sahip" (renk koyuluğu + "3/4" yazısı; yalnız renge güvenilmez).
// Satır adına basınca ayrıntılı tablo yalnız o alanı gösterir (onFocusGroup).
import { useMemo } from 'react';
import type { AdminProfile, RbacMatrix } from '../../../api/rbac';
import { Insight } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { buildGroupRows, narrowestProfile, profileCoverage } from './permGroups';
import { useGt } from '../sys2Dict';
import styles from './heatmap.module.css';

export function RoleHeatmap({
  matrix,
  focusGroup,
  onFocusGroup,
}: {
  matrix: RbacMatrix;
  focusGroup: string | null;
  onFocusGroup: (group: string | null) => void;
}) {
  const { t, td, formatNumber } = useI18n();
  const gt = useGt();
  const profileName = (p: AdminProfile) => t(`admin.p16.profile.${p}`);
  const rows = useMemo(() => buildGroupRows(matrix.entries, matrix.profiles), [matrix]);
  const cov = useMemo(() => profileCoverage(matrix.entries, matrix.profiles), [matrix]);
  const narrow = narrowestProfile(cov);
  const groupName = (g: string) => td(`admin.sys2.roles.group.${g}`, g);

  return (
    <div className={styles.wrap} data-testid="roles-heatmap">
      {narrow && (
        <Insight
          tone="info"
          parts={gt('admin.sys2.roles.insight', {
            name: profileName(narrow.profile),
            n: formatNumber(narrow.granted),
            total: formatNumber(narrow.total),
            p: formatNumber(narrow.percent),
          })}
        />
      )}
      <div className={styles.scroll}>
        <table className={styles.map} aria-label={gt('admin.sys2.roles.mapCaption')}>
          <thead>
            <tr>
              <th scope="col">{gt('admin.sys2.roles.area')}</th>
              {matrix.profiles.map((p) => (
                <th key={p} scope="col" title={t(`admin.p16.profileDesc.${p}`)}>
                  {gt(`admin.sys2.roles.short.${p}`)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => {
              const on = focusGroup === r.group;
              return (
                <tr key={r.group} data-group={r.group} data-focus={on || undefined}>
                  <th scope="row">
                    <button
                      type="button"
                      className={styles.groupBtn}
                      aria-pressed={on}
                      onClick={() => onFocusGroup(on ? null : r.group)}
                      title={gt('admin.sys2.roles.focusHint')}
                    >
                      <span>{groupName(r.group)}</span>
                      <span className={styles.groupCount}>{gt('admin.sys2.roles.permCount', { n: r.total })}</span>
                    </button>
                  </th>
                  {r.cells.map((c) => (
                    <td
                      key={c.profile}
                      className={styles.cell}
                      data-level={c.level}
                      title={
                        c.missing.length
                          ? gt('admin.sys2.roles.missing', { list: c.missing.join(', ') })
                          : gt('admin.sys2.roles.allGranted')
                      }
                    >
                      <span aria-hidden="true">
                        {c.granted}/{c.total}
                      </span>
                      <span className={styles.srOnly}>
                        {gt('admin.sys2.roles.cellText', {
                          profile: profileName(c.profile),
                          area: groupName(r.group),
                          n: c.granted,
                          total: c.total,
                        })}
                      </span>
                    </td>
                  ))}
                </tr>
              );
            })}
          </tbody>
          <tfoot>
            <tr>
              <th scope="row">{gt('admin.sys2.roles.overall')}</th>
              {cov.map((c) => (
                <td key={c.profile} className={styles.total}>
                  %{formatNumber(c.percent)}
                </td>
              ))}
            </tr>
          </tfoot>
        </table>
      </div>
      <div className={styles.legend} aria-hidden="true">
        <span>{gt('admin.sys2.roles.legend.none')}</span>
        {[0, 1, 2, 3, 4].map((l) => (
          <span key={l} className={styles.swatch} data-level={l} />
        ))}
        <span>{gt('admin.sys2.roles.legend.all')}</span>
      </div>
    </div>
  );
}
