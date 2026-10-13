// Ícone do WaxClub em madeira (a partir da arte do usuário): recorta o quadrado de madeira, mantém o
// selo do disco com o texto (com keepLabel=false, redesenha o selo SEM texto: creme + faixa laranja, balão e pessoas), escurece levemente a
// borda do disco (encaixe entalhado) e deixa os cantos transparentes.
// Uso (PowerShell): Add-Type -Path WaxClubWoodIcon.cs -ReferencedAssemblies System.Drawing
//                   [WaxClubWoodIcon]::Render("arte.png", "saida.png", 1024)
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class WaxClubWoodIcon
{
    static bool IsBackground(Color c) { return c.R > 228 && c.G > 228 && c.B > 228; }

    // Limites do quadrado de madeira: linha e coluna centrais, do primeiro ao último pixel não-branco
    static Rectangle FindTile(Bitmap b)
    {
        int cy = b.Height / 2 - 20, cx = b.Width / 2 - 40;
        int left = 0, right = b.Width - 1, top = 0, bottom = b.Height - 1;
        for (int x = 0; x < b.Width; x++) if (!IsBackground(b.GetPixel(x, cy))) { left = x; break; }
        for (int y = 0; y < b.Height; y++) if (!IsBackground(b.GetPixel(cx, y))) { top = y; break; }
        // borda direita/inferior: a sombra é cinza clara; usa a madeira (tom quente) como critério
        for (int x = b.Width - 1; x > left; x--) { var c = b.GetPixel(x, cy); if (c.R - c.B > 40) { right = x; break; } }
        for (int y = b.Height - 1; y > top; y--) { var c = b.GetPixel(cx, y); if (c.R - c.B > 40) { bottom = y; break; } }
        return Rectangle.FromLTRB(left, top, right + 1, bottom + 1);
    }

    public static void Render(string src, string output, int size) { Render(src, output, size, true); }

    // keepLabel: mantém o selo original da arte ("WaxClub" / "VINYL SOCIAL CLUB"); false redesenha o selo sem texto
    public static void Render(string src, string output, int size, bool keepLabel)
    {
        using (var art = new Bitmap(src))
        {
            var tile = FindTile(art);
            int side = Math.Max(tile.Width, tile.Height);
            using (var sq = new Bitmap(side, side, PixelFormat.Format32bppArgb))
            {
                using (var g = Graphics.FromImage(sq))
                {
                    g.Clear(Color.Transparent);
                    g.DrawImage(art, new Rectangle((side - tile.Width) / 2, (side - tile.Height) / 2, tile.Width, tile.Height), tile, GraphicsUnit.Pixel);
                }
                float s = side / 400f; // coordenadas abaixo medidas num quadrado de ~400 px
                using (var g = Graphics.FromImage(sq))
                {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    float ox = (side - tile.Width) / 2f - tile.Left, oy = (side - tile.Height) / 2f - tile.Top;
                    // centro e raio do selo na arte original (1024x572)
                    float lx = 516 + ox, ly = 283 + oy, lr = 96;

                    // Encaixe entalhado: sombra suave em anel logo fora do disco
                    float dx = 487 + ox, dy = 289 + oy, dr = 172;
                    for (int i = 0; i < 10; i++)
                        using (var pen = new Pen(Color.FromArgb(10, 40, 18, 6), 2.2f + i * 1.6f))
                            g.DrawEllipse(pen, dx - dr - i, dy - dr - i, 2 * (dr + i), 2 * (dr + i));

                    if (!keepLabel)
                    {
                    // Selo sem texto
                    using (var clip = new GraphicsPath())
                    {
                        clip.AddEllipse(lx - lr, ly - lr, 2 * lr, 2 * lr);
                        using (var cream = new SolidBrush(Color.FromArgb(255, 232, 210, 172)))
                            g.FillPath(cream, clip);
                        var old = g.Clip;
                        g.SetClip(clip);
                        using (var orange = new SolidBrush(Color.FromArgb(255, 186, 88, 42)))
                            g.FillRectangle(orange, lx - lr, ly + lr * 0.32f, 2 * lr, lr);
                        using (var line = new Pen(Color.FromArgb(255, 120, 52, 26), 2.2f))
                            g.DrawLine(line, lx - lr, ly + lr * 0.32f, lx + lr, ly + lr * 0.32f);
                        // leve brilho no topo do selo
                        using (var gloss = new LinearGradientBrush(new PointF(lx, ly - lr), new PointF(lx, ly), Color.FromArgb(55, 255, 255, 255), Color.FromArgb(0, 255, 255, 255)))
                            g.FillRectangle(gloss, lx - lr, ly - lr, 2 * lr, lr);
                        g.Clip = old;
                        using (var rim = new Pen(Color.FromArgb(255, 150, 70, 34), 2.4f))
                            g.DrawEllipse(rim, lx - lr + 6, ly - lr + 6, 2 * lr - 12, 2 * lr - 12);
                        using (var outer = new Pen(Color.FromArgb(160, 60, 26, 10), 2f))
                            g.DrawPath(outer, clip);
                    }

                    // Balão de conversa (laranja, três pontos) no alto do selo
                    float bx = lx, by = ly - lr * 0.38f, bw = 38, bh = 29;
                    using (var bubble = new GraphicsPath())
                    {
                        bubble.AddEllipse(bx - bw / 2, by - bh / 2, bw, bh);
                        bubble.AddPolygon(new[] { new PointF(bx - 9, by + 7), new PointF(bx - 15, by + 19), new PointF(bx - 1, by + 10) });
                        using (var ob = new SolidBrush(Color.FromArgb(255, 196, 92, 44)))
                            g.FillPath(ob, bubble);
                    }
                    using (var dot = new SolidBrush(Color.FromArgb(255, 245, 228, 200)))
                        for (int i = -1; i <= 1; i++) g.FillEllipse(dot, bx + i * 8 - 2.6f, by - 2.6f, 5.2f, 5.2f);

                    // Pessoas (creme) na faixa laranja
                    float px = lx, py = ly + lr * 0.62f;
                    using (var cr = new SolidBrush(Color.FromArgb(255, 240, 220, 188)))
                    {
                        Action<float, float, float> person = (x, y, k) =>
                        {
                            g.FillEllipse(cr, x - 5.5f * k, y - 13 * k, 11 * k, 11 * k);
                            g.FillPie(cr, x - 10 * k, y - 1 * k, 20 * k, 20 * k, 180, 180);
                        };
                        person(px - 15, py + 2, 0.85f);
                        person(px + 15, py + 2, 0.85f);
                        person(px, py, 1.05f);
                    }
                    }
                }

                // Cantos transparentes: remove o fundo branco que sobra fora do quadrado arredondado
                var visited = new bool[side, side];
                var stack = new Stack<Point>();
                foreach (var p in new[] { new Point(0, 0), new Point(side - 1, 0), new Point(0, side - 1), new Point(side - 1, side - 1) }) stack.Push(p);
                while (stack.Count > 0)
                {
                    var p = stack.Pop();
                    if (p.X < 0 || p.Y < 0 || p.X >= side || p.Y >= side || visited[p.X, p.Y]) continue;
                    visited[p.X, p.Y] = true;
                    var c = sq.GetPixel(p.X, p.Y);
                    if (c.A != 0 && !(c.R > 200 && c.G > 200 && c.B > 200)) continue;
                    sq.SetPixel(p.X, p.Y, Color.Transparent);
                    stack.Push(new Point(p.X + 1, p.Y)); stack.Push(new Point(p.X - 1, p.Y));
                    stack.Push(new Point(p.X, p.Y + 1)); stack.Push(new Point(p.X, p.Y - 1));
                }

                using (var outBmp = new Bitmap(size, size, PixelFormat.Format32bppArgb))
                using (var g = Graphics.FromImage(outBmp))
                {
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.Clear(Color.Transparent);
                    g.DrawImage(sq, 0, 0, size, size);
                    outBmp.Save(output, ImageFormat.Png);
                }
            }
        }
    }
}
