// Site sözlüğü (tr): ziyaretçinin gördüğü tüm metinler. Yalnız kendi dilinin parçası indirilir (registry.ts dinamik içe aktarır).
import common from '../tr/common';
import site from '../tr/site';
import siteNew from '../tr/site-new';
import legal from '../tr/legal';
import pages from '../tr/pages';
import supportPublic from '../tr/support-public';
import seo from '../tr/seo';

export default { ...common, ...site, ...siteNew, ...legal, ...pages, ...supportPublic, ...seo };
