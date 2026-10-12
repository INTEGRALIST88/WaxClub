// Gera o ícone do WaxClub (1024x1024, estilo neon do app): disco de vinil com anel brilhante,
// nome "WaxClub" com brilho e o sufixo "VINYL SOCIAL CLUB".
// Uso (PowerShell): Add-Type -Path WaxClubIcon.cs -ReferencedAssemblies System.Drawing; [WaxClubIcon]::Render("saida.png")
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;

public static class WaxClubIcon
{
    const int S = 1024;

    static GraphicsPath RoundRect(float x, float y, float w, float h, float r)
    {
        var p = new GraphicsPath();
        p.AddArc(x, y, 2 * r, 2 * r, 180, 90);
        p.AddArc(x + w - 2 * r, y, 2 * r, 2 * r, 270, 90);
        p.AddArc(x + w - 2 * r, y + h - 2 * r, 2 * r, 2 * r, 0, 90);
        p.AddArc(x, y + h - 2 * r, 2 * r, 2 * r, 90, 90);
        p.CloseFigure();
        return p;
    }

    static void Glow(Graphics g, GraphicsPath path, Color color, float maxWidth, int steps, int maxAlpha)
    {
        for (int i = steps; i >= 1; i--)
        {
            float w = maxWidth * i / steps;
            int a = (int)(maxAlpha * (1.0 - (double)i / (steps + 1)) / 2.2) + 4;
            using (var pen = new Pen(Color.FromArgb(Math.Min(255, a), color), w) { LineJoin = LineJoin.Round })
                g.DrawPath(pen, path);
        }
    }

    static void GlowCircle(Graphics g, float cx, float cy, float r, Color color, float maxWidth, int steps, int maxAlpha)
    {
        using (var p = new GraphicsPath())
        {
            p.AddEllipse(cx - r, cy - r, 2 * r, 2 * r);
            Glow(g, p, color, maxWidth, steps, maxAlpha);
        }
    }

    static GraphicsPath TextPath(string text, FontFamily family, FontStyle style, float emSize, float centerX, float baselineY, float tracking)
    {
        var path = new GraphicsPath();
        var fmt = StringFormat.GenericTypographic;
        // Monta letra a letra para controlar o espaçamento
        float x = 0;
        var letters = new GraphicsPath();
        foreach (char c in text)
        {
            using (var lp = new GraphicsPath())
            {
                lp.AddString(c.ToString(), family, (int)style, emSize, new PointF(x, 0), fmt);
                if (lp.PointCount > 0) letters.AddPath(lp, false); // espaço não tem contorno
                var b = lp.PointCount > 0 ? lp.GetBounds() : RectangleF.Empty;
                float adv = c == ' ' ? emSize * 0.28f : (b.Width > 0 ? b.Right - x : emSize * 0.3f);
                x += adv + tracking;
            }
        }
        var bounds = letters.GetBounds();
        using (var m = new Matrix())
        {
            m.Translate(centerX - (bounds.Left + bounds.Width / 2), baselineY - bounds.Bottom);
            letters.Transform(m);
        }
        path.AddPath(letters, false);
        return path;
    }

    public static void Render(string output)
    {
        using (var bmp = new Bitmap(S, S, PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

            // Fundo: roxo profundo com vinheta
            using (var bg = new GraphicsPath())
            {
                bg.AddEllipse(-300, -300, S + 600, S + 600);
                using (var pgb = new PathGradientBrush(bg) { CenterColor = Color.FromArgb(255, 58, 24, 120), SurroundColors = new[] { Color.FromArgb(255, 10, 5, 26) } })
                    g.FillRectangle(pgb, 0, 0, S, S);
            }

            // Cartão arredondado com leve relevo
            using (var card = RoundRect(70, 70, S - 140, S - 140, 190))
            {
                using (var shadow = RoundRect(70, 92, S - 140, S - 140, 190))
                using (var sb = new SolidBrush(Color.FromArgb(120, 0, 0, 0)))
                    g.FillPath(sb, shadow);
                using (var lg = new LinearGradientBrush(new PointF(0, 70), new PointF(0, S - 70), Color.FromArgb(255, 72, 30, 140), Color.FromArgb(255, 24, 10, 58)))
                    g.FillPath(lg, card);
                using (var rim = new Pen(Color.FromArgb(90, 190, 150, 255), 4))
                    g.DrawPath(rim, card);
            }

            float cx = S / 2f, cy = 395, R = 272;

            // Halo atrás do disco
            using (var halo = new GraphicsPath())
            {
                halo.AddEllipse(cx - R - 80, cy - R - 80, 2 * (R + 80), 2 * (R + 80));
                using (var hb = new PathGradientBrush(halo) { CenterColor = Color.FromArgb(150, 120, 60, 255), SurroundColors = new[] { Color.FromArgb(0, 120, 60, 255) } })
                    g.FillPath(hb, halo);
            }

            // Disco
            using (var disc = new SolidBrush(Color.FromArgb(255, 12, 10, 20)))
                g.FillEllipse(disc, cx - R, cy - R, 2 * R, 2 * R);

            // Sulcos (tons de roxo/azul alternados)
            for (float r = 112; r < R - 6; r += 7)
            {
                double t = (r - 112) / (R - 118);
                int a = 70 + (int)(60 * Math.Sin(r * 0.21));
                var col = Color.FromArgb(Math.Max(25, Math.Min(150, a)), (int)(110 + 60 * t), (int)(70 + 40 * (1 - t)), 255);
                using (var pen = new Pen(col, 1.6f))
                    g.DrawEllipse(pen, cx - r, cy - r, 2 * r, 2 * r);
            }

            // Reflexo diagonal do vinil
            using (var clip = new GraphicsPath())
            {
                clip.AddEllipse(cx - R, cy - R, 2 * R, 2 * R);
                var old = g.Clip;
                g.SetClip(clip);
                using (var sheen = new LinearGradientBrush(new PointF(cx - R, cy - R), new PointF(cx + R, cy + R), Color.FromArgb(0, 255, 255, 255), Color.FromArgb(0, 255, 255, 255)))
                {
                    var blend = new ColorBlend
                    {
                        Positions = new[] { 0f, 0.38f, 0.5f, 0.62f, 1f },
                        Colors = new[] { Color.FromArgb(0, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), Color.FromArgb(70, 200, 230, 255), Color.FromArgb(0, 255, 255, 255), Color.FromArgb(0, 255, 255, 255) }
                    };
                    sheen.InterpolationColors = blend;
                    g.FillEllipse(sheen, cx - R, cy - R, 2 * R, 2 * R);
                }
                g.Clip = old;
            }

            // Anel neon externo (ciano) e interno (roxo)
            GlowCircle(g, cx, cy, R + 4, Color.FromArgb(0, 229, 255), 46, 14, 230);
            using (var ring = new Pen(Color.FromArgb(255, 170, 245, 255), 6))
                g.DrawEllipse(ring, cx - R - 4, cy - R - 4, 2 * (R + 4), 2 * (R + 4));
            GlowCircle(g, cx, cy, 104, Color.FromArgb(168, 85, 247), 26, 10, 200);

            // Selo: gradiente roxo → ciano com "W"
            using (var label = new GraphicsPath())
            {
                label.AddEllipse(cx - 100, cy - 100, 200, 200);
                using (var lb = new LinearGradientBrush(new PointF(cx - 100, cy - 100), new PointF(cx + 100, cy + 100), Color.FromArgb(255, 168, 85, 247), Color.FromArgb(255, 0, 200, 255)))
                    g.FillPath(lb, label);
            }
            var titleFont = new FontFamily("Segoe UI Black");
            using (var w = TextPath("W", titleFont, FontStyle.Regular, 130, cx, cy + 50, 0))
            using (var wb = new SolidBrush(Color.FromArgb(240, 255, 255, 255)))
                g.FillPath(wb, w);
            using (var hole = new SolidBrush(Color.FromArgb(255, 12, 10, 20)))
                g.FillEllipse(hole, cx - 9, cy - 9, 18, 18);

            // Nome com brilho neon
            using (var name = TextPath("WaxClub", titleFont, FontStyle.Regular, 176, cx, 850, 2))
            {
                Glow(g, name, Color.FromArgb(168, 85, 247), 44, 14, 210);
                Glow(g, name, Color.FromArgb(0, 229, 255), 16, 8, 230);
                using (var fill = new LinearGradientBrush(new PointF(0, 700), new PointF(0, 860), Color.FromArgb(255, 245, 252, 255), Color.FromArgb(255, 190, 240, 255)))
                    g.FillPath(fill, name);
            }

            // Sufixo
            using (var tag = TextPath("VINYL SOCIAL CLUB", new FontFamily("Segoe UI Semibold"), FontStyle.Regular, 46, cx, 925, 7))
            {
                Glow(g, tag, Color.FromArgb(0, 229, 255), 10, 6, 160);
                using (var tb = new SolidBrush(Color.FromArgb(255, 150, 238, 255)))
                    g.FillPath(tb, tag);
            }

            bmp.Save(output, ImageFormat.Png);
        }
    }
}
