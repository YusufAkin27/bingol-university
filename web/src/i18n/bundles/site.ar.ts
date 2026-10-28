// Site sözlüğü (ar): ziyaretçinin gördüğü tüm metinler. Yalnız kendi dilinin parçası indirilir (registry.ts dinamik içe aktarır).
import common from '../ar/common';
import site from '../ar/site';
import siteNew from '../ar/site-new';
import legal from '../ar/legal';
import pages from '../ar/pages';
import supportPublic from '../ar/support-public';
import seo from '../ar/seo';

export default { ...common, ...site, ...siteNew, ...legal, ...pages, ...supportPublic, ...seo };
