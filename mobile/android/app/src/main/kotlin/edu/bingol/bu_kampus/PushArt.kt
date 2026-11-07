package edu.bingol.bu_kampus

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface

/** Bildirim karti bitmap parcalari: kategori ikon karosu, avatar kose rozeti/sayaci, yuvarlak/koseli kirpma. */
object PushArt {
    private fun glyphRes(g: Glyph): Int = when (g) {
        Glyph.CHAT -> R.drawable.ic_push_chat
        Glyph.GROUP -> R.drawable.ic_push_group
        Glyph.EVENT -> R.drawable.ic_push_event
        Glyph.SCHOOL -> R.drawable.ic_push_school
        Glyph.MEGAPHONE -> R.drawable.ic_push_megaphone
        Glyph.POLL -> R.drawable.ic_push_poll
        Glyph.MEAL -> R.drawable.ic_push_meal
        Glyph.HEART -> R.drawable.ic_push_heart
        Glyph.PERSON_ADD -> R.drawable.ic_push_person_add
        Glyph.LOCK -> R.drawable.ic_push_lock
        Glyph.CHECK -> R.drawable.ic_push_check
        Glyph.SHIELD -> R.drawable.ic_push_shield
        Glyph.SUPPORT -> R.drawable.ic_push_support
        Glyph.INFO -> R.drawable.ic_push_info
        Glyph.CLOCK -> R.drawable.ic_push_clock
        Glyph.PHOTO -> R.drawable.ic_push_photo
    }

    fun toneFg(c: Context, t: Tone): Int = c.getColor(when (t) {
        Tone.RED -> R.color.push_red_fg; Tone.BLUE -> R.color.push_blue_fg; Tone.PURPLE -> R.color.push_purple_fg
        Tone.ORANGE -> R.color.push_orange_fg; Tone.GREEN -> R.color.push_green_fg; Tone.GRAY -> R.color.push_gray_fg
    })

    fun toneBg(c: Context, t: Tone): Int = c.getColor(when (t) {
        Tone.RED -> R.color.push_red_bg; Tone.BLUE -> R.color.push_blue_bg; Tone.PURPLE -> R.color.push_purple_bg
        Tone.ORANGE -> R.color.push_orange_bg; Tone.GREEN -> R.color.push_green_bg; Tone.GRAY -> R.color.push_gray_bg
    })

    fun pillRes(t: Tone): Int = when (t) {
        Tone.RED -> R.drawable.push_pill_red; Tone.BLUE -> R.drawable.push_pill_blue; Tone.PURPLE -> R.drawable.push_pill_purple
        Tone.ORANGE -> R.drawable.push_pill_orange; Tone.GREEN -> R.drawable.push_pill_green; Tone.GRAY -> R.drawable.push_pill_gray
    }

    private fun drawGlyph(c: Context, canvas: Canvas, g: Glyph, color: Int, box: RectF) {
        val d = c.getDrawable(glyphRes(g))?.mutate() ?: return
        d.setTint(color)
        d.setBounds(box.left.toInt(), box.top.toInt(), box.right.toInt(), box.bottom.toInt())
        d.draw(canvas)
    }

    /** Pastel yuvarlak kare + ikon (avatar yoksa kategori karosu). */
    fun tile(c: Context, spec: IconSpec, px: Int): Bitmap {
        val out = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = toneBg(c, spec.tone) }
        canvas.drawRoundRect(RectF(0f, 0f, px.toFloat(), px.toFloat()), px * 0.28f, px * 0.28f, paint)
        val inset = px * 0.27f
        drawGlyph(c, canvas, spec.glyph, toneFg(c, spec.tone), RectF(inset, inset, px - inset, px - inset))
        return out
    }

    /**
     * Varsayilan avatar: profil fotografi yoksa (ya da gizlilik nedeniyle gonderilmediyse) adin bas harfli yuvarlak
     * (gri ton, kirmizi marka rengi yok). Ad bossa "?" yerine nokta degil, bos harf cizilmez.
     */
    fun initials(c: Context, name: String, px: Int): Bitmap {
        val out = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = c.getColor(R.color.push_gray_bg) }
        canvas.drawCircle(px / 2f, px / 2f, px / 2f, paint)
        val letter = initialOf(name)
        if (letter.isNotEmpty()) {
            val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = c.getColor(R.color.push_gray_fg); textSize = px * 0.46f
                textAlign = Paint.Align.CENTER; typeface = Typeface.DEFAULT
            }
            val y = px / 2f - (text.descent() + text.ascent()) / 2f
            canvas.drawText(letter, px / 2f, y, text)
        }
        return out
    }

    /** Adin ilk harfi (buyuk, Turkce kurallariyla); harf yoksa bos. Saf mantik: PushArtLogicTest. */
    fun initialOf(name: String): String {
        val first = name.trim().firstOrNull { it.isLetterOrDigit() } ?: return ""
        return first.toString().uppercase(java.util.Locale("tr"))
    }

    /** Kare/dikdortgen kaynagi merkezden kirpip [px] kare daire yapar. */
    fun circle(src: Bitmap, px: Int): Bitmap {
        val out = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawCircle(px / 2f, px / 2f, px / 2f, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(src, centerSquare(src), Rect(0, 0, px, px), paint)
        return out
    }

    private fun centerSquare(src: Bitmap): Rect {
        val side = minOf(src.width, src.height)
        return Rect((src.width - side) / 2, (src.height - side) / 2, (src.width + side) / 2, (src.height + side) / 2)
    }

    /** [w] x [h] alana merkezden kirpar, koseleri yuvarlar. */
    fun roundedCrop(src: Bitmap, w: Int, h: Int, radius: Float): Bitmap {
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), radius, radius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        val target = w.toFloat() / h
        val have = src.width.toFloat() / src.height
        val crop = if (have > target) {
            val cw = (src.height * target).toInt()
            Rect((src.width - cw) / 2, 0, (src.width + cw) / 2, src.height)
        } else {
            val ch = (src.width / target).toInt()
            Rect(0, (src.height - ch) / 2, src.width, (src.height + ch) / 2)
        }
        canvas.drawBitmap(src, crop, Rect(0, 0, w, h), paint)
        return out
    }

    /** Avatarin sag altina kucuk rozet: [glyph] (kalp, kisi+, kilit, onay, grup) ya da okunmamis sohbet sayisi. */
    fun withBadge(c: Context, base: Bitmap, glyph: Glyph?, count: Int): Bitmap {
        if (glyph == null && count < 2) return base
        val size = base.width
        val out = base.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(out)
        val r = size * 0.22f
        val cx = size - r - 1f
        val cy = size - r - 1f
        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFFFFFFF.toInt() }
        canvas.drawCircle(cx, cy, r + size * 0.04f, ring)
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = when {
                glyph == null || glyph == Glyph.HEART -> c.getColor(R.color.push_brand)
                glyph == Glyph.CHECK -> c.getColor(R.color.push_green_fg)
                else -> c.getColor(R.color.push_navy)
            }
        }
        canvas.drawCircle(cx, cy, r, fill)
        if (glyph == null) {
            val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFFFFFFF.toInt(); textAlign = Paint.Align.CENTER; typeface = Typeface.DEFAULT_BOLD; textSize = r * 1.25f
            }
            val label = if (count > 9) "9+" else count.toString()
            canvas.drawText(label, cx, cy - (text.descent() + text.ascent()) / 2f, text)
        } else {
            val g = r * 0.62f
            drawGlyph(c, canvas, glyph, 0xFFFFFFFF.toInt(), RectF(cx - g, cy - g, cx + g, cy + g))
        }
        return out
    }
}
