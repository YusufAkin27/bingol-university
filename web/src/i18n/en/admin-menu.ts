// Menu photo management (/admin/content/menu).
const m = {
  'admin.nav.menu': 'Meal menu',

  'admin.menu.title': 'Meal menu',
  'admin.menu.subtitle': 'Add, replace or remove an optional photo for a day\'s menu. The photo is shown next to the menu in the app.',
  'admin.menu.filters': 'Menu filters',
  'admin.menu.month': 'Month',
  'admin.menu.hint': 'JPEG, PNG or WebP; up to 5 MB.',
  'admin.menu.pickMonth': 'Pick a valid month',
  'admin.menu.empty': 'No menu for this month',
  'admin.menu.noItems': 'No menu items',
  'admin.menu.noImage': 'No photo',
  'admin.menu.imageAlt': 'Menu photo for {date}',
  'admin.menu.fileInput': 'Choose a photo for {date}',
  'admin.menu.add': 'Add photo',
  'admin.menu.replace': 'Replace',
  'admin.menu.remove': 'Remove',
  'admin.menu.uploading': 'Uploading…',
  'admin.menu.uploaded': 'Photo saved',
  'admin.menu.removed': 'Photo removed',
  'admin.menu.removeTitle': 'Remove the photo?',
  'admin.menu.removeMsg': 'The menu photo for {date} will be removed.',
  'admin.menu.err.type': 'Only JPEG, PNG or WebP files can be uploaded.',
  'admin.menu.err.size': 'The file can be at most 5 MB.',
  'admin.menu.err.empty': 'The file is empty.',
  'admin.err.MENU_DAY_NOT_FOUND': 'No menu found for this day.',
} as const;

export default m;
