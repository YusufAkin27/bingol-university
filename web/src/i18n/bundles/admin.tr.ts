// Yönetim sözlüğü (tr). Panel yalnız Türkçedir: üretimde yalnız admin.tr yüklenir; en/ar sürümü tür bütünlüğü ve testler için (all.ts).
import Academic from '../tr/admin-academic';
import Accessbans from '../tr/admin-accessbans';
import Analytics from '../tr/admin-analytics';
import Campaigns from '../tr/admin-campaigns';
import Chat from '../tr/admin-chat';
import CommunityCategories from '../tr/admin-community-categories';
import Content from '../tr/admin-content';
import Dashboard from '../tr/admin-dashboard';
import Events from '../tr/admin-events';
import Mail from '../tr/admin-mail';
import Menu from '../tr/admin-menu';
import Moderation from '../tr/admin-moderation';
import Ops from '../tr/admin-ops';
import Pending from '../tr/admin-pending';
import Polls from '../tr/admin-polls';
import Posts from '../tr/admin-posts';
import Profanity from '../tr/admin-profanity';
import Push from '../tr/admin-push';
import Safety from '../tr/admin-safety';
import Settings from '../tr/admin-settings';
import Support from '../tr/admin-support';
import System from '../tr/admin-system';
import Users from '../tr/admin-users';
import trOnly from './admin-tr-only';

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
  ...trOnly,
};
