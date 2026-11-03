// Site sözlüğü (en): ziyaretçinin gördüğü tüm metinler. Yalnız kendi dilinin parçası indirilir (registry.ts dinamik içe aktarır).
import common from '../en/common';
import site from '../en/site';
import siteNew from '../en/site-new';
import siteV3 from '../en/site-v3';
import siteRd06 from '../en/site-rd06';
import legal from '../en/legal';
import pages from '../en/pages';
import supportPublic from '../en/support-public';
import seo from '../en/seo';
import childSafety from '../en/child-safety';
import siteTrust from '../en/site-trust';

export default { ...common, ...site, ...siteNew, ...siteV3, ...siteRd06, ...legal, ...pages, ...supportPublic, ...seo, ...childSafety, ...siteTrust };
