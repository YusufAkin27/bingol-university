// إدارة صور قائمة الطعام (/admin/content/menu).
const m = {
  'admin.nav.menu': 'قائمة الطعام',

  'admin.menu.title': 'قائمة الطعام',
  'admin.menu.subtitle': 'أضف صورة اختيارية لقائمة اليوم أو استبدلها أو أزلها. تظهر الصورة بجانب القائمة في التطبيق.',
  'admin.menu.filters': 'عوامل تصفية القائمة',
  'admin.menu.month': 'الشهر',
  'admin.menu.hint': 'JPEG أو PNG أو WebP، حتى 5 ميغابايت.',
  'admin.menu.pickMonth': 'اختر شهرًا صالحًا',
  'admin.menu.empty': 'لا توجد قائمة لهذا الشهر',
  'admin.menu.noItems': 'لا توجد أصناف',
  'admin.menu.noImage': 'لا توجد صورة',
  'admin.menu.imageAlt': 'صورة قائمة {date}',
  'admin.menu.fileInput': 'اختر صورة ليوم {date}',
  'admin.menu.add': 'إضافة صورة',
  'admin.menu.replace': 'استبدال',
  'admin.menu.remove': 'إزالة',
  'admin.menu.uploading': 'جارٍ الرفع…',
  'admin.menu.uploaded': 'تم حفظ الصورة',
  'admin.menu.removed': 'تمت إزالة الصورة',
  'admin.menu.removeTitle': 'إزالة الصورة؟',
  'admin.menu.removeMsg': 'ستتم إزالة صورة قائمة يوم {date}.',
  'admin.menu.err.type': 'يمكن رفع ملفات JPEG أو PNG أو WebP فقط.',
  'admin.menu.err.size': 'الحد الأقصى لحجم الملف 5 ميغابايت.',
  'admin.menu.err.empty': 'الملف فارغ.',
  'admin.err.MENU_DAY_NOT_FOUND': 'لا توجد قائمة لهذا اليوم.',
} as const;

export default m;
