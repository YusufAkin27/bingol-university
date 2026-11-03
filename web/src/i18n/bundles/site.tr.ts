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
import siteRd01 from '../tr/site-rd01';
import siteRd02 from '../tr/site-rd02';
import siteRd03 from '../tr/site-rd03';
import siteRd04 from '../tr/site-rd04';
import siteRd05 from '../tr/site-rd05';
import siteRd06 from '../tr/site-rd06';
import siteRd07 from '../tr/site-rd07';
import siteRd08 from '../tr/site-rd08';
import siteRd09 from '../tr/site-rd09';
import siteRd10 from '../tr/site-rd10';

export default { ...common, ...site, ...siteNew, ...siteV3, ...legal, ...pages, ...supportPublic, ...seo, ...childSafety, ...siteTrust, ...siteRd10, ...siteRd01, ...siteRd02, ...siteRd03, ...siteRd04, ...siteRd05, ...siteRd06, ...siteRd07, ...siteRd08, ...siteRd09 };
