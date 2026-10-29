// Yalnız Türkçe yönetim ad alanları (panel tr'ye sabit); en/ar tam sözlüklerine de aynı Türkçe metin katılır (all.ts).
import Guard from '../tr/admin-guard';
import Shell from '../tr/admin-shell';
import P05 from '../tr/admin-p05';
import P03 from '../tr/admin-p03';
import Wp02 from '../tr/admin-wp02';
import P06 from '../tr/admin-p06';
import P07 from '../tr/admin-p07';
import P08 from '../tr/admin-p08';
import P09 from '../tr/admin-p09';
import P11 from '../tr/admin-p11';
import P13 from '../tr/admin-p13';
import P14 from '../tr/admin-p14';
import P15 from '../tr/admin-p15';
import P16 from '../tr/admin-p16';
import Cr1 from '../tr/admin-cr1';
import Ds1 from '../tr/admin-ds1';
import Reg from '../tr/admin-reg';

export default {
  ...Guard,
  ...Shell,
  ...P05,
  ...P03,
  ...Wp02,
  ...P06,
  ...P07,
  ...P08,
  ...P09,
  ...P11,
  ...P13,
  ...P14,
  ...P15,
  ...P16,
  ...Cr1,
  ...Ds1,
  ...Reg,
};
