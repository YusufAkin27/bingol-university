// Yönetim sözlüğü (en). Panel yalnız Türkçedir: üretimde yalnız admin.tr yüklenir; en/ar sürümü tür bütünlüğü ve testler için (all.ts).
import Academic from '../en/admin-academic';
import Accessbans from '../en/admin-accessbans';
import Analytics from '../en/admin-analytics';
import Campaigns from '../en/admin-campaigns';
import Chat from '../en/admin-chat';
import CommunityCategories from '../en/admin-community-categories';
import Content from '../en/admin-content';
import Dashboard from '../en/admin-dashboard';
import Events from '../en/admin-events';
import Mail from '../en/admin-mail';
import Menu from '../en/admin-menu';
import Moderation from '../en/admin-moderation';
import Ops from '../en/admin-ops';
import Pending from '../en/admin-pending';
import Polls from '../en/admin-polls';
import Posts from '../en/admin-posts';
import Profanity from '../en/admin-profanity';
import Push from '../en/admin-push';
import Safety from '../en/admin-safety';
import Settings from '../en/admin-settings';
import Support from '../en/admin-support';
import System from '../en/admin-system';
import Users from '../en/admin-users';

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
