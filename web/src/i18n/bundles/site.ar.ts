// Site sözlüğü (ar): ziyaretçinin gördüğü tüm metinler. Yalnız kendi dilinin parçası indirilir (registry.ts dinamik içe aktarır).
import common from '../ar/common';
import site from '../ar/site';
import siteNew from '../ar/site-new';
import siteV3 from '../ar/site-v3';
import siteRd06 from '../ar/site-rd06';
import legal from '../ar/legal';
import pages from '../ar/pages';
import supportPublic from '../ar/support-public';
import seo from '../ar/seo';
import childSafety from '../ar/child-safety';
import siteTrust from '../ar/site-trust';

export default { ...common, ...site, ...siteNew, ...siteV3, ...siteRd06, ...legal, ...pages, ...supportPublic, ...seo, ...childSafety, ...siteTrust };
