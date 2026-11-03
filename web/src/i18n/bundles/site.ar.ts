// Site sözlüğü (ar): ziyaretçinin gördüğü tüm metinler. Yalnız kendi dilinin parçası indirilir (registry.ts dinamik içe aktarır).
import common from '../ar/common';
import site from '../ar/site';
import siteNew from '../ar/site-new';
import siteV3 from '../ar/site-v3';
import siteRd01 from '../ar/site-rd01';
import siteRd02 from '../ar/site-rd02';
import siteRd03 from '../ar/site-rd03';
import siteRd04 from '../ar/site-rd04';
import siteRd05 from '../ar/site-rd05';
import siteRd06 from '../ar/site-rd06';
import siteRd07 from '../ar/site-rd07';
import legal from '../ar/legal';
import pages from '../ar/pages';
import supportPublic from '../ar/support-public';
import seo from '../ar/seo';
import childSafety from '../ar/child-safety';
import siteTrust from '../ar/site-trust';
import siteRd10 from '../ar/site-rd10';

export default { ...common, ...site, ...siteNew, ...siteV3, ...legal, ...pages, ...supportPublic, ...seo, ...childSafety, ...siteTrust, ...siteRd10, ...siteRd01, ...siteRd02, ...siteRd03, ...siteRd04, ...siteRd05, ...siteRd06, ...siteRd07 };
