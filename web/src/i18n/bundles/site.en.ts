// Site sözlüğü (en): ziyaretçinin gördüğü tüm metinler. Yalnız kendi dilinin parçası indirilir (registry.ts dinamik içe aktarır).
import common from '../en/common';
import site from '../en/site';
import siteNew from '../en/site-new';
import siteV3 from '../en/site-v3';
import legal from '../en/legal';
import pages from '../en/pages';
import supportPublic from '../en/support-public';
import seo from '../en/seo';
import childSafety from '../en/child-safety';
import siteTrust from '../en/site-trust';
import siteRd09 from '../en/site-rd09';

export default { ...common, ...site, ...siteNew, ...siteV3, ...legal, ...pages, ...supportPublic, ...seo, ...childSafety, ...siteTrust, ...siteRd09 };
