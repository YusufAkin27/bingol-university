// Site sözlüğü (tr): ziyaretçinin gördüğü tüm metinler. Yalnız kendi dilinin parçası indirilir (registry.ts dinamik içe aktarır).
import common from '../tr/common';
import site from '../tr/site';
import siteNew from '../tr/site-new';
import siteV3 from '../tr/site-v3';
import legal from '../tr/legal';
import pages from '../tr/pages';
import supportPublic from '../tr/support-public';
import seo from '../tr/seo';
import childSafety from '../tr/child-safety';
import siteTrust from '../tr/site-trust';
import siteRd09 from '../tr/site-rd09';

export default { ...common, ...site, ...siteNew, ...siteV3, ...legal, ...pages, ...supportPublic, ...seo, ...childSafety, ...siteTrust, ...siteRd09 };
