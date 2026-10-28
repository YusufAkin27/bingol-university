// Yönetim sözlüğü (ar). Panel yalnız Türkçedir: üretimde yalnız admin.tr yüklenir; en/ar sürümü tür bütünlüğü ve testler için (all.ts).
import Academic from '../ar/admin-academic';
import Accessbans from '../ar/admin-accessbans';
import Analytics from '../ar/admin-analytics';
import Campaigns from '../ar/admin-campaigns';
import Chat from '../ar/admin-chat';
import CommunityCategories from '../ar/admin-community-categories';
import Content from '../ar/admin-content';
import Dashboard from '../ar/admin-dashboard';
import Events from '../ar/admin-events';
import Mail from '../ar/admin-mail';
import Menu from '../ar/admin-menu';
import Moderation from '../ar/admin-moderation';
import Ops from '../ar/admin-ops';
import Pending from '../ar/admin-pending';
import Polls from '../ar/admin-polls';
import Posts from '../ar/admin-posts';
import Profanity from '../ar/admin-profanity';
import Push from '../ar/admin-push';
import Safety from '../ar/admin-safety';
import Settings from '../ar/admin-settings';
import Support from '../ar/admin-support';
import System from '../ar/admin-system';
import Users from '../ar/admin-users';

export default {
  ...Academic,
  ...Accessbans,
  ...Analytics,
  ...Campaigns,
  ...Chat,
  ...CommunityCategories,
  ...Content,
  ...Dashboard,
  ...Events,
  ...Mail,
  ...Menu,
  ...Moderation,
  ...Ops,
  ...Pending,
  ...Polls,
  ...Posts,
  ...Profanity,
  ...Push,
  ...Safety,
  ...Settings,
  ...Support,
  ...System,
  ...Users,
};
