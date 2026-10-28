// Site sözlüğü (en): ziyaretçinin gördüğü tüm metinler. Yalnız kendi dilinin parçası indirilir (registry.ts dinamik içe aktarır).
import common from '../en/common';
import site from '../en/site';
import siteNew from '../en/site-new';
import legal from '../en/legal';
import pages from '../en/pages';
import supportPublic from '../en/support-public';
import seo from '../en/seo';

export default { ...common, ...site, ...siteNew, ...legal, ...pages, ...supportPublic, ...seo };
