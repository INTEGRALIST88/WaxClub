// Extrai só o microfone cromado da arte (fundo de madeira): mantém os pixels sem cor (cinza/prata)
// da região central, com transparência gradual na borda, e recorta justo no microfone.
// Uso (PowerShell): Add-Type -Path ChromeMicExtract.cs -ReferencedAssemblies System.Drawing
//                   [ChromeMicExtract]::Render("arte.png", "saida.png", 512)
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class ChromeMicExtract
{
    // Croma (diferença entre o canal mais forte e o mais fraco): madeira tem croma alta, cromo baixa
    static int Chroma(Color c) { return Math.Max(c.R, Math.Max(c.G, c.B)) - Math.Min(c.R, Math.Min(c.G, c.B)); }

    public static void Render(string src, string output, int size)
    {
        using (var art = new Bitmap(src))
        {
            int w = art.Width, h = art.Height;
            var alpha = new byte[w, h];
            // Região central onde está o microfone (fora dela só há madeira e fundo branco)
            int x0 = (int)(w * 0.36), x1 = (int)(w * 0.64), y0 = (int)(h * 0.20), y1 = (int)(h * 0.84);
            for (int y = y0; y < y1; y++)
                for (int x = x0; x < x1; x++)
                {
                    var c = art.GetPixel(x, y);
                    int chroma = Chroma(c);
                    // croma < 18: cromo; 18..34: transição (borda); > 34: madeira
                    int a = chroma <= 18 ? 255 : (chroma >= 34 ? 0 : (34 - chroma) * 255 / 16);
                    alpha[x, y] = (byte)a;
                }

            // Fica só o maior componente conectado (o microfone), descartando reflexos soltos na madeira
            var keep = new bool[w, h];
            var seen = new bool[w, h];
            List<Point> best = null;
            for (int y = y0; y < y1; y++)
                for (int x = x0; x < x1; x++)
                {
                    if (seen[x, y] || alpha[x, y] < 128) continue;
                    var comp = new List<Point>();
                    var stack = new Stack<Point>();
                    stack.Push(new Point(x, y));
                    seen[x, y] = true;
                    while (stack.Count > 0)
                    {
                        var p = stack.Pop();
                        comp.Add(p);
                        foreach (var d in new[] { new Point(1, 0), new Point(-1, 0), new Point(0, 1), new Point(0, -1) })
                        {
                            int nx = p.X + d.X, ny = p.Y + d.Y;
                            if (nx < x0 || ny < y0 || nx >= x1 || ny >= y1 || seen[nx, ny] || alpha[nx, ny] < 128) continue;
                            seen[nx, ny] = true;
                            stack.Push(new Point(nx, ny));
                        }
                    }
                    if (best == null || comp.Count > best.Count) best = comp;
                }
            int minX = w, minY = h, maxX = 0, maxY = 0;
            foreach (var p in best)
            {
                keep[p.X, p.Y] = true;
                if (p.X < minX) minX = p.X; if (p.X > maxX) maxX = p.X;
                if (p.Y < minY) minY = p.Y; if (p.Y > maxY) maxY = p.Y;
            }
            // borda suave: pixels de transição vizinhos do microfone
            using (var cut = new Bitmap(w, h, PixelFormat.Format32bppArgb))
            {
                for (int y = Math.Max(y0, minY - 3); y <= Math.Min(y1 - 1, maxY + 3); y++)
                    for (int x = Math.Max(x0, minX - 3); x <= Math.Min(x1 - 1, maxX + 3); x++)
                    {
                        bool near = keep[x, y];
                        if (!near)
                            for (int dy = -2; dy <= 2 && !near; dy++)
                                for (int dx = -2; dx <= 2 && !near; dx++)
                                {
                                    int nx = x + dx, ny = y + dy;
                                    if (nx >= 0 && ny >= 0 && nx < w && ny < h && keep[nx, ny]) near = true;
                                }
                        if (!near) continue;
                        int a = keep[x, y] ? 255 : alpha[x, y];
                        if (a == 0) continue;
                        var c = art.GetPixel(x, y);
                        cut.SetPixel(x, y, Color.FromArgb(a, c.R, c.G, c.B));
                    }

                int bw = maxX - minX + 1, bh = maxY - minY + 1, side = Math.Max(bw, bh) + 8;
                using (var outBmp = new Bitmap(size, size, PixelFormat.Format32bppArgb))
                using (var g = Graphics.FromImage(outBmp))
                {
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.Clear(Color.Transparent);
                    float scale = (float)size / side;
                    var dest = new RectangleF((size - bw * scale) / 2, (size - bh * scale) / 2, bw * scale, bh * scale);
                    g.DrawImage(cut, dest, new RectangleF(minX, minY, bw, bh), GraphicsUnit.Pixel);
                    outBmp.Save(output, ImageFormat.Png);
                }
            }
        }
    }
}
